##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-12-06T20:42:14Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.391807,
  bishopQueenThreatsPerMove: 0.757938,
  capturesNearKing: 0.673812,
  centralPawnBreaksPerMove: 0.057330,
  checksPerMove: 0.914233,
  coordinatedAttacksPerMove: 0.375258,
  f7F2AttacksPerMove: 0.005474,
  forcingMovesPerMove: 0.232125,
  forfeitedCastlingGames: -0.007745,
  knightOutpostsPerMove: 0.020764,
  movesNearKing: 0.391029,
  oppositeSideCastlingGames: 0.006622,
  pawnStormsPerMove: 0.533632,
  rookLiftsPerMove: 0.004124,
  rookQueenThreatsPerMove: 0.914763,
  sacrificeScorePerWinMove: 2.184827,
  shortGameBonusPerWin: 2.792475,
]
