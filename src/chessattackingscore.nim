import std/[tables, sequtils, strutils, math, algorithm, parseopt, strformat]
import nimchess
import features, paramfeatures, paramnorm

export features

const
  PIECE_VALUES = [pawn: 1, knight: 3, bishop: 3, rook: 5, queen: 9]
  WINNING_MATERIAL_ADVANTAGE = PIECE_VALUES[pawn] * 3

type
  AttackingStats* = object
    numGames: int
    numWins: int
    numDraws: int
    numLosses: int
    totalMoves: int
    numWinMoves: int
    oppositeSideCastlingGames: int
    forfeitedCastlingGames: int
    pawnStormsVsKing: int
    centralPawnBreaks: int
    advancedPieces: int
    rookLifts: int
    knightOutposts: int
    movesNearKingDist: array[8, int]
    capturesNearKingDist: array[8, int]
    rookQueenThreats: int
    bishopQueenThreats: int
    totalSacrificeScore: float
    coordinatedAttacks: int

  SacrificeState = object
    active: bool
    quietDeficits: seq[int]

  AnalysisArgs = object
    pgnPath: string
    player: string
    maxGames: int
    minGames: int
    minRating: int
    topN: int
    eventFilter: seq[string]

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
        inc stats.oppositeSideCastlingGames
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

  let
    toFile = fileNumber(move.target)
    toRank = rankNumber(move.target)
    kingFile = fileNumber(enemyKingSquare)
    kingRank = rankNumber(enemyKingSquare)

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

# --- Main Analysis Function ---
func analyseGame*(game: Game, playerName: string, stats: var AttackingStats) =
  let playerColor =
    if game.headers.getOrDefault("White") == playerName: white else: black
  var
    position = game.startPosition
    usCastledSide = none CastlingSide
    themCastledSide = none CastlingSide

  let
    termination = game.headers.getOrDefault("Termination", "").toLower()
    isDraw =
      "time forfeit" in termination or game.headers.getOrDefault("Result") == "1/2-1/2"
    isWin =
      (
        (game.headers.getOrDefault("Result") == "1-0" and playerColor == white) or
        (game.headers.getOrDefault("Result") == "0-1" and playerColor == black)
      ) and not isDraw

  var sacrificeState = SacrificeState()

  for move in game.moves:
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
      if isWin:
        updateSacrificeTracking(position, move, sacrificeState, stats)

      # Only analyze attacking if we don't have winning material advantage
      if not hasWinningAdvantage(materialBalance):
        analyzeKingProximity(position, move, materialBalance, stats)

        analyzePieceThreats(position, move, movingPieceType, materialBalance, stats)

        analyzeTacticalMoves(position, move, movingPieceType, materialBalance, stats)

        analyzeCoordinatedAttacks(position, materialBalance, stats)

    position = position.doMove(move)

    if isOurTurn:
      inc stats.totalMoves
      if isWin:
        inc stats.numWinMoves

  # Finalize sacrifice tracking
  if isWin:
    finalizeSacrificeTracking(sacrificeState, stats)

  # Check for forfeited castling
  if usCastledSide.isNone and game.moves.len >= 40:
    inc stats.forfeitedCastlingGames

  # Update game results
  inc stats.numGames
  if isDraw:
    inc stats.numDraws
  elif isWin:
    inc stats.numWins
  else:
    inc stats.numLosses

# --- Score Calculation Functions ---
func getRawFeatureScores*(stats: AttackingStats): array[AttackingFeature, float] =
  if stats.numGames == 0 or stats.totalMoves == 0:
    return

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

  result[sacrificeScorePerWinMove] =
    if stats.numWinMoves > 0:
      stats.totalSacrificeScore / stats.numWinMoves.float
    else:
      0.0

  #!fmt: off
  result[sacrificeScorePerWinMove] = if stats.numWinMoves > 0: stats.totalSacrificeScore / stats.numWinMoves.float else: 0.0
  result[capturesNearKing] = getProximityScore(stats.capturesNearKingDist)
  result[coordinatedAttacksPerMove] = stats.coordinatedAttacks.float / stats.totalMoves.float
  result[oppositeSideCastlingGames] = stats.oppositeSideCastlingGames.float / stats.numGames.float
  result[pawnStormsPerMove] = stats.pawnStormsVsKing.float / stats.totalMoves.float
  result[rookQueenThreatsPerMove] = stats.rookQueenThreats.float / stats.totalMoves.float
  result[movesNearKing] = getProximityScore(stats.movesNearKingDist)
  result[advancedPiecesPerMove] = stats.advancedPieces.float / stats.totalMoves.float
  result[forfeitedCastlingGames] = stats.forfeitedCastlingGames.float / stats.numGames.float
  result[bishopQueenThreatsPerMove] = stats.bishopQueenThreats.float / stats.totalMoves.float
  result[knightOutpostsPerMove] = stats.knightOutposts.float / stats.totalMoves.float
  result[rookLiftsPerMove] = stats.rookLifts.float / stats.totalMoves.float
  result[centralPawnBreaksPerMove] = stats.centralPawnBreaks.float / stats.totalMoves.float
  #!fmt: on

func getAttackingScore*(
    rawScores: array[AttackingFeature, float],
    weights: array[AttackingFeature, float] = featureWeights,
): float =
  var totalWeightedScore = 0.0
  var totalWeight = 0.0

  for feature in AttackingFeature:
    let rawValue = rawScores[feature]
    let weight = weights[feature]
    let params = normalizationParams[feature]

    var normalizedValue: float
    if params.std > 0:
      normalizedValue = (rawValue - params.mean) / params.std
    else:
      normalizedValue = 0.0

    totalWeightedScore += weight * normalizedValue
    totalWeight += weight.abs

  if totalWeight == 0:
    return 0.0

  return totalWeightedScore / totalWeight

func getAttackingScore(stats: AttackingStats): float =
  getAttackingScore(getRawFeatureScores(stats))

func shouldIncludeGame(game: Game, args: AnalysisArgs): bool =
  # Apply event filter if specified
  if args.eventFilter.len > 0:
    let event = game.headers.getOrDefault("Event", "").toLower()
    var found = false
    for filter in args.eventFilter:
      if filter.toLower() in event:
        found = true
        break
    if not found:
      return false

  # Check player names
  let
    whitePlayer = game.headers.getOrDefault("White", "?")
    blackPlayer = game.headers.getOrDefault("Black", "?")

  if "?" in [whitePlayer, blackPlayer]:
    return false

  # Filter by minimum rating
  if args.minRating > 0:
    try:
      let
        whiteElo = parseInt(game.headers.getOrDefault("WhiteElo", "0"))
        blackElo = parseInt(game.headers.getOrDefault("BlackElo", "0"))
        minElo = min(whiteElo, blackElo)

      if minElo < args.minRating:
        return false
    except ValueError:
      return false

  return true

proc processSinglePlayerMode(args: AnalysisArgs) =
  var
    gameScoresForPlayer: seq[(Game, float)] = @[]
    gamesProcessed = 0
    gamesFilteredByRating = 0

  echo "Analyzing games for player '", args.player, "'..."

  try:
    for game in readPgnFileIter(args.pgnPath):
      if args.maxGames > 0 and gamesProcessed >= args.maxGames:
        echo "Reached game limit of ", args.maxGames
        break

      if not shouldIncludeGame(game, args):
        if args.minRating > 0:
          inc gamesFilteredByRating
        continue

      let
        whitePlayer = game.headers.getOrDefault("White", "?")
        blackPlayer = game.headers.getOrDefault("Black", "?")

      if args.player in [whitePlayer, blackPlayer]:
        var stats = AttackingStats()
        analyseGame(game, args.player, stats)
        let score = getAttackingScore(stats)
        gameScoresForPlayer.add((game, score))

      inc gamesProcessed
      if gamesProcessed mod 1000 == 0:
        echo "Processed ", gamesProcessed, " games..."

    echo "\n--- Analysis Complete ---"
    if gamesFilteredByRating > 0 and args.minRating > 0:
      echo "Filtered out ",
        gamesFilteredByRating, " games due to rating requirements (min rating: ",
        args.minRating, ")"

    # Output results
    if gameScoresForPlayer.len == 0:
      echo "No games found for player '", args.player, "'"
      return

    echo "Player: ", args.player
    let
      totalGames = gameScoresForPlayer.len
      avgScore = gameScoresForPlayer.mapIt(it[1]).sum / totalGames.float

    echo "\nOverall Stats for ", totalGames, " games:"
    echo "Average Attacking Score: ", avgScore.formatFloat(ffDecimal, 2), " / 100.0"

    gameScoresForPlayer.sort(
      proc(a, b: (Game, float)): int =
        cmp(a[1], b[1])
    )

    echo "\n--- Top ", args.topN, " Most Aggressive Games ---"
    for i in 0..<min(args.topN, gameScoresForPlayer.len):
      let (game, score) = gameScoresForPlayer[gameScoresForPlayer.len - 1 - i]
      echo "\nScore: ",
        score.formatFloat(ffDecimal, 2), " - ", game.headers.getOrDefault("Site", "?")
      echo game.toPgnString()

    echo "\n--- Top ", args.topN, " Least Aggressive Games ---"
    for i in 0..<min(args.topN, gameScoresForPlayer.len) - 1:
      let (game, score) = gameScoresForPlayer[i]
      echo "\nScore: ",
        score.formatFloat(ffDecimal, 2), " - ", game.headers.getOrDefault("Site", "?")
      echo game.toPgnString()
  except IOError:
    echo "Error: Could not read PGN file: ", args.pgnPath
    quit(1)

proc processAllPlayersMode(args: AnalysisArgs) =
  var
    allPlayerStats = initTable[string, AttackingStats]()
    topAggressiveGames: seq[(Game, float, string, AttackingStats)] = @[]
    leastAggressiveGames: seq[(Game, float, string, AttackingStats)] = @[]
    gamesProcessed = 0
    gamesFilteredByRating = 0

  echo "Analyzing all players..."

  try:
    for game in readPgnFileIter(args.pgnPath):
      if args.maxGames > 0 and gamesProcessed >= args.maxGames:
        echo "Reached game limit of ", args.maxGames
        break

      if not shouldIncludeGame(game, args):
        if args.minRating > 0:
          inc gamesFilteredByRating
        continue

      let
        whitePlayer = game.headers.getOrDefault("White", "?")
        blackPlayer = game.headers.getOrDefault("Black", "?")

      # Analyze for both players
      for player in [whitePlayer, blackPlayer]:
        if not allPlayerStats.hasKey(player):
          allPlayerStats[player] = AttackingStats()

        analyseGame(game, player, allPlayerStats[player])

        # Track top/least aggressive games across all players
        var tempStats = AttackingStats()
        analyseGame(game, player, tempStats)
        let score = getAttackingScore(tempStats)

        if topAggressiveGames.len < args.topN or score > topAggressiveGames[^1][1]:
          topAggressiveGames.add((game, score, player, tempStats))
          topAggressiveGames.sort(
            proc(a, b: (Game, float, string, AttackingStats)): int =
              cmp(b[1], a[1])
          )
          if topAggressiveGames.len > args.topN:
            topAggressiveGames.setLen(args.topN)

        if leastAggressiveGames.len < args.topN or score < leastAggressiveGames[^1][1]:
          leastAggressiveGames.add((game, score, player, tempStats))
          leastAggressiveGames.sort(
            proc(a, b: (Game, float, string, AttackingStats)): int =
              cmp(a[1], b[1])
          )
          if leastAggressiveGames.len > args.topN:
            leastAggressiveGames.setLen(args.topN)

      inc gamesProcessed
      if gamesProcessed mod 100 == 0:
        echo "Processed ", gamesProcessed, " games..."

    echo "\n--- Analysis Complete ---"
    if gamesFilteredByRating > 0 and args.minRating > 0:
      echo "Filtered out ",
        gamesFilteredByRating, " games due to rating requirements (min rating: ",
        args.minRating, ")"

    # Output results for all players mode
    var playerResults: seq[(string, float, AttackingStats)] = @[]
    for player, stats in allPlayerStats.pairs:
      if stats.numGames >= args.minGames:
        let score = getAttackingScore(stats)
        playerResults.add((player, score, stats))

    if playerResults.len == 0:
      echo "No players found with at least ", args.minGames, " games."
    else:
      playerResults.sort(
        proc(a, b: (string, float, AttackingStats)): int =
          cmp(b[1], a[1])
      )

      echo "Attacking ranking for ",
        playerResults.len, " players with at least ", args.minGames, " games:"
      echo "-".repeat(80)
      echo fmt"""{"Rank":<5} {"Player":<30} {"Agg. Score":<15} {"Games":<10} Record (W/D/L)"""
      echo "-".repeat(80)

      for i, (player, score, stats) in playerResults.pairs:
        let record = $stats.numWins & " / " & $stats.numDraws & " / " & $stats.numLosses
        echo fmt"{$(i + 1):<5} {player:<30} {score.formatFloat(ffDecimal, 2):<15} {$(stats.numGames):<10} {record}"

    echo "\n--- Top ", args.topN, " Most Aggressive Games (All Players) ---"
    for (game, score, player, stats) in topAggressiveGames:
      echo "-".repeat(50)
      echo "\nScore: ",
        score.formatFloat(ffDecimal, 2),
        " - ",
        game.headers.getOrDefault("Site", "?"),
        " - ",
        player
      echo "White: ",
        game.headers.getOrDefault("White", "?"),
        ", Black: ",
        game.headers.getOrDefault("Black", "?")
      echo game.toPgnString()

    echo "\n--- Top ", args.topN, " Least Aggressive Games (All Players) ---"
    for (game, score, player, stats) in leastAggressiveGames:
      echo "-".repeat(50)
      echo "\nScore: ",
        score.formatFloat(ffDecimal, 2),
        " - ",
        game.headers.getOrDefault("Site", "?"),
        " - ",
        player
      echo "White: ",
        game.headers.getOrDefault("White", "?"),
        ", Black: ",
        game.headers.getOrDefault("Black", "?")
      echo game.toPgnString()
  except IOError:
    echo "Error: Could not read PGN file: ", args.pgnPath
    quit(1)

proc parseArguments(): AnalysisArgs =
  result = AnalysisArgs(
    pgnPath: "",
    player: "",
    maxGames: 0,
    minGames: 10,
    minRating: 0,
    topN: 1,
    eventFilter: @[],
  )

  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "pgn":
        result.pgnPath = p.val
      of "player":
        result.player = p.val
      of "games":
        try:
          result.maxGames = parseInt(p.val)
        except ValueError:
          echo "Error: --games must be a number"
          quit(1)
      of "min_games", "min-games":
        try:
          result.minGames = parseInt(p.val)
        except ValueError:
          echo "Error: --min_games must be a number"
          quit(1)
      of "min_rating", "min-rating":
        try:
          result.minRating = parseInt(p.val)
        except ValueError:
          echo "Error: --min_rating must be a number"
          quit(1)
      of "top_n", "top-n":
        try:
          result.topN = parseInt(p.val)
        except ValueError:
          echo "Error: --top_n must be a number"
          quit(1)
      of "event_filter", "event-filter":
        result.eventFilter.add(p.val)
      of "help", "h":
        echo """
A tool to analyze PGNs and score players for attacking style

Usage: chessattackingscore [options]

Options:
  --pgn PATH              Path to the PGN file (required)
  --player NAME           Name of a specific player to analyze
  --games N               Maximum number of games to process
  --min_games N           Minimum games for a player to be included (default: 10)
  --min_rating N          Minimum rating for the lower-rated player (default: 0)
  --top_n N               Number of top/bottom games to display (default: 10)
  --event_filter TYPE     Filter games by event types (can be used multiple times)
  --help, -h              Show this help message

Examples:
  chessattackingscore --pgn games.pgn --player "Magnus Carlsen"
  chessattackingscore --pgn games.pgn --min_rating 2400 --top_n 5
"""
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      echo "Unexpected argument: ", p.key
      quit(1)

proc main() =
  let args = parseArguments()

  if args.pgnPath.len == 0:
    echo "Error: --pgn is required"
    echo "Use --help for usage information"
    quit(1)

  # Process games based on mode
  if args.player.len > 0:
    processSinglePlayerMode(args)
  else:
    processAllPlayersMode(args)

when isMainModule:
  main()
