# Puzzlepaw

Nim puzzle game framework (6x6 letter grid puzzles).

## Project Structure

- `src/pzlpaw.nim` - Main TUI entry point (menu: Play, Craft, Quit)
- `src/parloku/types.nim` - Core types (Grid, Problem, Puzzle, etc.)
- `src/parloku/values.nim` - Shared constants (gridSize, boxRows, boxCols, etc.)
- `src/parloku/io.nim` - Pretty-print display + JSON serialization (jsony)
- `src/parloku/play.nim` - Play mode TUI (puzzle selection + gameplay)
- `src/parloku/craft.nim` - Craft mode TUI (create/edit puzzles)
- `src/parloku/solver.nim` - Constraint solver: count/enumerate solutions, candidates, word starts, grid checks (no os/jsony: must keep compiling with `nim js`)
- `src/parloku/code.nim` - Compact URL-safe problem code (`LETTERS_GIVENS_WORDS`), JS-compatible
- `src/pzlsolve.nim` - Solver CLI (puzzle JSON file or problem code)
- `data/` - Puzzle JSON files (naming: `puzzleN-WORD1-WORD2-WORD3.json`, e.g. `puzzle1-ITALIA-PASTA-ALPI.json`)
- `tests/test_io.nim` - Tests for io module (printing + serialization)
- `tests/test_solver.nim` - Solver and code tests (uses the answer keys in `data/`)

## Build & Test

```
nimble test            # run tests
nim c src/pzlpaw.nim   # compile TUI app
nim r src/pzlpaw.nim   # compile and run
nimble play            # run via task
nim r -d:release src/pzlsolve.nim data/puzzle1-ITALIA-PASTA-ALPI.json   # solver CLI
nim js -d:nodejs -r tests/test_solver_js.nim                            # JS backend check
```

## Conventions

- Types go in `types.nim`, shared constants in `values.nim`
- Module-specific constants (e.g. TUI layout) stay in their own module
- JSON serialization uses jsony (automatic for all types)
- Puzzles are stored as JSON in `data/` with naming `puzzleN-WORD1-WORD2-WORD3.json`; word hints are embedded in the filename so the TUI can display them without reading file contents
- Plans and session logs live in `claude/`
- Add compiled binaries to `.gitignore` when creating new entry points
