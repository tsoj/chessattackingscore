import std/[os, tables, sequtils, strutils, math, algorithm, parseopt, strformat, sugar]
import nimchess
import utils, core

export nimchess, core

#----------- CLI -----------#

type AnalysisArgs = object
  pgnPath: string
  player: string
  maxGames: int
  minGames: int
  minRating: int
  topN: int
  eventFilter: seq[string]
  includeLosses: bool
  includeDraws: bool
  winPgnPath: string
  lossPgnPath: string
  drawPgnPath: string
  winThreshold: float
  lossThreshold: float
  drawThreshold: float

proc parseArguments(): AnalysisArgs =
  result = AnalysisArgs(
    pgnPath: "",
    player: "",
    maxGames: 0,
    minGames: 10,
    minRating: 0,
    topN: 1,
    eventFilter: @[],
    includeLosses: false,
    includeDraws: false,
    winPgnPath: "",
    lossPgnPath: "",
    drawPgnPath: "",
    winThreshold: 0.7,
    lossThreshold: 0.7,
    drawThreshold: 0.7,
  )

  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "pgn":
        result.pgnPath = p.val
      of "player":
        result.player = p.val
      of "games":
        result.maxGames = p.val.parseInt
      of "min_games", "min-games":
        result.minGames = p.val.parseInt
      of "min_rating", "min-rating":
        result.minRating = p.val.parseInt
      of "top_n", "top-n":
        result.topN = p.val.parseInt
      of "event_filter", "event-filter":
        result.eventFilter.add(p.val)
      of "losses":
        result.includeLosses = true
      of "draws":
        result.includeDraws = true
      of "win_pgn", "win-pgn":
        result.winPgnPath = p.val
      of "loss_pgn", "loss-pgn":
        result.lossPgnPath = p.val
      of "draw_pgn", "draw-pgn":
        result.drawPgnPath = p.val
      of "win_threshold", "win-threshold":
        result.winThreshold = p.val.parseFloat
      of "loss_threshold", "loss-threshold":
        result.lossThreshold = p.val.parseFloat
      of "draw_threshold", "draw-threshold":
        result.drawThreshold = p.val.parseFloat
      of "output_pgn", "output-pgn":
        # Legacy support
        result.winPgnPath = p.val
      of "save_threshold", "save-threshold":
        # Legacy support
        let val = p.val.parseFloat
        result.winThreshold = val
        result.lossThreshold = val
        result.drawThreshold = val
      of "help", "h":
        echo """
A tool to analyze PGNs and score players for attacking style

Usage: chessattackingscore [options]

Options:
  --pgn=PATH              Path to the PGN file (required)
  --player=NAME           Name of a specific player to analyze (default: all players)
  --games=N               Maximum number of games to process
  --min_games=N           Minimum games for a player to be included (default: 10)
  --min_rating=N          Minimum rating for the lower-rated player (default: 0)
  --top_n=N               Number of top/bottom games to display (default: 10)
  --event_filter=TYPE     Filter games by event types (can be used multiple times)
  --losses                Include games where the player lost (default: only wins)
  --draws                 Include games where the player drew (default: only wins)
  --win_pgn=PATH          Path to save PGNs of aggressive won games
  --loss_pgn=PATH         Path to save PGNs of aggressive lost games
  --draw_pgn=PATH         Path to save PGNs of aggressive drawn games
  --win_threshold=N       Score threshold (0.0 - 1.0) for won games (default: 0.7)
  --loss_threshold=N      Score threshold (0.0 - 1.0) for lost games (default: 0.7)
  --draw_threshold=N      Score threshold (0.0 - 1.0) for drawn games (default: 0.7)
  --help, -h              Show this help message

Examples:
  chessattackingscore --pgn=games.pgn --player="Magnus Carlsen"
  chessattackingscore --pgn=games.pgn --min_rating=2400 --top_n=5
  chessattackingscore --pgn=games.pgn --win_pgn=aggressive_wins.pgn --win_threshold=0.8
"""
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      echo "Unexpected argument: ", p.key
      quit(1)

proc processGames(args: AnalysisArgs) =
  var
    allPlayerScores = initTable[string, seq[float]]()
    allPlayerRecords = initTable[string, tuple[wins: int, draws: int, losses: int]]()
    gameScores: seq[(Game, float, string)] = @[] # (Game, Score, Player)
    gamesProcessed = 0
    gamesFilteredByRating = 0
    gamesSaved = 0

  let isSinglePlayer = args.player.len > 0

  echo if isSinglePlayer:
    fmt"Analyzing games for player '{args.player}'..."
  else:
    "Analyzing all players..."

  try:
    for game in readPgnFileIter(args.pgnPath):
      if args.maxGames > 0 and gamesProcessed >= args.maxGames:
        echo "Reached game limit of ", args.maxGames
        break

      if not shouldIncludeGame(game, args.minRating, args.eventFilter):
        if args.minRating > 0:
          inc gamesFilteredByRating
        continue

      let playersToAnalyze =
        if isSinglePlayer:
          let
            white = game.headers.getOrDefault("White", "?")
            black = game.headers.getOrDefault("Black", "?")
          if args.player == white or args.player == black:
            @[args.player]
          else:
            @[]
        else:
          let
            white = game.headers.getOrDefault("White", "?")
            black = game.headers.getOrDefault("Black", "?")
          @[white, black]

      for player in playersToAnalyze:
        if "?" in player:
          continue

        let res = resultForPlayer(game, player)

        # Apply result filter
        if res == Loss and not (args.includeLosses or args.lossPgnPath.len > 0):
          continue
        if res == Draw and not (args.includeDraws or args.drawPgnPath.len > 0):
          continue

        let stats = analyseGame(game, player)
        let score = getAttackingScore(stats)

        # PGN Writing
        let (outPgnPath, threshold) =
          case res
          of Win:
            (args.winPgnPath, args.winThreshold)
          of Loss:
            (args.lossPgnPath, args.lossThreshold)
          of Draw:
            (args.drawPgnPath, args.drawThreshold)

        if outPgnPath.len > 0 and score >= threshold:
          writeGameToPgn(game, score, player, outPgnPath)
          inc gamesSaved

        # Collect stats
        if res == Win or (res == Loss and args.includeLosses) or
            (res == Draw and args.includeDraws):
          if not allPlayerScores.hasKey(player):
            allPlayerScores[player] = @[]
            allPlayerRecords[player] = (0, 0, 0)

          allPlayerScores[player].add(score)
          case res
          of Win:
            inc allPlayerRecords[player].wins
          of Draw:
            inc allPlayerRecords[player].draws
          of Loss:
            inc allPlayerRecords[player].losses

          # Save to game list for top_n reporting
          gameScores.add((game, score, player))

      inc gamesProcessed
      if gamesProcessed mod 1000 == 0:
        stdout.write(&"\rProcessed {gamesProcessed} games...")
        stdout.flushFile()

    echo "\n--- Analysis Complete ---"
    if gamesFilteredByRating > 0:
      echo "Filtered out ", gamesFilteredByRating, " games due to rating requirements."

    if gamesSaved > 0:
      echo "Total games saved to PGN files: ", gamesSaved

    # Top and Least aggressive games
    if gameScores.len > 0:
      gameScores.sort((a, b) => cmp(b[1], a[1]))

      echo "\n--- Top ", min(args.topN, gameScores.len), " Most Aggressive Games ---"
      for i in 0 ..< min(args.topN, gameScores.len):
        let (game, score, player) = gameScores[i]
        echo "-".repeat(50)
        echo fmt"""Score: {score.formatFloat(ffDecimal, 2)} - {game.headers.getOrDefault("Site", "?")} - {player}"""
        echo fmt"""White: {game.headers.getOrDefault("White", "?")}, Black: {game.headers.getOrDefault("Black", "?")}"""
        echo game.toPgnString()

      echo "\n--- Top ", min(args.topN, gameScores.len), " Least Aggressive Games ---"
      for i in 0 ..< min(args.topN, gameScores.len):
        let (game, score, player) = gameScores[gameScores.len - 1 - i]
        echo "-".repeat(50)
        echo fmt"""Score: {score.formatFloat(ffDecimal, 2)} - {game.headers.getOrDefault("Site", "?")} - {player}"""
        echo fmt"""White: {game.headers.getOrDefault("White", "?")}, Black: {game.headers.getOrDefault("Black", "?")}"""
        echo game.toPgnString()

    if isSinglePlayer:
      if not allPlayerScores.hasKey(args.player):
        echo "No games found for player '", args.player, "'"
        return
      let
        scores = allPlayerScores[args.player]
        avgScore = scores.sum / scores.len.float
      echo "\nOverall Stats for ", scores.len, " games:"
      echo "Average Attacking Score: ", avgScore.formatFloat(ffDecimal, 2), " / 100.0"
    else:
      # All players mode ranking
      type PlayerResult =
        tuple[player: string, score: float, stdev: float, numGames: int, record: string]

      var playerResults: seq[PlayerResult] = @[]

      for player, scores in allPlayerScores.pairs:
        if scores.len >= args.minGames:
          let
            numGames = scores.len
            mean = scores.sum / numGames.float
            stdev =
              sqrt(scores.mapIt((it - mean) ^ 2).sum / max(1, (numGames - 1)).float)
            rec = allPlayerRecords[player]
            recordStr = $rec.wins & " / " & $rec.draws & " / " & $rec.losses
          playerResults.add((player, mean, stdev, numGames, recordStr))

      if playerResults.len == 0:
        echo "No players found with at least ", args.minGames, " games."
      else:
        playerResults.sort((a, b) => cmp(b.score, a.score))
        echo "\nAttacking ranking for ",
          playerResults.len, " players with at least ", args.minGames, " games:"
        echo "-".repeat(110)
        echo fmt"""{"Rank":<5} {"Player":<30} {"Agg. Score":<15} {"StdDev":<15} {"Games":<10} {"Record (W/D/L)":<20}"""
        echo "-".repeat(110)
        for i, res in playerResults.pairs:
          echo fmt"""{$(i + 1):<5} {res.player:<30} {res.score.formatFloat(ffDecimal, 4):<15} {res.stdev.formatFloat(ffDecimal, 4):<15} {$(res.numGames):<10} {res.record:<20}"""
  except IOError as e:
    echo "Error: ", e.msg
    quit(1)

proc main() =
  let args = parseArguments()
  if args.pgnPath.len == 0:
    echo "Error: --pgn is required\nUse --help for usage information"
    quit(1)

  for outFile in [args.winPgnPath, args.lossPgnPath, args.drawPgnPath]:
    if outFile.len > 0 and fileExists(outFile):
      echo "Error: File already exists: ", outfile
      quit(1)

  processGames(args)

when isMainModule:
  main()
