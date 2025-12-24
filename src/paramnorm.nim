##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculatenormalization.nim script on 2025-12-24T00:34:22Z.
]##

import features

const normalizationParams* = [
  advancedPieces: (mean: 0.12779905, std: 0.08282749),
  bishopQueenThreats: (mean: 0.12493464, std: 0.07720045),
  capturesNearKing: (mean: 0.49029898, std: 0.12949206),
  centralPawnBreaks: (mean: 0.02039151, std: 0.02385794),
  checks: (mean: 0.05097479, std: 0.05653066),
  coordinatedAttacks: (mean: 0.04120736, std: 0.07382315),
  f7F2Attacks: (mean: 0.00672670, std: 0.01543616),
  forcingMoves: (mean: 0.26368249, std: 0.08476835),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutposts: (mean: 0.01234175, std: 0.02023166),
  movesNearKing: (mean: 0.39573376, std: 0.09277501),
  oppositeSideCastlingGames: (mean: 0.05369800, std: 0.22542203),
  pawnStorms: (mean: 0.17095325, std: 0.09601913),
  rookLifts: (mean: 0.00658065, std: 0.01347176),
  rookQueenThreats: (mean: 0.10521201, std: 0.08233216),
  sacrificeScorePerWinMove: (mean: 0.10284874, std: 0.30707767),
  shortGameBonusPerWin: (mean: 0.12920070, std: 0.30864804),
]
