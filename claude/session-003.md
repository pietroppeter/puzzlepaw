# Session 003 — Solver tools for the Parloku builder

**Date:** 2026-11-04

## Goal

Prepare for a future Parloku builder page (pick words, givens and letters,
see how many solutions remain, generate a link to play) by adding solver
APIs to puzzlepaw.

## What was built

- `src/parloku/solver.nim`
  - Board of 36 bitmasks with sudoku propagation (naked and hidden singles).
  - Word hints become sets of geometric paths from the start cell, prefiltered
    for consistency (a revisited cell keeps its letter; two cells of one unit
    cannot share a letter). During search, dead paths are dropped and cells
    on every surviving path of a word are narrowed to the letters those paths
    need. Search branches on cells, so each grid is counted once even when a
    word can be read along several paths.
  - `solve`, `countSolutions`, `isUnique`, `candidates` (exact per-cell
    letters over all solutions, each witnessed by a solution), `forcedCells`,
    `wordStarts`, `checkGrid`, `wordPaths`, `validate`.
  - Options `allowRevisit` and `allowShared` (both true by the rules; false
    gives the stricter "elegant" reading).
- `src/parloku/code.nim`: URL-safe problem code `LETTERS_GIVENS_WORDS`.
- `src/pzlsolve.nim`: CLI over both.
- Solver and code avoid os/jsony and compile with `nim js`
  (`tests/test_solver_js.nim`).

## Findings on the two existing puzzles

- Both answer keys are the unique solution.
- Without givens, puzzle1 (ITALIA/PASTA/ALPI) has 42 solutions with 6 cells
  forced; puzzle2 (AMICA/GIOCO/MAGIA) has 34.
- Forbidding shared cells, puzzle1 without givens drops to 8 solutions.
- Counts were cross-checked by brute force over all 28,200,960 6x6 grids.
