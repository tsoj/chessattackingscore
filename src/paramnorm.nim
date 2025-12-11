##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script on 2025-12-11T13:57:11Z.
]##

import features

const normalizationParams* = [
  advancedPiecesPerMove: (mean: 0.15261217, std: 0.08819477),
  bishopQueenThreatsPerMove: (mean: 0.13073324, std: 0.07713113),
  capturesNearKing: (mean: 0.50702355, std: 0.12429057),
  centralPawnBreaksPerMove: (mean: 0.02249731, std: 0.02525156),
  checksPerMove: (mean: 0.05861445, std: 0.05853012),
  coordinatedAttacksPerMove: (mean: 0.04088096, std: 0.07220505),
  f7F2AttacksPerMove: (mean: 0.00787636, std: 0.01734351),
  forcingMovesPerMove: (mean: 0.28104774, std: 0.08826658),
  forfeitedCastlingGames: (mean: 0.09332793, std: 0.29089565),
  knightOutpostsPerMove: (mean: 0.01434244, std: 0.02206611),
  movesNearKing: (mean: 0.39761642, std: 0.08659965),
  oppositeSideCastlingGames: (mean: 0.05668508, std: 0.23124322),
  pawnStormsPerMove: (mean: 0.17804598, std: 0.09339249),
  rookLiftsPerMove: (mean: 0.00791149, std: 0.01512814),
  rookQueenThreatsPerMove: (mean: 0.10476663, std: 0.07887150),
  sacrificeScorePerWinMove: (mean: 0.09956679, std: 0.21527486),
  shortGameBonusPerWin: (mean: 0.33213215, std: 0.42129975),
]
