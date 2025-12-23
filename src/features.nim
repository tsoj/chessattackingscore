type
  AttackingFeature* = enum
    advancedPieces
    bishopQueenThreats
    capturesNearKing
    centralPawnBreaks
    checks
    coordinatedAttacks
    f7F2Attacks
    forcingMoves
    forfeitedCastlingGames
    knightOutposts
    movesNearKing
    oppositeSideCastlingGames
    pawnStorms
    rookLifts
    rookQueenThreats
    sacrificeScorePerWinMove
    shortGameBonusPerWin

  FeatureWeights* = object
    weights*: array[AttackingFeature, float]
    bias*: float
