# Chess Attacking Score

A tool to analyze PGNs and score players for attacking style

## Build

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

You can also write the most aggressive games into a new pgn
```bash
./chessattackingscore --pgn=games.pgn --output_pgn=aggressive.pgn --save_threshold=0.8
```
