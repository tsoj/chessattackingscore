import std/[os, strutils, sequtils, math, random, strformat, times, options]
import nimchess
import features, utils, core

type GameData = tuple[rawScores: array[AttackingFeature, float], targetLabel: float]

const
  attackingTarget = 1.0
  normalTarget = 0.5

proc preprocessGamesFromFolder(
    folderPath: string, targetLabel: float, maxGamesPerClass: int
): seq[GameData] =
  echo "\nProcessing games from '",
    folderPath, "' with target score ", targetLabel, "..."

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

  # let isAttackingSet = (targetLabel == 1.0)

  for pgnPath in pgnFiles:
    if processedData.len >= maxGamesPerClass:
      echo "\nReached max_games_per_class limit of ", maxGamesPerClass, " for this set."
      break

    echo "path: ", pgnPath
    for game in readPgnFileIter(pgnPath):
      if processedData.len >= maxGamesPerClass:
        break

      let winnerOpt = getWinner(game)

      if game.shouldIncludeGame and winnerOpt.isSome:
        let winnerPlayerName = winnerOpt.get()
        if winnerPlayerName != "?":
          let stats = analyseGame(game, winnerPlayerName)
          let rawScores = getRawFeatureScores(stats)
          processedData.add((rawScores, targetLabel))

  # Shuffle the data
  shuffle(processedData)

  echo "Found ", processedData.len, " valid player-perspectives in ", folderPath, "."
  return processedData

proc calculateLoss(trainingData: seq[GameData], weights: FeatureWeights): float =
  var totalError = 0.0

  for data in trainingData:
    let predictedScore = getAttackingScore(data.rawScores, weights)
    totalError += (predictedScore - data.targetLabel) ^ 2

  return totalError / trainingData.len.float

proc calculateGradient(
    weights: FeatureWeights, trainingData: seq[GameData]
): FeatureWeights =
  if trainingData.len == 0:
    return
  let invCount = 1.0 / trainingData.len.float

  for data in trainingData:
    let normalizedScores = getNormalizedFeatureScores(data.rawScores)
    var linearScore = 0.0
    for feature in AttackingFeature:
      linearScore += weights.weights[feature] * normalizedScores[feature]

    let predicted = 1.0 / (1.0 + exp(-linearScore))
    let error = predicted - data.targetLabel
    let dLossDz = 2.0 * error * predicted * (1.0 - predicted)

    for feature in AttackingFeature:
      result.weights[feature] += dLossDz * normalizedScores[feature]

  for feature in AttackingFeature:
    result.weights[feature] *= invCount

proc calibrateBiasForNormalMean(
    weights: var FeatureWeights,
    normalData: seq[GameData],
    targetMean: float = normalTarget,
) =
  ## Adjusts only `weights[bias]` so mean prediction on `normalData` equals `targetMean`.
  doAssert normalData.len > 0

  # Calculate current mean prediction
  var currentMean = 0.0
  for data in normalData:
    currentMean += getAttackingScore(data.rawScores, weights)
  currentMean /= normalData.len.float

  # Simple iterative adjustment
  let error = targetMean - currentMean
  weights.bias += error * 2.0 # Scale factor to speed up convergence

proc updateWeights(
    currentWeights: var FeatureWeights, gradient: FeatureWeights, lr: float
) =
  for feature in AttackingFeature:
    currentWeights.weights[feature] -= lr * gradient.weights[feature]

proc evaluatePerformance(
    normalDataset: seq[GameData],
    attackingDataset: seq[GameData],
    weights: FeatureWeights,
    datasetName: string,
) =
  doAssert normalDataset.len > 0 and attackingDataset.len > 0

  var normalScores: seq[float] = @[]
  var attackingScores: seq[float] = @[]

  for data in normalDataset:
    let score = getAttackingScore(data.rawScores, weights)
    normalScores.add(score)

  for data in attackingDataset:
    let score = getAttackingScore(data.rawScores, weights)
    attackingScores.add(score)

  echo "\n--- ", datasetName, " Performance ---"

  if normalScores.len > 0:
    let avgNormal = normalScores.foldl(a + b, 0.0) / normalScores.len.float
    echo fmt"Average score for 'normal' games:   {avgNormal.formatFloat(ffDecimal, 4)} (Target: {normalTarget})"
  else:
    echo "No 'normal' games in this set."

  if attackingScores.len > 0:
    let avgAttacking = attackingScores.foldl(a + b, 0.0) / attackingScores.len.float
    echo fmt"Average score for 'attacking' games: {avgAttacking.formatFloat(ffDecimal, 4)} (Target: {attackingTarget})"
  else:
    echo "No 'attacking' games in this set."

proc createTrainTestSplit(
    data: seq[GameData], testSplit: float
): (seq[GameData], seq[GameData]) =
  if testSplit == 0.0:
    return (data, @[])

  var data = data
  data.shuffle

  let splitIdx = int(data.len.float * (1.0 - testSplit))
  let trainData = data[0 ..< splitIdx]
  let testData = data[splitIdx ..^ 1]
  return (trainData, testData)

proc writeFeatureWeightsFile(weights: FeatureWeights) =
  ##[
  Write the feature weights directly to the source file.
  ]##
  let filePath = "src/paramfeatures.nim"

  var content =
    fmt"""##[
Feature weights for chess attacking score calculation.
These weights determine the relative importance of each attacking feature.

This file is automatically updated by the tuneweights.nim script on {now().utc}.
]##

import features

const featureWeights* = FeatureWeights(
  weights: [
"""

  for feature in AttackingFeature:
    content.add(fmt"    {feature}: {weights.weights[feature]:.6f}," & "\n")

  content.add(
    fmt"""
  ],
  bias: {weights.bias:.6f},
)
"""
  )

  try:
    writeFile(filePath, content)
    echo fmt"Successfully updated {filePath}"
  except Exception as e:
    echo fmt"Error writing to {filePath}: {e.msg}"

proc main() =
  const
    logInterval = 500
    normalGamesDir = "./data/non_attacking_games"
    attackingGamesDir = "./data/attacking_games"
    maxGamesPerClass = 500000
    maxIterations = 5000
    testSplit = 0.0
    learningRate = 0.1

  randomize(8767128)

  # Pre-process all data
  let normalData =
    preprocessGamesFromFolder(normalGamesDir, normalTarget, maxGamesPerClass)
  var attackingData =
    preprocessGamesFromFolder(attackingGamesDir, attackingTarget, maxGamesPerClass)

  # Create train/test splits
  if testSplit == 0.0:
    echo "\nNo test set will be created (test_split=0.0). All data will be used for training."
  else:
    echo "\nCreating ",
      int((1.0 - testSplit) * 100), "/", int(testSplit * 100), " train-test splits..."

  let (normalTrain, normalTest) = createTrainTestSplit(normalData, testSplit)
  let (attackingTrain, attackingTest) = createTrainTestSplit(attackingData, testSplit)

  echo "Training examples: ",
    normalTrain.len, " normal, ", attackingTrain.len, " attacking"
  if testSplit > 0.0:
    echo "Testing examples: ",
      normalTest.len, " normal, ", attackingTest.len, " attacking"
  else:
    echo "Tsting examples:  0 (no test set)"

  doAssert attackingTrain.len > 0,
    "No attacking training data. Cannot compute attacking-only gradients."
  doAssert normalTrain.len > 0, "No normal training data. Bias cannot be recalibrated."

  # Initialize optimizer with all weights set to 1.0
  var
    currentWeights: FeatureWeights
    runningLoss = 0.0

  # Training loop
  echo "\nStarting attacking-only full-batch gradient descent with ",
    maxIterations, " iterations..."
  if normalTrain.len > 0:
    echo "Bias is recalibrated each iteration so mean 'normal' prediction is ",
      normalTarget.formatFloat(ffDecimal, 3)

  for iteration in 1 .. maxIterations:
    var currentTrain = normalTrain
    currentTrain.shuffle
    currentTrain.setLen min(currentTrain.len, attackingTrain.len)
    currentTrain.add attackingTrain

    let gradient = calculateGradient(currentWeights, currentTrain)
    updateWeights(currentWeights, gradient, learningRate)
    calibrateBiasForNormalMean(currentWeights, normalTrain)

    let currentLoss = calculateLoss(currentTrain, currentWeights)
    runningLoss += currentLoss

    if iteration mod logInterval == 0 or iteration == maxIterations:
      echo "Iteration ",
        iteration,
        ", Loss: ",
        formatFloat(runningLoss / logInterval.float, ffDecimal, 6)
      runningLoss = 0.0

  echo "\n\n--- Optimization Complete ---"

  # Write to file
  writeFeatureWeightsFile(currentWeights)

  echo "\nOptimized feature weights have been written to src/paramfeatures.nim"

  # Evaluate final model
  evaluatePerformance(normalTrain, attackingTrain, currentWeights, "Training Set")
  if testSplit > 0.0:
    evaluatePerformance(normalTest, attackingTest, currentWeights, "Test Set")

when isMainModule:
  main()
