##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-12-07T02:28:19Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.314837,
  bishopQueenThreatsPerMove: 0.049576,
  capturesNearKing: 0.204487,
  centralPawnBreaksPerMove: 0.022412,
  checksPerMove: 0.235315,
  coordinatedAttacksPerMove: 0.066528,
  f7F2AttacksPerMove: -0.031366,
  forcingMovesPerMove: -0.353935,
  forfeitedCastlingGames: -0.025161,
  knightOutpostsPerMove: -0.015109,
  movesNearKing: -0.091270,
  oppositeSideCastlingGames: 0.018568,
  pawnStormsPerMove: 0.134167,
  rookLiftsPerMove: -0.028005,
  rookQueenThreatsPerMove: 0.133852,
  sacrificeScorePerWinMove: 0.369136,
  shortGameBonusPerWin: 0.392314,
]
