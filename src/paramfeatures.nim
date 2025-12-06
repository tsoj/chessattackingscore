##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-12-06T20:12:00Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.509222,
  bishopQueenThreatsPerMove: 0.668696,
  capturesNearKing: 0.617947,
  centralPawnBreaksPerMove: 0.100097,
  checksPerMove: 0.973093,
  coordinatedAttacksPerMove: 0.252039,
  f7F2AttacksPerMove: 0.003147,
  forcingMovesPerMove: 0.430451,
  forfeitedCastlingGames: -0.005471,
  knightOutpostsPerMove: 0.044522,
  movesNearKing: 0.448192,
  oppositeSideCastlingGames: 0.004350,
  pawnStormsPerMove: 0.506074,
  rookLiftsPerMove: 0.002983,
  rookQueenThreatsPerMove: 0.832329,
  sacrificeScorePerWinMove: 2.279812,
  shortGameBonusPerWin: 2.831422,
]
