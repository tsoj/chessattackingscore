##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T01:51:19Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.952605,
  bishopQueenThreatsPerMove: 0.802031,
  capturesNearKing: 0.658975,
  centralPawnBreaksPerMove: 1.214239,
  checksPerMove: -0.037208,
  coordinatedAttacksPerMove: 0.391495,
  f7F2AttacksPerMove: 0.632235,
  forcingMovesPerMove: -0.037577,
  forfeitedCastlingGames: 0.808778,
  knightOutpostsPerMove: 0.797955,
  movesNearKing: -0.031844,
  oppositeSideCastlingGames: 0.588067,
  pawnStormsPerMove: 0.997848,
  rookLiftsPerMove: 0.933880,
  rookQueenThreatsPerMove: 0.778652,
  sacrificeScorePerWinMove: 0.537688,
  shortGameBonusPerWin: 2.936475,
]
