##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on 2025-12-24T00:34:36Z.
]##


import features

const featureWeights* = FeatureWeights(
  weights: [
  advancedPieces: 1.117808,
  bishopQueenThreats: 0.083385,
  capturesNearKing: 0.541080,
  centralPawnBreaks: 0.155472,
  checks: 0.321406,
  coordinatedAttacks: 0.287992,
  f7F2Attacks: -0.145464,
  forcingMoves: -0.283383,
  forfeitedCastlingGames: -0.180051,
  knightOutposts: -0.013447,
  movesNearKing: -0.247442,
  oppositeSideCastlingGames: -0.018086,
  pawnStorms: 0.608953,
  rookLifts: -0.208096,
  rookQueenThreats: 0.661941,
  sacrificeScorePerWinMove: 0.635337,
  shortGameBonusPerWin: 1.210842,
  ],
  bias: -0.708723,
)
