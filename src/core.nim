import std/[tables, sequtils, math, options]
import nimchess
import features, weights, norms, utils

export features

const
  PIECE_VALUES = [pawn: 1, knight: 3, bishop: 3, rook: 5, queen: 9]
  WINNING_MATERIAL_ADVANTAGE = PIECE_VALUES[pawn] * 3
  EARLY_QUEEN_EXCHANGE_MAX_MOVES = 15

type
  AttackingStats* = object
    result: GameResult
    totalMoves: int
    oppositeSideCastling: bool
    forfeitedCastling: bool
    pawnStormsVsKing: int
    centralPawnBreaks: int
    advancedPieces: int
    rookLifts: int
    knightOutposts: int
    rookQueenThreats: int
    bishopQueenThreats: int
    coordinatedAttacks: int
    movesNearKingDist: array[8, int]
    capturesNearKingDist: array[8, int]
    totalSacrificeScore: float
    totalChecks: int
    forcingMoves: int
    f7F2Attacks: int
    shortGameBonus: float
    shieldDestruction: int
    kingLinePressure: int
    rookOpenFileAttacks: int
    earlyQueenExchange: bool

  SacrificeState = object
    active: bool
    quietDeficits: seq[int]

func hasWinningAdvantage(balance: int): bool =
  balance >= WINNING_MATERIAL_ADVANTAGE

func getMaterialScore(position: Position, side: Color): int =
  var score = 0
  for pieceType in [pawn, knight, bishop, rook, queen]:
    let pieces = position[side, pieceType]
    var count = 0
    for square in a1 .. h8:
      if not empty(square.toBitboard and pieces):
        inc count
    score += count * PIECE_VALUES[pieceType]
  score

func getMaterialBalance(position: Position, playerColor: Color): int =
  let
    materialUs = getMaterialScore(position, playerColor)
    materialThem = getMaterialScore(position, playerColor.opposite)
  materialUs - materialThem

func createAnalysisView(position: Position, move: Move): (Position, Move) =
  if position.us == white:
    return (position, move)

  # For black, we mirror both position and move to normalize to white's perspective
  let mirroredPosition = position.mirrorVertically
  let mirroredMove = newMove(
    source = move.source.mirrorVertically,
    target = move.target.mirrorVertically,
    captured = move.isCapture,
    enPassant = move.isEnPassantCapture,
    castled = move.isCastling,
    promoted = move.promoted,
  )
  return (mirroredPosition, mirroredMove)

# --- Sacrifice Analysis ---
func maxFilterRadius(sequence: seq[int], radius: int): seq[int] =
  let n = sequence.len
  if n == 0:
    return @[]

  result = newSeq[int](n)
  for i in 0 ..< sequence.len:
    let
      lo = max(0, i - radius)
      hi = min(n - 1, i + radius)
      mm = sequence[lo .. hi].minmax
    assert mm[0] <= mm[1]
    result[i] = mm[1]

func scoreSacrificeQuietDeficits(quietDeficits: seq[int], radius: int = 2): float =
  if quietDeficits.len == 0:
    return 0.0
  let filtered = maxFilterRadius(quietDeficits, radius)
  filtered.sum.float

func updateSacrificeTracking(
    position: Position,
    move: Move,
    sacrificeState: var SacrificeState,
    stats: var AttackingStats,
) =
  # Apply the move to check material balance after our move
  let newPosition = position.doMove(move)
  let balanceAfter = getMaterialBalance(newPosition, position.us)

  if balanceAfter < 0:
    # We are in a deficit
    if not sacrificeState.active:
      sacrificeState.active = true
      sacrificeState.quietDeficits = @[]

    # If this move is quiet (non-capture, non-check), record the deficit
    if not move.isTactical and not newPosition.inCheck(position.enemy):
      sacrificeState.quietDeficits.add(abs(balanceAfter))
  else:
    # No deficit; if a sequence was active, it ends here
    if sacrificeState.active:
      let seqScore = scoreSacrificeQuietDeficits(sacrificeState.quietDeficits)
      stats.totalSacrificeScore += seqScore
      sacrificeState.active = false
      sacrificeState.quietDeficits = @[]

func finalizeSacrificeTracking(
    sacrificeState: SacrificeState, stats: var AttackingStats
) =
  if sacrificeState.active:
    let seqScore = scoreSacrificeQuietDeficits(sacrificeState.quietDeficits)
    stats.totalSacrificeScore += seqScore

# --- Move Analysis Functions ---
func analyzeCastling(
    position: Position,
    move: Move,
    isOurTurn: bool,
    usCastledSide: var Option[CastlingSide],
    themCastledSide: var Option[CastlingSide],
    materialBalance: int,
    stats: var AttackingStats,
) =
  if not move.isCastling:
    return

  let side = move.castlingSide(position)

  if isOurTurn:
    usCastledSide = some side
    if themCastledSide.isSome and usCastledSide != themCastledSide:
      if not materialBalance.hasWinningAdvantage:
        stats.oppositeSideCastling = true
  else:
    themCastledSide = some side

func analyzeKingProximity(
    position: Position, move: Move, materialBalance: int, stats: var AttackingStats
) =
  let dist = squareDistance(move.target, position.kingSquare(position.enemy))
  if dist <= 4:
    if move.isCapture:
      inc stats.capturesNearKingDist[dist]
    else:
      inc stats.movesNearKingDist[dist]

func analyzePieceThreats(
    position: Position,
    move: Move,
    movingPieceType: Piece,
    materialBalance: int,
    stats: var AttackingStats,
) =
  let enemyKingSquare = position.kingSquare(position.enemy)

  if movingPieceType in [rook, queen] and
      not empty(rook.attackMask(move.target, 0.Bitboard) and mask3x3(enemyKingSquare)):
    inc stats.rookQueenThreats

  if movingPieceType in [bishop, queen] and
      not empty(bishop.attackMask(move.target, 0.Bitboard) and mask3x3(enemyKingSquare)):
    inc stats.bishopQueenThreats

func analyzeTacticalMoves(
    position: Position,
    move: Move,
    movingPieceType: Piece,
    materialBalance: int,
    stats: var AttackingStats,
) =
  # Normalize to white's perspective
  let (position, move) = createAnalysisView(position, move)
  assert position.us == white

  let numPieces = position.occupancy.countSetBits

  # We don't evaluate this in the endgame, since there pieces move very freely anyway
  if numPieces >= 18:
    # Pawn storms
    if movingPieceType == pawn:
      let
        pawnFile = fileNumber(move.target)
        pawnRank = rankNumber(move.target)
        enemyKingSquare = position.kingSquare(black)
        kingFile = fileNumber(enemyKingSquare)
        kingRank = rankNumber(enemyKingSquare)

      if kingRank > pawnRank and abs(pawnFile - kingFile) <= 2:
        inc stats.pawnStormsVsKing

    # Central pawn breaks
    if movingPieceType == pawn and fileNumber(move.source) in [3, 4] and
        rankNumber(move.target) == 4 and numPieces >= 20:
      inc stats.centralPawnBreaks

    # Advanced pieces
    if movingPieceType != pawn:
      let targetRank = rankNumber(move.target)
      if targetRank >= 4:
        inc stats.advancedPieces

    # Rook lifts
    if movingPieceType == rook:
      let
        sourceRank = rankNumber(move.source)
        targetRank = rankNumber(move.target)
      if sourceRank <= 2 and targetRank >= 6:
        inc stats.rookLifts

    # Knight outposts
    if movingPieceType == knight:
      let targetRank = rankNumber(move.target)
      if targetRank >= 4 and
          not empty(attackMaskPawnCapture(move.target, black) and position[pawn, white]):
        inc stats.knightOutposts

  # Only important during opening
  if numPieces >= 26:
    # F7/F2 attacks (now always f7 in normalized view)
    if move.target == f7 or position.attacksFrom(move.target).isSet(f7):
      inc stats.f7F2Attacks

func analyzeForcingMoves(
    position: Position, move: Move, materialBalance: int, stats: var AttackingStats
) =
  if move.isCapture:
    inc stats.forcingMoves

  let newPosition = position.doMove(move)
  if newPosition.inCheck(position.enemy):
    inc stats.forcingMoves
    inc stats.totalChecks

func analyzeCoordinatedAttacks(
    position: Position, materialBalance: int, stats: var AttackingStats
) =
  let enemyKingSquare = position.kingSquare(position.enemy)

  # Count attacking pieces in 3x3 area around king
  var attacks = 0.Bitboard

  for square in mask3x3(enemyKingSquare):
    attacks |= position.attackers(attacker = position.us, target = square)

  let uniqueAttackers = countSetBits(attacks and position[position.us])

  if uniqueAttackers >= 3:
    inc stats.coordinatedAttacks

func calculateShortGameBonus(position: Position, playerColor: Color, ply: int): float =
  let finalBalance = getMaterialBalance(position, playerColor)

  if hasWinningAdvantage(finalBalance):
    return 0.0

  let gameLength = (ply + 1) div 2
  # Don't give a high bonus for games that are too short
  if gameLength in 20 .. 60:
    return max(0.0, (60 - max(30, gameLength)).float / 30.0)
  return 0.0

func analyzeShieldDestruction(
    position: Position, move: Move, stats: var AttackingStats
) =
  # If we capture a pawn that is part of the King's immediate protection
  if move.isCapture:
    let enemyKingSq = position.kingSquare(position.enemy)
    # Check if the captured square is in the 3x3 box of the king
    if not empty(mask3x3(enemyKingSq) and move.target.toBitboard):
      # We need to know if the captured piece was a pawn.
      # Since 'move' struct usually doesn't store captured piece type in all implementations,
      # we check the board state *before* the move was applied.
      if position.pieceAt(move.target) == pawn:
        inc stats.shieldDestruction

func analyzeLinePressure(position: Position, stats: var AttackingStats) =
  # Checks if sliding pieces are "looking" at the King, even if blocked.
  # This measures "X-Ray" pressure.
  let
    enemyKingSq = position.kingSquare(position.enemy)
    us = position.us

    # Rooks and Queens on same Rank or File
    rooksQueens = position[us, rook] or position[us, queen]
    # Bishops and Queens on same Diagonals
    bishopsQueens = position[us, bishop] or position[us, queen]

    # Get pseudo-attacks from the King's square as if the King was a Rook/Bishop
    # to find aligned pieces.
    kingRookLines = rook.attackMask(enemyKingSq, 0.Bitboard)
    kingBishopLines = bishop.attackMask(enemyKingSq, 0.Bitboard)

  # If our sliding pieces are on these lines, we are exerting pressure
  if not empty(kingRookLines and rooksQueens):
    inc stats.kingLinePressure

  if not empty(kingBishopLines and bishopsQueens):
    inc stats.kingLinePressure

func analyzeRookOpenFiles(
    position: Position, move: Move, movingPieceType: Piece, stats: var AttackingStats
) =
  # Checks if a Rook/Queen lands on an open/semi-open file near the King
  if movingPieceType in [rook, queen]:
    let
      destFile = fileNumber(move.target)
      enemyKingFile = fileNumber(position.kingSquare(position.enemy))

    # Only care if reasonably close to the King (same file or adjacent)
    if abs(destFile - enemyKingFile) <= 1:
      # Create file mask (vertical line)
      var fileMask = 0.Bitboard
      for r in 0 .. 7:
        fileMask = fileMask or (1.Bitboard shl (r * 8 + destFile))

      let allPawns = position[white, pawn] or position[black, pawn]

      # If no pawns on this file (Open) or only Enemy pawns (Semi-Open for us)
      # Actually, standard attacking principle: "Open" means no pawns.
      if empty(fileMask and allPawns):
        inc stats.rookOpenFileAttacks

func analyzeEarlyQueenExchange(
    position: Position, fullMoveNumber: int, stats: var AttackingStats
) =
  if stats.earlyQueenExchange:
    return
  if fullMoveNumber > EARLY_QUEEN_EXCHANGE_MAX_MOVES:
    return
  if empty(position[white, queen]) and empty(position[black, queen]):
    stats.earlyQueenExchange = true

# --- Main Analysis Function ---
func analyseGame*(game: Game, playerName: string): AttackingStats =
  var stats = AttackingStats(result: resultForPlayer(game, playerName))

  let playerColor =
    if game.headers.getOrDefault("White") == playerName: white else: black
  var
    position = game.startPosition
    usCastledSide = none CastlingSide
    themCastledSide = none CastlingSide
  var sacrificeState = SacrificeState()

  for ply, move in game.moves.pairs:
    let
      turn = position.us
      isOurTurn = (turn == playerColor)
      materialBalance = getMaterialBalance(position, playerColor)

    # Handle castling
    analyzeCastling(
      position, move, isOurTurn, usCastledSide, themCastledSide, materialBalance, stats
    )

    if isOurTurn:
      let movingPieceType = position.pieceAt(move.source)

      if movingPieceType == noPiece:
        position = position.doMove(move)
        continue

      # Update sacrifice tracking
      updateSacrificeTracking(position, move, sacrificeState, stats)

      # Only analyze attacking if we don't have winning material advantage
      if not hasWinningAdvantage(materialBalance):
        analyzeKingProximity(position, move, materialBalance, stats)
        analyzePieceThreats(position, move, movingPieceType, materialBalance, stats)
        analyzeTacticalMoves(position, move, movingPieceType, materialBalance, stats)
        analyzeForcingMoves(position, move, materialBalance, stats)
        analyzeCoordinatedAttacks(position, materialBalance, stats)
        analyzeShieldDestruction(position, move, stats)
        analyzeRookOpenFiles(position, move, movingPieceType, stats)

    let newPosition = position.doMove(move)
    analyzeEarlyQueenExchange(newPosition, (ply div 2) + 1, stats)

    if isOurTurn:
      if not hasWinningAdvantage(materialBalance):
        # Analyze pressure in the resulting position
        analyzeLinePressure(newPosition, stats)
      inc stats.totalMoves

    position = newPosition

  # Finalize sacrifice tracking
  finalizeSacrificeTracking(sacrificeState, stats)

  stats.shortGameBonus = calculateShortGameBonus(position, playerColor, game.moves.len)

  # Check for forfeited castling
  if usCastledSide.isNone and game.moves.len >= 40:
    stats.forfeitedCastling = true

  stats

func getProximityScore(distances: array[8, int]): float =
  let weights = [0, 8, 6, 4, 2, 1, 0, 0]
  var
    score = 0
    totalMovesInZone = 0

  for i, freq in distances.pairs:
    score += weights[i] * freq
    totalMovesInZone += freq

  let maxWeight = max(weights)
  if totalMovesInZone > 0:
    result = score.float / (totalMovesInZone * maxWeight).float
  else:
    result = 0.0

# --- Score Calculation Functions ---
func getRawFeatureScores*(stats: AttackingStats): array[AttackingFeature, float] =
  if stats.totalMoves <= 0:
    return

  #!fmt: off
  result[oppositeSideCastlingGames] = (if stats.oppositeSideCastling: 1.0 else: 0.0)
  result[forfeitedCastlingGames] = (if stats.forfeitedCastling: 1.0 else: 0.0)

  result[capturesNearKing] = getProximityScore(stats.capturesNearKingDist)
  result[movesNearKing] = getProximityScore(stats.movesNearKingDist)

  if stats.result != Loss:
    result[sacrificeScorePerWinMove] = stats.totalSacrificeScore / stats.totalMoves.float

  if stats.result == Win:
    result[shortGameBonusPerWin] = stats.shortGameBonus

  result[bishopQueenThreats] = stats.bishopQueenThreats.float / stats.totalMoves.float
  result[rookQueenThreats] = stats.rookQueenThreats.float / stats.totalMoves.float
  result[centralPawnBreaks] = stats.centralPawnBreaks.float / stats.totalMoves.float
  result[pawnStorms] = stats.pawnStormsVsKing.float / stats.totalMoves.float
  result[advancedPieces] = stats.advancedPieces.float / stats.totalMoves.float
  result[rookLifts] = stats.rookLifts.float / stats.totalMoves.float
  result[knightOutposts] = stats.knightOutposts.float / stats.totalMoves.float
  result[coordinatedAttacks] = stats.coordinatedAttacks.float / stats.totalMoves.float
  result[forcingMoves] = stats.forcingMoves.float / stats.totalMoves.float
  result[checks] = stats.totalChecks.float / stats.totalMoves.float
  result[f7F2Attacks] = stats.f7F2Attacks.float / stats.totalMoves.float
  result[shieldDestruction] = stats.shieldDestruction.float / stats.totalMoves.float
  result[kingLinePressure] = stats.kingLinePressure.float / stats.totalMoves.float
  result[rookOpenFileAttacks] = stats.rookOpenFileAttacks.float / stats.totalMoves.float
  result[earlyQueenExchange] = (if stats.earlyQueenExchange: 1.0 else: 0.0)

  #!fmt: on

func getNormalizedFeatureScores*(
    rawScores: array[AttackingFeature, float]
): array[AttackingFeature, float] =
  for feature in AttackingFeature:
    let params = normalizationParams[feature]
    if params.std > 0:
      result[feature] = (rawScores[feature] - params.mean) / params.std
    else:
      result[feature] = 0.0

func getAttackingScore*(
    rawScores: array[AttackingFeature, float], weights: FeatureWeights = featureWeights
): float =
  var totalWeightedScore = 0.0
  let normalizedScores = getNormalizedFeatureScores(rawScores)

  for feature in AttackingFeature:
    totalWeightedScore += weights.weights[feature] * normalizedScores[feature]

  let score = totalWeightedScore + weights.bias
  return 1.0 / (1.0 + exp(-score))

func getAttackingScore*(stats: AttackingStats): float =
  getAttackingScore(getRawFeatureScores(stats))
