##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script on 2025-08-11T17:51:14Z.
]##

import features

const normalizationParams* = [
  advancedPiecesPerMove: (mean: 0.12779905, std: 0.08282749),
  bishopQueenThreatsPerMove: (mean: 0.12493464, std: 0.07720045),
  capturesNearKing: (mean: 0.49029898, std: 0.12949206),
  centralPawnBreaksPerMove: (mean: 0.02039151, std: 0.02385794),
  coordinatedAttacksPerMove: (mean: 0.04120736, std: 0.07382315),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutpostsPerMove: (mean: 0.01234175, std: 0.02023166),
  movesNearKing: (mean: 0.39573376, std: 0.09277501),
  oppositeSideCastlingGames: (mean: 0.05369800, std: 0.22542203),
  pawnStormsPerMove: (mean: 0.17095325, std: 0.09601913),
  rookLiftsPerMove: (mean: 0.00658065, std: 0.01347176),
  rookQueenThreatsPerMove: (mean: 0.10521201, std: 0.08233216),
  sacrificeScorePerWinMove: (mean: 0.03873187, std: 0.14277139),
]
