##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script.
]##

import features

const featureWeights* = [
  advancedPiecesPerMove: 1.004177,
  bishopQueenThreatsPerMove: 0.856049,
  capturesNearKing: 0.695529,
  centralPawnBreaksPerMove: 1.190567,
  checksPerMove: -0.064374,
  coordinatedAttacksPerMove: 0.435553,
  f7F2AttacksPerMove: 0.635450,
  forcingMovesPerMove: -0.052769,
  forfeitedCastlingGames: 0.807302,
  knightOutpostsPerMove: 0.831369,
  movesNearKing: -0.031738,
  oppositeSideCastlingGames: 0.520369,
  pawnStormsPerMove: 1.044093,
  rookLiftsPerMove: 0.979605,
  rookQueenThreatsPerMove: 0.764325,
  sacrificeScorePerWinMove: 0.528763,
  shortGameBonusPerWin: 3.076635,
]
