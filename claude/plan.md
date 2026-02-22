# Plan: Serialization, Craft Mode & TUI Restructuring

Status: **COMPLETED**

## What was done

### Step 1: jsony + serialization + data/puzzle1.json

- Added jsony dependency via atlas
- Added `savePuzzle`, `loadPuzzle`, `listPuzzles` to `io.nim`
- Created `data/puzzle1.json` from the example puzzle
- Added round-trip serialization tests to `test_io.nim`

### Step 2: Main entry point + play refactor

- Created `src/pzlpaw.nim` with main menu (Play, Craft, Quit)
- Refactored `play.nim`: added `selectPuzzle`, `play` now returns instead of quitting, removed `isMainModule`
- Updated `config.nims` to point to `pzlpaw.nim`

### Step 3: craft.nim module

- Created `src/parloku/craft.nim` with full illwill TUI
- Three modes: Letters (set 6 letters), Solution (fill grid), Hints (letter/word hints)
- Save with auto-incrementing filenames, load existing puzzles for editing
- `selectAndCraft` menu for new/edit selection

### Step 4: Wiring + cleanup

- Wired craft into pzlpaw main menu
- Updated CLAUDE.md with new project structure

## Previous plan (completed earlier)

Refactoring: renamed Solution to Grid, added Puzzle type, extracted shared constants to values.nim.
