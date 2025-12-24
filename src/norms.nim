##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calcnorm.nim script on 2025-12-24T23:09:55Z.
]##

import features

const normalizationParams* = [
  advancedPieces: (mean: 0.13049901, std: 0.08393417),
  bishopQueenThreats: (mean: 0.12526134, std: 0.07734092),
  capturesNearKing: (mean: 0.48926713, std: 0.13030547),
  centralPawnBreaks: (mean: 0.02091860, std: 0.02421268),
  checks: (mean: 0.04987512, std: 0.05633870),
  coordinatedAttacks: (mean: 0.03902794, std: 0.07234428),
  f7F2Attacks: (mean: 0.00695190, std: 0.01582372),
  forcingMoves: (mean: 0.26514586, std: 0.08543799),
  forfeitedCastlingGames: (mean: 0.10298103, std: 0.30393602),
  knightOutposts: (mean: 0.01254343, std: 0.02055312),
  movesNearKing: (mean: 0.39226766, std: 0.09247007),
  oppositeSideCastlingGames: (mean: 0.05398526, std: 0.22599004),
  pawnStorms: (mean: 0.17479289, std: 0.09540642),
  rookLifts: (mean: 0.00671349, std: 0.01375433),
  rookQueenThreats: (mean: 0.10315446, std: 0.08145553),
  sacrificeScorePerWinMove: (mean: 0.06863919, std: 0.21900333),
  shortGameBonusPerWin: (mean: 0.14543137, std: 0.32383739),
  shieldDestruction: (mean: 0.00497427, std: 0.01253848),
  kingLinePressure: (mean: 0.14513735, std: 0.16679538),
  rookOpenFileAttacks: (mean: 0.01747075, std: 0.03351492),
  earlyQueenExchange: (mean: 0.11080718, std: 0.31389520),
]
