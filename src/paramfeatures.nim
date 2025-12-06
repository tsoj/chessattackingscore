##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-12-06T19:40:59Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.889839,
  bishopQueenThreatsPerMove: 0.196264,
  capturesNearKing: 0.025487,
  centralPawnBreaksPerMove: 0.017514,
  coordinatedAttacksPerMove: 0.191549,
  forfeitedCastlingGames: -0.005267,
  knightOutpostsPerMove: 0.008743,
  movesNearKing: 0.019709,
  oppositeSideCastlingGames: 0.010037,
  pawnStormsPerMove: 0.190239,
  rookLiftsPerMove: 0.007356,
  rookQueenThreatsPerMove: 0.373560,
  sacrificeScorePerWinMove: 3.643797,
]
