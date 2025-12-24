#!/usr/bin/env nim
##[
Script to calculate normalization parameters for raw attacking scores.
This analyzes a large set of games to determine mean and standard deviation
for each raw score feature, enabling better normalization.
]##

import std/[os, strutils, tables, strformat, math, times]
import nimchess
import features, utils, core

proc collectRawScores(
    pgnPath: string, maxGames: int = 0, minRating: int = 2000
): array[AttackingFeature, seq[float]] =
  ##[
  Process PGN file and collect all raw scores for statistical analysis.

  Returns:
    Array mapping feature names to sequences of raw scores
  ]##
  var rawScoreCollections: array[AttackingFeature, seq[float]]
  for feature in AttackingFeature:
    rawScoreCollections[feature] = @[]
  var gamesProcessed = 0
  var gamesFilteredByRating = 0

  echo fmt"Collecting raw scores from games (min rating: {minRating})..."

  try:
    for game in readPgnFileIter(pgnPath):
      if maxGames > 0 and gamesProcessed >= maxGames:
        echo &"\nReached game limit of {maxGames}."
        break

      if not shouldIncludeGame(game, minRating):
        inc gamesFilteredByRating
        continue

      # Analyze both players
      let whitePlayer = game.headers.getOrDefault("White", "?")
      let blackPlayer = game.headers.getOrDefault("Black", "?")

      for player in [whitePlayer, blackPlayer]:
        let stats = analyseGame(game, player)
        let rawScores = getRawFeatureScores(stats)

        # Collect all raw scores
        for feature in AttackingFeature:
          let score = rawScores[feature]
          rawScoreCollections[feature].add(score)

      inc gamesProcessed
      if gamesProcessed mod 100 == 0:
        stdout.write(&"\rProcessed {gamesProcessed} games...")
        stdout.flushFile()
  except Exception as e:
    echo fmt"Error processing PGN file: {e.msg}"
    quit(1)

  echo &"\nProcessed {gamesProcessed} games total."
  if gamesFilteredByRating > 0:
    echo fmt"Filtered out {gamesFilteredByRating} games due to rating requirements."

  return rawScoreCollections

proc calculateMean(values: seq[float]): float =
  if values.len == 0:
    return 0.0
  return values.sum() / values.len.float

proc calculateStdDev(values: seq[float], mean: float): float =
  if values.len <= 1:
    return 0.0

  var sumSquaredDiffs = 0.0
  for value in values:
    let diff = value - mean
    sumSquaredDiffs += diff * diff

  return sqrt(sumSquaredDiffs / (values.len - 1).float)

proc calculateNormalizationParameters(
    rawScoreCollections: array[AttackingFeature, seq[float]]
): array[AttackingFeature, tuple[mean: float, std: float]] =
  ##[
  Calculate mean and standard deviation for each feature.

  Returns:
    Array mapping feature names to tuples with 'mean' and 'std' fields
  ]##
  var normalizationParams: array[AttackingFeature, tuple[mean: float, std: float]]

  echo "\nCalculating normalization parameters..."

  for feature in AttackingFeature:
    let scores = rawScoreCollections[feature]
    if scores.len < 10: # Need at least 10 samples
      echo fmt"Warning: Only {scores.len} samples for {feature}, skipping..."
      continue

    let meanVal = calculateMean(scores)
    let stdVal = calculateStdDev(scores, meanVal)

    normalizationParams[feature] = (mean: meanVal, std: stdVal)

  return normalizationParams

proc writeNormalizationParamsFile(
    normalizationParams: array[AttackingFeature, tuple[mean: float, std: float]]
) =
  ##[
  Write the normalization parameters directly to the source file.
  ]##
  let filePath = "src/paramnorm.nim"

  var content =
    fmt"""##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculatenormalization.nim script on {now().utc}.
]##

import features

const normalizationParams* = [
"""

  for feature in AttackingFeature:
    let params = normalizationParams[feature]
    content.add(
      fmt"  {feature}: (mean: {params.mean:.8f}, std: {params.std:.8f})," & "\n"
    )

  content.add("]\n")

  try:
    writeFile(filePath, content)
    echo fmt"Successfully updated {filePath}"
  except Exception as e:
    echo fmt"Error writing to {filePath}: {e.msg}"

proc main() =
  const
    pgnPath = "data/non_attacking_games/classical_rapid_2300_elo_plus.pgn"
    maxGames = 200000
    minRating = 2000

  doAssert fileExists(pgnPath)

  try:
    # Collect raw scores
    let rawScoreCollections = collectRawScores(pgnPath, maxGames, minRating)

    # Calculate normalization parameters
    let normalizationParams = calculateNormalizationParameters(rawScoreCollections)

    var totalSamples = 0
    for feature in AttackingFeature:
      totalSamples += rawScoreCollections[feature].len

    echo "\n\n--- Normalization Parameters Complete ---"
    echo fmt"Analyzed {totalSamples} player-game combinations"

    # Write to file
    writeNormalizationParamsFile(normalizationParams)

    echo "\nNormalization parameters have been written to src/paramnorm.nim"
  except Exception as e:
    echo fmt"Error: {e.msg}"
    quit(1)

when isMainModule:
  main()
