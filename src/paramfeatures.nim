##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T17:51:53Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.525803,
  bishopQueenThreatsPerMove: 1.067286,
  capturesNearKing: 0.691749,
  centralPawnBreaksPerMove: 0.756841,
  coordinatedAttacksPerMove: 0.359134,
  forfeitedCastlingGames: 0.713120,
  knightOutpostsPerMove: 0.910758,
  movesNearKing: 0.710872,
  oppositeSideCastlingGames: 0.789825,
  pawnStormsPerMove: 2.077273,
  rookLiftsPerMove: 0.405617,
  rookQueenThreatsPerMove: 1.509646,
  sacrificeScorePerWinMove: 0.619662,
]
