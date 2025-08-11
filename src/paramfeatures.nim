##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T15:01:54Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.319386,
  bishopQueenThreatsPerMove: 1.022100,
  capturesNearKing: 1.005810,
  centralPawnBreaksPerMove: 1.011714,
  checksPerMove: -0.048915,
  coordinatedAttacksPerMove: 0.329766,
  f7F2AttacksPerMove: 0.415836,
  forcingMovesPerMove: -0.039994,
  forfeitedCastlingGames: 1.131982,
  knightOutpostsPerMove: 1.049012,
  movesNearKing: 0.584930,
  oppositeSideCastlingGames: 1.067578,
  pawnStormsPerMove: 1.636164,
  rookLiftsPerMove: 0.434822,
  rookQueenThreatsPerMove: 1.317359,
  sacrificeScorePerWinMove: 0.504404,
  shortGameBonusPerWin: 1.990034,
]
