import std/[os, tempfiles]
import parloku/types
import parloku/io

let exampleProblem = Problem(
  letters: ['A', 'I', 'L', 'P', 'S', 'T'],
  letterHints: @[
    HintLetter(pos: (row: 0, col: 1), letter: 'S'),
    HintLetter(pos: (row: 3, col: 3), letter: 'L'),
    HintLetter(pos: (row: 5, col: 4), letter: 'P'),
  ],
  wordHints: @[
    HintWord(pos: (row: 5, col: 0), word: "ITALIA"),
    HintWord(pos: (row: 3, col: 0), word: "PASTA"),
    HintWord(pos: (row: 1, col: 0), word: "ALPI"),
  ],
)

let examplePuzzle = Puzzle(
  problem: exampleProblem,
  solution: [
  ['T', 'S', 'I', 'P', 'L', 'A'],
  ['A', 'L', 'P', 'T', 'I', 'S'],
  ['L', 'I', 'T', 'A', 'S', 'P'],
  ['P', 'A', 'S', 'L', 'T', 'I'],
  ['S', 'P', 'L', 'I', 'A', 'T'],
  ['I', 'T', 'A', 'S', 'P', 'L'],
  ],
)

let exampleSolution = examplePuzzle.solution

proc captureStdout(body: proc()): string =
  let oldStdout = stdout
  let (tmpFile, tmpPath) = createTempFile("test_", ".txt")
  stdout = tmpFile
  body()
  stdout = oldStdout
  tmpFile.close()
  result = readFile(tmpPath)
  removeFile(tmpPath)

block testPrintProblem:
  let output = captureStdout(proc() = printProblem(exampleProblem))
  let expected = """
Letters: A I L P S T

+-------+-------+
| . S . | . . . |
| 3 . . | . . . |
+-------+-------+
| . . . | . . . |
| 2 . . | L . . |
+-------+-------+
| . . . | . . . |
| 1 . . | . P . |
+-------+-------+

  1. ITALIA
  2. PASTA
  3. ALPI
"""
  doAssert output == expected, "Problem output mismatch:\n" & output

block testPrintSolution:
  let output = captureStdout(proc() = printSolution(exampleSolution))
  let expected = """
+-------+-------+
| T S I | P L A |
| A L P | T I S |
+-------+-------+
| L I T | A S P |
| P A S | L T I |
+-------+-------+
| S P L | I A T |
| I T A | S P L |
+-------+-------+
"""
  doAssert output == expected, "Solution output mismatch:\n" & output

block testSaveLoadRoundtrip:
  let (tmpFile, tmpPath) = createTempFile("puzzle_", ".json")
  tmpFile.close()
  savePuzzle(examplePuzzle, tmpPath)
  let loaded = loadPuzzle(tmpPath)
  doAssert loaded.problem.letters == examplePuzzle.problem.letters,
    "Letters mismatch after round-trip"
  doAssert loaded.problem.letterHints == examplePuzzle.problem.letterHints,
    "Letter hints mismatch after round-trip"
  doAssert loaded.problem.wordHints == examplePuzzle.problem.wordHints,
    "Word hints mismatch after round-trip"
  doAssert loaded.solution == examplePuzzle.solution,
    "Solution mismatch after round-trip"
  removeFile(tmpPath)

block testLoadPuzzleFromData:
  let dataDir = parentDir(currentSourcePath()) / ".." / "data"
  let puzzle = loadPuzzle(dataDir / "puzzle1-ITALIA-PASTA-ALPI.json")
  doAssert puzzle.problem.letters == ['A', 'I', 'L', 'P', 'S', 'T'],
    "puzzle1 letters mismatch"
  doAssert puzzle.solution[0] == ['T', 'S', 'I', 'P', 'L', 'A'],
    "puzzle1 first row mismatch"

block testListPuzzles:
  let dataDir = parentDir(currentSourcePath()) / ".." / "data"
  let puzzles = listPuzzles(dataDir)
  doAssert puzzles.len >= 1, "Expected at least 1 puzzle file"
  doAssert "puzzle1-ITALIA-PASTA-ALPI.json" in puzzles,
    "puzzle1-ITALIA-PASTA-ALPI.json not found in listing"

block testWordsFromFilename:
  doAssert wordsFromFilename("puzzle1-ITALIA-PASTA-ALPI.json") == @["ITALIA", "PASTA", "ALPI"],
    "wordsFromFilename failed for puzzle1"
  doAssert wordsFromFilename("puzzle2.json") == @[],
    "wordsFromFilename should return empty for name without words"

block testNextPuzzleNumber:
  let dataDir = parentDir(currentSourcePath()) / ".." / "data"
  let n = nextPuzzleNumber(dataDir)
  doAssert n >= 3, "nextPuzzleNumber should be at least 3 with 2 existing puzzles"

block testPuzzleFilePath:
  let path = puzzleFilePath("/data", 3, @["FOO", "BAR"])
  doAssert path == "/data/puzzle3-FOO-BAR.json", "puzzleFilePath mismatch: " & path
  let pathNoWords = puzzleFilePath("/data", 4, @[])
  doAssert pathNoWords == "/data/puzzle4.json", "puzzleFilePath no-words mismatch: " & pathNoWords

echo "All tests passed."
