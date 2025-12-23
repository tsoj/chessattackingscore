##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculatenormalization.nim script on 2025-12-23T22:51:02Z.
]##

import features

const normalizationParams* = [
  advancedPieces: (mean: 4.71237315, std: 2.84294119),
  bishopQueenThreats: (mean: 4.96781270, std: 3.86865255),
  capturesNearKing: (mean: 0.49029898, std: 0.12949206),
  centralPawnBreaks: (mean: 0.69404631, std: 0.65582997),
  checks: (mean: 2.32164795, std: 2.99288704),
  coordinatedAttacks: (mean: 2.22198096, std: 4.38780123),
  f7F2Attacks: (mean: 0.23199379, std: 0.46509552),
  forcingMoves: (mean: 10.69382130, std: 5.50570114),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutposts: (mean: 0.45751862, std: 0.69833810),
  movesNearKing: (mean: 0.39573376, std: 0.09277501),
  oppositeSideCastlingGames: (mean: 0.05369800, std: 0.22542203),
  pawnStorms: (mean: 5.81517899, std: 2.13814343),
  rookLifts: (mean: 0.26418109, std: 0.50549659),
  rookQueenThreats: (mean: 4.70359787, std: 4.85155809),
  sacrificeScorePerWinMove: (mean: 0.10284874, std: 0.30707767),
  shortGameBonusPerWin: (mean: 0.12920070, std: 0.30864804),
]
