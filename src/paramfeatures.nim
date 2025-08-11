##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T18:27:32Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.288731,
  bishopQueenThreatsPerMove: 1.114876,
  capturesNearKing: 0.498580,
  centralPawnBreaksPerMove: 0.958803,
  coordinatedAttacksPerMove: 0.543425,
  forfeitedCastlingGames: 1.272481,
  knightOutpostsPerMove: 1.001270,
  movesNearKing: 0.294552,
  oppositeSideCastlingGames: 1.234591,
  pawnStormsPerMove: 1.325652,
  rookLiftsPerMove: 0.431609,
  rookQueenThreatsPerMove: 1.459328,
  sacrificeScorePerWinMove: 0.622321,
]
