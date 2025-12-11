##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-12-11T13:57:51Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.296666,
  bishopQueenThreatsPerMove: 0.121637,
  capturesNearKing: 0.135566,
  centralPawnBreaksPerMove: 0.027781,
  checksPerMove: 0.248602,
  coordinatedAttacksPerMove: 0.082598,
  f7F2AttacksPerMove: -0.056582,
  forcingMovesPerMove: -0.306880,
  forfeitedCastlingGames: -0.031728,
  knightOutpostsPerMove: -0.007663,
  movesNearKing: -0.011248,
  oppositeSideCastlingGames: 0.027417,
  pawnStormsPerMove: 0.197002,
  rookLiftsPerMove: -0.045003,
  rookQueenThreatsPerMove: 0.235805,
  sacrificeScorePerWinMove: 0.284897,
  shortGameBonusPerWin: 0.302574,
]
