##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T01:40:08Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.999557,
  bishopQueenThreatsPerMove: 0.842473,
  capturesNearKing: 0.690392,
  centralPawnBreaksPerMove: 1.278448,
  checksPerMove: -0.040175,
  coordinatedAttacksPerMove: 0.411597,
  f7F2AttacksPerMove: 0.666499,
  forcingMovesPerMove: -0.039138,
  forfeitedCastlingGames: 0.848546,
  knightOutpostsPerMove: 0.838395,
  movesNearKing: -0.027690,
  oppositeSideCastlingGames: 0.619618,
  pawnStormsPerMove: 1.050820,
  rookLiftsPerMove: 0.979926,
  rookQueenThreatsPerMove: 0.819212,
  sacrificeScorePerWinMove: 0.563494,
  shortGameBonusPerWin: 3.091367,
]
