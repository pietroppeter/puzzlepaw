# Puzzlepaw

Nim puzzle game framework (6x6 letter grid puzzles).

## Project Structure

- `src/pzlpaw.nim` - Main TUI entry point (menu: Play, Craft, Quit)
- `src/parloku/types.nim` - Core types (Grid, Problem, Puzzle, etc.)
- `src/parloku/values.nim` - Shared constants (gridSize, boxRows, boxCols, etc.)
- `src/parloku/io.nim` - Pretty-print display + JSON serialization (jsony)
- `src/parloku/play.nim` - Play mode TUI (puzzle selection + gameplay)
- `src/parloku/craft.nim` - Craft mode TUI (create/edit puzzles)
- `data/` - Puzzle JSON files (puzzle1.json, puzzle2.json, ...)
- `tests/test_io.nim` - Tests for io module (printing + serialization)

## Build & Test

```
nimble test            # run tests
nim c src/pzlpaw.nim   # compile TUI app
nim r src/pzlpaw.nim   # compile and run
nimble play            # run via task
```

## Conventions

- Types go in `types.nim`, shared constants in `values.nim`
- Module-specific constants (e.g. TUI layout) stay in their own module
- JSON serialization uses jsony (automatic for all types)
- Puzzles are stored as JSON in `data/` with naming `puzzleN.json`
- Plans and session logs live in `claude/`
- Add compiled binaries to `.gitignore` when creating new entry points
