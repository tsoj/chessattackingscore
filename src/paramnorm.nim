##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script on 2025-08-11T01:50:31Z.
]##

import features

const normalizationParams* = [
  advancedPiecesPerMove: (mean: 0.19296217, std: 0.10240948),
  bishopQueenThreatsPerMove: (mean: 0.03432087, std: 0.03951600),
  capturesNearKing: (mean: 0.38103961, std: 0.13096237),
  centralPawnBreaksPerMove: (mean: 0.02253382, std: 0.02369336),
  checksPerMove: (mean: 0.05097479, std: 0.05653066),
  coordinatedAttacksPerMove: (mean: 0.04120736, std: 0.07382315),
  f7F2AttacksPerMove: (mean: 0.02120294, std: 0.02535035),
  forcingMovesPerMove: (mean: 0.26368249, std: 0.08476835),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutpostsPerMove: (mean: 0.01351445, std: 0.02107667),
  movesNearKing: (mean: 0.21502321, std: 0.08669685),
  oppositeSideCastlingGames: (mean: 0.05369800, std: 0.22542203),
  pawnStormsPerMove: (mean: 0.06986719, std: 0.05841764),
  rookLiftsPerMove: (mean: 0.00568181, std: 0.01232329),
  rookQueenThreatsPerMove: (mean: 0.04562202, std: 0.04895079),
  sacrificeScorePerWinMove: (mean: 0.03873655, std: 0.14282984),
  shortGameBonusPerWin: (mean: 0.12920070, std: 0.30864804),
]
