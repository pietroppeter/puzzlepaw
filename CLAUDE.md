# Puzzlepaw

Nim puzzle game framework (6x6 letter grid puzzles).

## Project Structure

- `src/parloku/types.nim` - Core types (Grid, Problem, Puzzle, etc.)
- `src/parloku/values.nim` - Shared constants (gridSize, boxRows, boxCols, etc.)
- `src/parloku/io.nim` - Pretty-print display functions
- `src/parloku/play.nim` - Interactive TUI game (uses illwill)
- `tests/test_io.nim` - Tests for io module

## Build & Test

```
nimble test        # run tests
nim c src/parloku/play.nim  # compile TUI app
```

## Conventions

- Types go in `types.nim`, shared constants in `values.nim`
- Module-specific constants (e.g. TUI layout) stay in their own module
- Plans and session logs live in `claude/`
