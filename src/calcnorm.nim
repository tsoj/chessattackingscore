#!/usr/bin/env nim
##[
Script to calculate normalization parameters for raw attacking scores.
This analyzes a large set of games to determine mean and standard deviation
for each raw score feature, enabling better normalization.
]##

import std/[os, strutils, sequtils, tables, strformat, math, parseopt, algorithm]
import nimchess
from chessattackingscore import AttackingStats, analyseGame, getRawFeatureScores, AttackingFeature

type
  NormalizationArgs = object
    pgnPath: string
    maxGames: int
    minRating: int

proc collectRawScores(pgnPath: string, maxGames: int = 0, minRating: int = 2000): array[AttackingFeature, seq[float]] =
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

      let whitePlayer = game.headers.getOrDefault("White", "?")
      let blackPlayer = game.headers.getOrDefault("Black", "?")

      if "?" in whitePlayer or "?" in blackPlayer:
        continue

      # Filter by rating
      try:
        let whiteElo = parseInt(game.headers.getOrDefault("WhiteElo", "0"))
        let blackElo = parseInt(game.headers.getOrDefault("BlackElo", "0"))
        let minElo = min(whiteElo, blackElo)
        if minElo > 0 and minElo < minRating:
          inc gamesFilteredByRating
          continue
      except ValueError:
        continue

      # Analyze both players
      for player in [whitePlayer, blackPlayer]:
        var stats = AttackingStats()
        analyseGame(game, player, stats)
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

proc calculateNormalizationParameters(rawScoreCollections: array[AttackingFeature, seq[float]]): array[AttackingFeature, tuple[mean: float, std: float]] =
  ##[
  Calculate mean and standard deviation for each feature.

  Returns:
    Array mapping feature names to tuples with 'mean' and 'std' fields
  ]##
  var normalizationParams: array[AttackingFeature, tuple[mean: float, std: float]]

  echo "\nCalculating normalization parameters..."
  echo "Feature".alignLeft(35) & " " & "Count".alignLeft(8) & " " & "Mean".alignLeft(12) & " " & "Std".alignLeft(12) & " " & "Min".alignLeft(12) & " " & "Max".alignLeft(12)
  echo "-".repeat(90)

  for feature in AttackingFeature:
    let scores = rawScoreCollections[feature]
    if scores.len < 10:  # Need at least 10 samples
      echo fmt"Warning: Only {scores.len} samples for {feature}, skipping..."
      continue

    let meanVal = calculateMean(scores)
    let stdVal = calculateStdDev(scores, meanVal)
    let minVal = scores.min()
    let maxVal = scores.max()

    normalizationParams[feature] = (mean: meanVal, std: stdVal)

    echo ($feature).alignLeft(35) & " " &
         ($scores.len).alignLeft(8) & " " &
         fmt"{meanVal:.6f}".alignLeft(12) & " " &
         fmt"{stdVal:.6f}".alignLeft(12) & " " &
         fmt"{minVal:.6f}".alignLeft(12) & " " &
         fmt"{maxVal:.6f}".alignLeft(12)

  return normalizationParams

proc writeNormalizationParamsFile(normalizationParams: array[AttackingFeature, tuple[mean: float, std: float]]) =
  ##[
  Write the normalization parameters directly to the source file.
  ]##
  let filePath = "src/paramnorm.nim"

  var content = """##[
Normalization parameters for chess attacking score features.
These parameters are used to normalize raw feature scores before applying weights.

This file is automatically updated by the calculate_normalization script.
]##

import features

const normalizationParams* = [
"""

  for feature in AttackingFeature:
    let params = normalizationParams[feature]
    content.add(fmt"  {feature}: (mean: {params.mean:.8f}, std: {params.std:.8f})," & "\n")

  content.add("]\n")

  try:
    writeFile(filePath, content)
    echo fmt"Successfully updated {filePath}"
  except Exception as e:
    echo fmt"Error writing to {filePath}: {e.msg}"

proc parseArguments(): NormalizationArgs =
  var
    pgnPath = "data/non_attacking_games/classical_rapid_2300_elo_plus.pgn"
    maxGames = 200000
    minRating = 2000

  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key:
      of "pgn":
        pgnPath = p.val
      of "games":
        maxGames = parseInt(p.val)
      of "min_rating":
        minRating = parseInt(p.val)
      of "help", "h":
        echo fmt"""
Calculate normalization parameters for chess attacking analysis.

Usage:
  calculate_normalization --pgn <path> [options]

Options:
  --pgn <path>           Path to the PGN file (default: {pgnPath})
  --games <n>            Maximum number of games to process (default: {maxGames})
  --min_rating <rating>  Minimum rating for players (default: {minRating})
  --help, -h             Show this help message
"""
        quit(0)
      else:
        echo fmt"Unknown option: {p.key}"
        quit(1)
    of cmdArgument:
      if pgnPath == "":
        pgnPath = p.key

  if pgnPath == "":
    echo "Error: PGN path is required. Use --pgn <path>"
    quit(1)

  return NormalizationArgs(
    pgnPath: pgnPath,
    maxGames: maxGames,
    minRating: minRating
  )

proc main() =
  let args = parseArguments()

  if not fileExists(args.pgnPath):
    echo fmt"Error: PGN file not found: {args.pgnPath}"
    quit(1)

  try:
    # Collect raw scores
    let rawScoreCollections = collectRawScores(args.pgnPath, args.maxGames, args.minRating)

    # Check if we have any meaningful data
    var hasData = false
    for feature in AttackingFeature:
      if rawScoreCollections[feature].len > 0:
        hasData = true
        break
    if not hasData:
      echo "No raw scores collected. Check your PGN file and parameters."
      quit(1)

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
