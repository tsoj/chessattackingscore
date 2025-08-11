##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on 2025-08-11T13:30:01Z.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 0.896463,
  bishopQueenThreatsPerMove: 0.810252,
  capturesNearKing: 0.741100,
  centralPawnBreaksPerMove: 1.248384,
  checksPerMove: -0.047777,
  coordinatedAttacksPerMove: 0.323255,
  f7F2AttacksPerMove: 0.621940,
  forcingMovesPerMove: -0.038553,
  forfeitedCastlingGames: 0.765102,
  knightOutpostsPerMove: 0.802555,
  movesNearKing: 0.196662,
  oppositeSideCastlingGames: 0.588559,
  pawnStormsPerMove: 0.949831,
  rookLiftsPerMove: 0.911161,
  rookQueenThreatsPerMove: 0.757993,
  sacrificeScorePerWinMove: 0.556157,
  shortGameBonusPerWin: 3.050115,
]
