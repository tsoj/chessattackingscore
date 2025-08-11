##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script on 2025-08-11T15:00:54Z.
]##

import features

const normalizationParams* = [
  advancedPiecesPerMove: (mean: 0.13542646, std: 0.08376054),
  bishopQueenThreatsPerMove: (mean: 0.11939589, std: 0.07597954),
  capturesNearKing: (mean: 0.48799527, std: 0.13034029),
  centralPawnBreaksPerMove: (mean: 0.02017722, std: 0.02377891),
  checksPerMove: (mean: 0.04673311, std: 0.05409035),
  coordinatedAttacksPerMove: (mean: 0.03655597, std: 0.06910359),
  f7F2AttacksPerMove: (mean: 0.00664344, std: 0.01530828),
  forcingMovesPerMove: (mean: 0.25314612, std: 0.08388187),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutpostsPerMove: (mean: 0.01241771, std: 0.02023356),
  movesNearKing: (mean: 0.38999347, std: 0.09205093),
  oppositeSideCastlingGames: (mean: 0.05217920, std: 0.22238949),
  pawnStormsPerMove: (mean: 0.18319571, std: 0.09072287),
  rookLiftsPerMove: (mean: 0.00732503, std: 0.01399044),
  rookQueenThreatsPerMove: (mean: 0.09783994, std: 0.08019137),
  sacrificeScorePerWinMove: (mean: 0.03873187, std: 0.14277139),
  shortGameBonusPerWin: (mean: 0.09572861, std: 0.27281974),
]
