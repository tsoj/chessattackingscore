##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on 2025-12-24T22:41:00Z.
]##

import features

const featureWeights* = FeatureWeights(
  weights: [
    advancedPieces: 0.958439,
    bishopQueenThreats: 0.041072,
    capturesNearKing: 0.348407,
    centralPawnBreaks: 0.097460,
    checks: 0.191397,
    coordinatedAttacks: 0.197550,
    f7F2Attacks: -0.181793,
    forcingMoves: -0.287884,
    forfeitedCastlingGames: 0.030638,
    knightOutposts: -0.039693,
    movesNearKing: 0.046932,
    oppositeSideCastlingGames: 0.037840,
    pawnStorms: 0.338084,
    rookLifts: -0.151031,
    rookQueenThreats: 0.441891,
    sacrificeScorePerWinMove: 0.788610,
    shortGameBonusPerWin: 1.110510,
    shieldDestruction: 0.266921,
    kingLinePressure: 0.099250,
    rookOpenFileAttacks: 0.001499,
    earlyQueenExchange: -1.274985,
  ],
  bias: -0.906081,
)
