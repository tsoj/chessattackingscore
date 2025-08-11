##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T18:33:33Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.344220,
  bishopQueenThreatsPerMove: 1.154806,
  capturesNearKing: 0.513828,
  centralPawnBreaksPerMove: 0.999997,
  coordinatedAttacksPerMove: 0.563213,
  forfeitedCastlingGames: 1.322425,
  knightOutpostsPerMove: 1.036980,
  movesNearKing: 0.322532,
  oppositeSideCastlingGames: 1.286216,
  pawnStormsPerMove: 1.366003,
  rookLiftsPerMove: 0.447592,
  rookQueenThreatsPerMove: 1.512604,
  sacrificeScorePerWinMove: 0.648627,
]
