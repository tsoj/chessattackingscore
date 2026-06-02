# Chess Attacking Score

A tool to analyze PGNs and score players for attacking style

## Build

Note: Prebuild binaries can be found on the [release page](https://github.com/tsoj/chessattackingscore/releases).

### Optional: Retune normalization and feature weights:
```bash
nimble calcParams
```

### Build executable
```bash
nimble build
```

## Basic Usage

Analyze aggression for all players in a PGN file:
```bash
./chessattackingscore --pgn=games.pgn
```

Analyze a specific player:
```bash
./chessattackingscore --pgn=games.pgn --player="Glaurung"
```

You can also write the most aggressive winning games into a new pgn
```bash
./chessattackingscore --pgn=games.pgn --win_pgn=aggressive.pgn --win_threshold=0.8
```
