# Package

version = "0.3.0"
author = "Jost Triller"
description = "A tool to analyze PGNs and score players for attacking style"
license = "MIT"
srcDir = "src"
installExt = @["nim"]
bin = @["chessattackingscore"]

requires "nim >= 2.2.4"
requires "nimchess >= 0.2.4"

task calcParams, "Calculate normalization and feature weight parameters from PGN files":
  exec "nim r src/calcnorm.nim"
  exec "nim r src/tuneweights.nim"
  echo "Done"
