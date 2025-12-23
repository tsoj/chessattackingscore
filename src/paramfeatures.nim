##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on 2025-12-23T22:55:06Z.
]##


import features

const featureWeights* = FeatureWeights(
  weights: [
  advancedPieces: 1.343023,
  bishopQueenThreats: -0.113447,
  capturesNearKing: 0.742420,
  centralPawnBreaks: 0.160848,
  checks: 1.434042,
  coordinatedAttacks: -0.043600,
  f7F2Attacks: -0.250530,
  forcingMoves: -2.254135,
  forfeitedCastlingGames: -0.152967,
  knightOutposts: -0.211797,
  movesNearKing: -0.062543,
  oppositeSideCastlingGames: 0.063332,
  pawnStorms: 0.351138,
  rookLifts: -0.261247,
  rookQueenThreats: 0.253611,
  sacrificeScorePerWinMove: 0.817292,
  shortGameBonusPerWin: 1.155006,
  ],
  bias: -0.736559,
)
