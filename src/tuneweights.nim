import std/[os, parseopt, strutils, sequtils, tables, math, random, strformat, times]
import nimchess
from chessattackingscore import AttackingStats, analyseGame, getRawFeatureScores, AttackingFeature, getAttackingScore
import paramnorm

type
  GameData = tuple
    rawScores: array[AttackingFeature, float]
    targetLabel: float

  SPSAOptimizer = object
    weights: array[AttackingFeature, float]
    momentum: array[AttackingFeature, float]
    learningRate: float
    momentumCoeff: float
    c: float  # SPSA perturbation magnitude
    iteration: int
    maxIterations: int

proc calculateScoreWithWeights(rawScores: array[AttackingFeature, float], weights: array[AttackingFeature, float]): float =
  var totalWeightedScore = 0.0
  var totalWeight = 0.0

  for feature in AttackingFeature:
    let rawValue = rawScores[feature]
    let weight = weights[feature]
    let params = normalizationParams[feature]

    var normalizedValue: float
    if params.std > 0:
      normalizedValue = (rawValue - params.mean) / params.std
    else:
      normalizedValue = 0.0

    totalWeightedScore += weight * normalizedValue
    totalWeight += weight

  if totalWeight == 0:
    return 0.0

  return totalWeightedScore / totalWeight

proc preprocessGamesFromFolder(folderPath: string, targetLabel: float, maxGamesPerClass: int): seq[GameData] =
  echo "\nProcessing games from '", folderPath, "' with target score ", targetLabel, "..."

  var processedData: seq[GameData] = @[]

  if not dirExists(folderPath):
    echo "Warning: Directory ", folderPath, " does not exist"
    return processedData

  var pgnFiles: seq[string] = @[]
  for file in walkDir(folderPath):
    if file.kind == pcFile and file.path.endsWith(".pgn"):
      pgnFiles.add(file.path)

  if pgnFiles.len == 0:
    echo "Warning: No .pgn files found in ", folderPath
    return processedData

  let isAttackingSet = (targetLabel == 1.0)

  for pgnPath in pgnFiles:
    if processedData.len >= maxGamesPerClass:
      echo "\nReached max_games_per_class limit of ", maxGamesPerClass, " for this set."
      break

    try:
      echo "path: ", pgnPath
      for game in readPgnFileIter(pgnPath):
        if processedData.len >= maxGamesPerClass:
          break

        if isAttackingSet:
          # For attacking games, find the winner and analyze only their play
          let gameResult = game.headers.getOrDefault("Result", "*")
          var winnerPlayerName = ""

          if gameResult == "1-0":
            winnerPlayerName = game.headers.getOrDefault("White", "")
          elif gameResult == "0-1":
            winnerPlayerName = game.headers.getOrDefault("Black", "")

          if winnerPlayerName != "" and winnerPlayerName != "?":
            var stats = AttackingStats()
            analyseGame(game, winnerPlayerName, stats)
            let rawScores = getRawFeatureScores(stats)
            processedData.add((rawScores, targetLabel))
        else:
          # For normal games, analyze both players
          let whiteName = game.headers.getOrDefault("White", "?")
          let blackName = game.headers.getOrDefault("Black", "?")

          for playerName in [whiteName, blackName]:
            if playerName == "?" or processedData.len >= maxGamesPerClass:
              continue

            var stats = AttackingStats()
            analyseGame(game, playerName, stats)
            let rawScores = getRawFeatureScores(stats)

            processedData.add((rawScores, targetLabel))

    except Exception as e:
      echo "Could not process file ", pgnPath, ": ", e.msg

  # Shuffle the data
  shuffle(processedData)

  echo "Found ", processedData.len, " valid player-perspectives in ", folderPath, "."
  return processedData

proc calculateLoss(trainingData: seq[GameData], weights: array[AttackingFeature, float]): float =
  var totalError = 0.0

  for data in trainingData:
    let predictedScore = calculateScoreWithWeights(data.rawScores, weights)
    totalError += abs(predictedScore - data.targetLabel)

  return totalError / trainingData.len.float

proc createBalancedDataset(normalData: seq[GameData], attackingData: seq[GameData]): seq[GameData] =
  let maxClassSize = max(normalData.len, attackingData.len)
  var balancedData: seq[GameData] = @[]

  # Add all data from both classes
  balancedData.add(normalData)
  balancedData.add(attackingData)

  # Oversample the minority class to match the majority class
  let minorityClass = if normalData.len < attackingData.len: normalData else: attackingData
  let oversampleCount = maxClassSize - minorityClass.len

  for i in 0..<oversampleCount:
    balancedData.add(minorityClass[i mod minorityClass.len])

  shuffle(balancedData)
  return balancedData

proc initSPSAOptimizer(initialWeights: array[AttackingFeature, float], maxIterations: int, learningRate: float = 0.01,
                      momentumCoeff: float = 0.9, c: float = 0.1): SPSAOptimizer =
  result.weights = initialWeights
  for feature in AttackingFeature:
    result.momentum[feature] = 0.0
  result.learningRate = learningRate
  result.momentumCoeff = momentumCoeff
  result.c = c
  result.iteration = 1
  result.maxIterations = maxIterations

proc estimateGradientSPSA(optimizer: var SPSAOptimizer, trainingData: seq[GameData]): array[AttackingFeature, float] =
  let ck = optimizer.c / optimizer.iteration.float.pow(0.167)  # SPSA coefficient decay

  # Generate random perturbation vector
  var delta: array[AttackingFeature, float]
  for feature in AttackingFeature:
    delta[feature] = if rand(1.0) < 0.5: -1.0 else: 1.0

  # Compute weights with positive and negative perturbations
  var weightsPlus: array[AttackingFeature, float]
  var weightsMinus: array[AttackingFeature, float]

  for feature in AttackingFeature:
    let weight = optimizer.weights[feature]
    weightsPlus[feature] = weight + ck * delta[feature]
    weightsMinus[feature] = weight - ck * delta[feature]

    # Ensure weights stay non-negative
    weightsPlus[feature] = max(0.0, weightsPlus[feature])
    weightsMinus[feature] = max(0.0, weightsMinus[feature])

  # Evaluate loss at both points
  let lossPlus = calculateLoss(trainingData, weightsPlus)
  let lossMinus = calculateLoss(trainingData, weightsMinus)

  # Estimate gradient using SPSA
  for feature in AttackingFeature:
    result[feature] = (lossPlus - lossMinus) / (2.0 * ck * delta[feature])

proc updateWeights(optimizer: var SPSAOptimizer, gradient: array[AttackingFeature, float]) =
  let ak = optimizer.learningRate / (optimizer.iteration.float + optimizer.maxIterations.float / 10.0).pow(0.602)  # Learning rate decay

  for feature in AttackingFeature:
    # Update momentum
    optimizer.momentum[feature] = optimizer.momentumCoeff * optimizer.momentum[feature] + ak * gradient[feature]

    # Update weights
    optimizer.weights[feature] -= optimizer.momentum[feature]

    # # Ensure weights stay non-negative
    # optimizer.weights[feature] = max(0.0, optimizer.weights[feature])

  optimizer.iteration += 1

proc evaluatePerformance(dataset: seq[GameData], weights: array[AttackingFeature, float], datasetName: string) =
  if dataset.len == 0:
    echo "\n", datasetName, " is empty. Skipping evaluation."
    return

  var normalScores: seq[float] = @[]
  var attackingScores: seq[float] = @[]

  for data in dataset:
    let score = calculateScoreWithWeights(data.rawScores, weights)
    if data.targetLabel == 0.0:
      normalScores.add(score)
    else:
      attackingScores.add(score)

  echo "\n--- ", datasetName, " Performance ---"
  if normalScores.len > 0:
    let avgNormal = normalScores.foldl(a + b, 0.0) / normalScores.len.float
    echo "Average score for 'normal' games:   ", avgNormal.formatFloat(ffDecimal, 4), " (Target: 0.0)"
  else:
    echo "No 'normal' games in this set."

  if attackingScores.len > 0:
    let avgAttacking = attackingScores.foldl(a + b, 0.0) / attackingScores.len.float
    echo "Average score for 'attacking' games: ", avgAttacking.formatFloat(ffDecimal, 4), " (Target: 1.0)"
  else:
    echo "No 'attacking' games in this set."

proc createTrainTestSplit(data: seq[GameData], testSplit: float): (seq[GameData], seq[GameData]) =
  if testSplit == 0.0:
    return (data, @[])

  let splitIdx = int(data.len.float * (1.0 - testSplit))
  let trainData = data[0..<splitIdx]
  let testData = data[splitIdx..^1]
  return (trainData, testData)

proc writeFeatureWeightsFile(weights: array[AttackingFeature, float]) =
  ##[
  Write the feature weights directly to the source file.
  ]##
  let filePath = "src/paramfeatures.nim"

  var content = fmt"""##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tune_weights script on {now().utc}.
]##

import features

const featureWeights* = [
"""

  for feature in AttackingFeature:
    content.add(fmt"  {feature}: {weights[feature]:.6f}," & "\n")

  content.add("]\n")

  try:
    writeFile(filePath, content)
    echo fmt"Successfully updated {filePath}"
  except Exception as e:
    echo fmt"Error writing to {filePath}: {e.msg}"

proc main() =
  var normalGamesDir = "./data/non_attacking_games"
  var attackingGamesDir = "./data/attacking_games"
  var maxGamesPerClass = 500000
  var maxIterations = 5000
  var testSplit = 0.0
  var learningRate = 10.0
  var momentumCoeff = 0.5
  var spsa_c = 0.1

  # Parse command line arguments
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "normal-games-dir":
        normalGamesDir = p.val
      of "attacking-games-dir":
        attackingGamesDir = p.val
      of "max-games-per-class":
        maxGamesPerClass = parseInt(p.val)
      of "iterations":
        maxIterations = parseInt(p.val)
      of "test-split":
        testSplit = parseFloat(p.val)
      of "learning-rate":
        learningRate = parseFloat(p.val)
      of "momentum":
        momentumCoeff = parseFloat(p.val)
      of "spsa-c":
        spsa_c = parseFloat(p.val)
      of "help", "h":
        echo "Usage: tune_weights [options]"
        echo "Options:"
        echo "  --normal-games-dir DIR       Path to folder with 'normal' PGNs (default: ", normalGamesDir, ")"
        echo "  --attacking-games-dir DIR    Path to folder with 'attacking' PGNs (default: ", attackingGamesDir, ")"
        echo "  --max-games-per-class N      Maximum games per class (default: ", maxGamesPerClass, ")"
        echo "  --iterations N               Number of optimization iterations (default: ", maxIterations, ")"
        echo "  --test-split F               Fraction for test set (default: ", testSplit, ")"
        echo "  --learning-rate F            Learning rate (default: ", learningRate, ")"
        echo "  --momentum F                 Momentum coefficient (default: ", momentumCoeff, ")"
        echo "  --spsa-c F                   SPSA perturbation magnitude (default: ", spsa_c, ")"
        return
      else:
        echo "Unknown option: ", p.key
        return
    of cmdArgument:
      discard

  randomize()

  # Pre-process all data
  let normalData = preprocessGamesFromFolder(normalGamesDir, 0.0, maxGamesPerClass)
  let attackingData = preprocessGamesFromFolder(attackingGamesDir, 1.0, maxGamesPerClass)

  # Create train/test splits
  if testSplit == 0.0:
    echo "\nNo test set will be created (test_split=0.0). All data will be used for training."
  else:
    echo "\nCreating ", int((1.0 - testSplit) * 100), "/", int(testSplit * 100), " train-test splits..."

  let (normalTrain, normalTest) = createTrainTestSplit(normalData, testSplit)
  let (attackingTrain, attackingTest) = createTrainTestSplit(attackingData, testSplit)

  # Keep training data separated by class for balanced sampling
  let normalTrainData = normalTrain
  let attackingTrainData = attackingTrain
  var allTrainingData = normalTrain & attackingTrain
  let allTestingData = normalTest & attackingTest

  # Create balanced dataset for loss evaluation (oversampling minority class)
  let balancedTrainingData = createBalancedDataset(normalTrainData, attackingTrainData)

  shuffle(allTrainingData)

  echo "Total training examples: ", allTrainingData.len, " (", normalTrain.len, " normal, ", attackingTrain.len, " attacking)"
  if testSplit > 0.0:
    echo "Total testing examples:  ", allTestingData.len, " (", normalTest.len, " normal, ", attackingTest.len, " attacking)"
  else:
    echo "Total testing examples:  0 (no test set)"

  if allTrainingData.len == 0:
    echo "\nError: Training data is empty. Cannot proceed with optimization."
    return

  # Initialize optimizer with all weights set to 1.0
  var initialWeights: array[AttackingFeature, float]
  for feature in AttackingFeature:
    initialWeights[feature] = 1.0
  var optimizer = initSPSAOptimizer(initialWeights, maxIterations, learningRate, momentumCoeff, spsa_c)

  # Training loop
  echo "\nStarting SPSA optimization with ", maxIterations, " iterations..."
  var bestLoss = Inf
  var bestWeights = optimizer.weights

  for iteration in 1..maxIterations:

    let gradient = estimateGradientSPSA(optimizer, balancedTrainingData)
    updateWeights(optimizer, gradient)

    let currentLoss = calculateLoss(balancedTrainingData, optimizer.weights)

    if currentLoss < bestLoss:
      bestLoss = currentLoss
      bestWeights = optimizer.weights

    if iteration mod 50 == 0 or iteration == maxIterations:
      echo "Iteration ", iteration, ", Loss: ", currentLoss.formatFloat(ffDecimal, 6),
           ", Best Loss: ", bestLoss.formatFloat(ffDecimal, 6)

  echo "\n\n--- Optimization Complete ---"
  echo "Best Mean Absolute Error on Training Set: ", bestLoss.formatFloat(ffDecimal, 6)

  # Write to file
  writeFeatureWeightsFile(bestWeights)

  echo "\nOptimized feature weights have been written to src/paramfeatures.nim"

  # Evaluate final model
  evaluatePerformance(allTrainingData, bestWeights, "Training Set")
  if testSplit > 0.0:
    evaluatePerformance(allTestingData, bestWeights, "Test Set")

when isMainModule:
  main()
