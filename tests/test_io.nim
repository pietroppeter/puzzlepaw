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

let exampleSolution: Solution = [
  ['T', 'S', 'I', 'P', 'L', 'A'],
  ['A', 'L', 'P', 'T', 'I', 'S'],
  ['L', 'I', 'T', 'A', 'S', 'P'],
  ['P', 'A', 'S', 'L', 'T', 'I'],
  ['S', 'P', 'L', 'I', 'A', 'T'],
  ['I', 'T', 'A', 'S', 'P', 'L'],
]

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

echo "All tests passed."
