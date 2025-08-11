##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script on 2025-08-11T18:32:53Z.
]##

import features

const normalizationParams* = [
  advancedPiecesPerMove: (mean: 0.10470843, std: 0.09307144),
  bishopQueenThreatsPerMove: (mean: 0.09781389, std: 0.08483257),
  capturesNearKing: (mean: 0.38025744, std: 0.23248973),
  centralPawnBreaksPerMove: (mean: 0.01693447, std: 0.02360516),
  coordinatedAttacksPerMove: (mean: 0.02747498, std: 0.06233869),
  forfeitedCastlingGames: (mean: 0.10216457, std: 0.30286631),
  knightOutpostsPerMove: (mean: 0.01010631, std: 0.01924513),
  movesNearKing: (mean: 0.30101110, std: 0.17798105),
  oppositeSideCastlingGames: (mean: 0.05369800, std: 0.22542203),
  pawnStormsPerMove: (mean: 0.14085326, std: 0.11257494),
  rookLiftsPerMove: (mean: 0.00524064, std: 0.01263657),
  rookQueenThreatsPerMove: (mean: 0.07830653, std: 0.08111849),
  sacrificeScorePerWinMove: (mean: 0.03873187, std: 0.14277139),
]
