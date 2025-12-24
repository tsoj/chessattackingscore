import std/[strutils, options]
import nimchess

type
  GameResult* = enum
    Loss
    Draw
    Win

func resultForPlayer*(game: Game, playerName: string): GameResult =
  let playerColor =
    if game.headers.getOrDefault("White") == playerName: white else: black
  let
    termination = game.headers.getOrDefault("Termination", "").toLower()
    isDraw =
      "time forfeit" in termination or game.headers.getOrDefault("Result") == "1/2-1/2"

  if isDraw:
    Draw
  elif game.headers.getOrDefault("Result") ==
      (if playerColor == white: "1-0" else: "0-1"):
    Win
  else:
    Loss

func getWinner*(game: Game): Option[string] =
  let res = game.headers.getOrDefault("Result")
  if res == "1-0":
    return some(game.headers.getOrDefault("White", "?"))
  elif res == "0-1":
    return some(game.headers.getOrDefault("Black", "?"))
  return none(string)

func shouldIncludeGame*(
    game: Game, minRating: int = 0, eventFilter: seq[string] = @[]
): bool =
  # Apply event filter if specified
  if eventFilter.len > 0:
    let event = game.headers.getOrDefault("Event", "").toLower()
    var found = false
    for filter in eventFilter:
      if filter.toLower() in event:
        found = true
        break
    if not found:
      return false

  # Check player names
  let
    whitePlayer = game.headers.getOrDefault("White", "?")
    blackPlayer = game.headers.getOrDefault("Black", "?")

  if "?" in [whitePlayer, blackPlayer]:
    return false

  # Filter by minimum rating
  if minRating > 0:
    try:
      let
        whiteElo = parseInt(game.headers.getOrDefault("WhiteElo", "0"))
        blackElo = parseInt(game.headers.getOrDefault("BlackElo", "0"))
        minElo = min(whiteElo, blackElo)

      if minElo < minRating:
        return false
    except ValueError:
      return false

  return true

proc writeGameToPgn*(game: Game, score: float, player: string, path: string) =
  try:
    let f = open(path, fmAppend)
    defer:
      f.close()
    var outputGame = game

    const canonicalOrder =
      ["Event", "Site", "Date", "Round", "White", "Black", "Result"]

    for key in canonicalOrder:
      if outputGame.headers.hasKey(key):
        f.writeLine(&"[{key} \"{outputGame.headers[key]}\"]")

    f.writeLine(fmt"[AttackingScore \"" & $score & "\"")
    f.writeLine(&"[AttackingScore \"{score:.6f}\"]")
    f.writeLine(&"[AttackingPlayer \"{player}\"]")

    for k, v in outputGame.headers.pairs:
      if k notin canonicalOrder:
        f.writeLine(&"[{k} \"{v}\"]")

    f.writeLine("")

    let fullPgn = outputGame.toPgnString()
    let parts = fullPgn.split("\n\n", maxsplit = 1)
    if parts.len == 2:
      f.writeLine(parts[1])

    f.writeLine("")
  except IOError:
    echo "Warning: Failed to append game to ", path
