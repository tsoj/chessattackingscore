##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on 2025-12-24T23:10:13Z.
]##

import features

const featureWeights* = FeatureWeights(
  weights: [
    advancedPieces: 0.343781,
    bishopQueenThreats: 0.017276,
    capturesNearKing: 0.089516,
    centralPawnBreaks: 0.046620,
    checks: 0.192159,
    coordinatedAttacks: 0.086075,
    f7F2Attacks: -0.073483,
    forcingMoves: -0.208957,
    forfeitedCastlingGames: 0.004931,
    knightOutposts: -0.031184,
    movesNearKing: 0.006042,
    oppositeSideCastlingGames: 0.018925,
    pawnStorms: 0.090738,
    rookLifts: -0.036526,
    rookQueenThreats: 0.129831,
    sacrificeScorePerWinMove: 0.339694,
    shortGameBonusPerWin: 0.322212,
    shieldDestruction: 0.120701,
    kingLinePressure: 0.031115,
    rookOpenFileAttacks: 0.007883,
    earlyQueenExchange: -0.231939,
  ],
  bias: -0.312773,
)
