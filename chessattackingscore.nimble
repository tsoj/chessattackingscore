# Package

version       = "0.1.0"
author        = "Jost Triller"
description   = "A tool to analyze PGNs and score players for attacking style"
license       = "MIT"
srcDir        = "src"
bin           = @["chessattackingscore"]


# Dependencies

requires "nim >= 2.2.4"
requires "https://github.com/tsoj/nimchess >= 0.1.0"

# Tasks

task calculate_normalization, "Calculate normalization parameters from PGN files":
  exec "nim compile --run calculate_normalization.nim"

task tune_weights, "Optimize feature weights using SPSA":
  exec "nim compile --run tune_weights.nim"
