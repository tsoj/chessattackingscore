# Chess Attacking Score

A tool to analyze PGNs and score players for attacking style

## Build

### Optional: Retune normalization and feature weights:
```
nimble calcParams
```

### Build executable
```bash
nimble build
```

## Basic Usage

Analyze aggression for all players in a PGN file:
```bash
chessattackingscore --pgn=games.pgn
```

Analyze a specific player:
```bash
chessattackingscore --pgn=games.pgn --player="Glaurung"
```
