# Refactoring Plan: Types & Shared Values

## Goals

1. Rename `Solution` to `Grid` and use it in multiple places (including `GameState.grid`)
2. Add a `Puzzle` type with `problem: Problem` and `solution: Grid` fields
3. Extract duplicated constants from `io.nim` and `play.nim` into a new `values.nim`

---

## Current State

### Types (in `src/parloku/types.nim`)

- `Coord` = `tuple[row, col: int]`
- `HintLetter` = object with `pos: Coord`, `letter: char`
- `HintWord` = object with `pos: Coord`, `word: string`
- `Problem` = object with `letters: array[6, char]`, `letterHints: seq[HintLetter]`, `wordHints: seq[HintWord]`
- `Solution` = `array[6, array[6, char]]` -- the 6x6 grid

### Duplicated Constants

Both `io.nim` and `play.nim` define:
```nim
const
  boxRows = 2
  boxCols = 3
  gridSize = 6
```

`play.nim` additionally defines:
```nim
const
  gridX = 2
  gridY = 3
  hLine = "+-------+-------+"
const wordColors = [fgRed, fgMagenta, fgBlue, fgYellow, fgGreen, fgCyan]
```

### Type usage across files

| Type       | types.nim | io.nim | play.nim | test_io.nim |
|------------|-----------|--------|----------|-------------|
| Coord      | def       | used   | used     | -           |
| HintLetter | def       | used   | used     | used        |
| HintWord   | def       | used   | used     | used        |
| Problem    | def       | used   | used     | used        |
| Solution   | def       | used   | used     | used        |
| GameState  | -         | -      | def+used | -           |

---

## Step-by-Step Plan

### Step 1: Create `src/parloku/values.nim`

Create a new file with the shared constants extracted from both `io.nim` and `play.nim`:

```nim
const
  gridSize* = 6
  boxRows* = 2
  boxCols* = 3
```

Only move constants that are shared (duplicated) between files. Keep `play.nim`-specific constants (`gridX`, `gridY`, `hLine`, `wordColors`) in `play.nim` since they are TUI-specific and not shared.

### Step 2: Rename `Solution` to `Grid` in `types.nim`

In `src/parloku/types.nim`, change:

```nim
Solution* = array[6, array[6, char]]
```

to:

```nim
Grid* = array[6, array[6, char]]
```

### Step 3: Add `Puzzle` type in `types.nim`

Add a new type after `Problem` and `Grid`:

```nim
Puzzle* = object
  problem*: Problem
  solution*: Grid
```

### Step 4: Update `GameState` in `play.nim`

Change `GameState` to use `Grid` instead of raw arrays:

```nim
# Before
solution: Solution
grid: array[6, 6, char]

# After
solution: Grid
grid: Grid
```

Note: `grid` is currently `array[6, 6, char]` (2D shorthand) while `Grid` is `array[6, array[6, char]]` (nested). These are equivalent in Nim, so this is a safe change.

### Step 5: Update `io.nim`

- Replace `import types` with `import types, values`
- Remove the local `const boxRows`, `boxCols`, `gridSize` block
- Rename `Solution` to `Grid` in `printSolution` signature (and consider renaming the proc to `printGrid`)

### Step 6: Update `play.nim`

- Add `import values`
- Remove the local `const gridSize`, `boxRows`, `boxCols` lines (keep `gridX`, `gridY`, `hLine`, `wordColors`)
- Replace all `Solution` references with `Grid`
- Update `play*` proc signature: `proc play*(problem: Problem, solution: Grid)` changing it to accept a `Puzzle` instead

### Step 7: Update `tests/test_io.nim`

- Replace `Solution` with `Grid` in the test fixture variable type
- Update any references accordingly


---

## Files Changed

| File                    | Action                                              |
|-------------------------|-----------------------------------------------------|
| `src/parloku/values.nim`| **New** -- shared constants                         |
| `src/parloku/types.nim` | Rename `Solution` -> `Grid`, add `Puzzle` type      |
| `src/parloku/io.nim`    | Import `values`, remove local consts, `Grid` rename |
| `src/parloku/play.nim`  | Import `values`, remove shared consts, `Grid` rename, use `Grid` for `GameState.grid` |
| `tests/test_io.nim`     | `Solution` -> `Grid` rename                         |

## Risk Assessment

- **Low risk**: All changes are type renames and constant extraction -- no logic changes.
- `array[6, 6, char]` and `array[6, array[6, char]]` are interchangeable in Nim, so unifying `GameState.grid` to use `Grid` is safe.
- Tests should continue to pass after the rename.

## Verification

After all changes, run:
```
nimble test
nim c src/parloku/play.nim
```
to confirm everything compiles and tests pass.
