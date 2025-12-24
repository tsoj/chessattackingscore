##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on 2025-12-24T14:23:12Z.
]##

import features

const featureWeights* = FeatureWeights(
  weights: [
    advancedPieces: 1.079360,
    bishopQueenThreats: 0.045496,
    capturesNearKing: 0.565585,
    centralPawnBreaks: 0.139581,
    checks: 0.419528,
    coordinatedAttacks: 0.244997,
    f7F2Attacks: -0.167216,
    forcingMoves: -0.428428,
    forfeitedCastlingGames: -0.171150,
    knightOutposts: -0.030739,
    movesNearKing: -0.186252,
    oppositeSideCastlingGames: 0.025702,
    pawnStorms: 0.500615,
    rookLifts: -0.182649,
    rookQueenThreats: 0.601473,
    sacrificeScorePerWinMove: 0.903094,
    shortGameBonusPerWin: 1.191287,
  ],
  bias: -0.889526,
)
