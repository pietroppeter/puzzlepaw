import std/[strutils, os, algorithm]
import jsony
import types
import values

proc printGrid(grid: Grid) =
  ## Prints a 6x6 grid with box separators.
  let hLine = "+" & "-------+".repeat(gridSize div boxCols)

  for row in 0 ..< gridSize:
    if row mod boxRows == 0:
      echo hLine

    var line = "|"
    for col in 0 ..< gridSize:
      line.add " " & grid[row][col]
      if (col + 1) mod boxCols == 0:
        line.add " |"

    echo line

  echo hLine

proc printProblem*(p: Problem) =
  ## Pretty-prints a Parloku problem to stdout.
  echo "Letters: ", p.letters.join(" ")
  echo ""

  # Build a sparse grid from letter hints
  var grid: Grid
  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      grid[row][col] = '.'

  for hint in p.letterHints:
    grid[hint.pos.row][hint.pos.col] = hint.letter

  # Place word hint numbers in the grid
  for i, hint in p.wordHints:
    grid[hint.pos.row][hint.pos.col] = chr(ord('1') + i)

  printGrid(grid)

  # Print word hints
  echo ""
  for i, hint in p.wordHints:
    echo "  ", i + 1, ". ", hint.word

proc printSolution*(s: Grid) =
  ## Pretty-prints a Parloku solution to stdout.
  printGrid(s)

proc savePuzzle*(puzzle: Puzzle, path: string) =
  ## Saves a Puzzle to a JSON file.
  writeFile(path, puzzle.toJson() & "\n")

proc loadPuzzle*(path: string): Puzzle =
  ## Loads a Puzzle from a JSON file.
  readFile(path).fromJson(Puzzle)

proc listPuzzles*(dir: string): seq[string] =
  ## Returns sorted list of puzzle JSON filenames in the given directory.
  var files: seq[string]
  for f in walkFiles(dir / "puzzle*.json"):
    files.add f.extractFilename
  files.sort()
  files

proc wordsFromFilename*(filename: string): seq[string] =
  ## Extracts word hints from a filename like "puzzle1-WORD1-WORD2-WORD3.json".
  let base = filename.extractFilename.changeFileExt("")
  let parts = base.split('-')
  if parts.len > 1:
    result = parts[1..^1]

proc nextPuzzleNumber*(dir: string): int =
  ## Returns the next available puzzle number based on existing files.
  result = 1
  for f in walkFiles(dir / "puzzle*.json"):
    let base = f.extractFilename.changeFileExt("")
    let afterPuzzle = base[6..^1]  # strip "puzzle"
    let dashIdx = afterPuzzle.find('-')
    let numStr = if dashIdx >= 0: afterPuzzle[0..<dashIdx] else: afterPuzzle
    try:
      let n = parseInt(numStr)
      if n >= result: result = n + 1
    except ValueError:
      discard

proc puzzleFilePath*(dir: string, n: int, words: seq[string]): string =
  ## Returns the path for puzzle N with word hints encoded in the filename.
  let suffix = if words.len > 0: "-" & words.join("-") else: ""
  dir / ("puzzle" & $n & suffix & ".json")

proc puzzleDisplayName*(filename: string): string =
  ## Returns a display string like "1. ITALIA PASTA ALPI" from a puzzle filename.
  let base = filename.extractFilename.changeFileExt("")
  let afterPuzzle = base[6..^1]  # strip "puzzle"
  let dashIdx = afterPuzzle.find('-')
  let numStr = if dashIdx >= 0: afterPuzzle[0..<dashIdx] else: afterPuzzle
  let words = wordsFromFilename(filename)
  let label = if words.len > 0: words.join(" ") else: filename
  numStr & ". " & label
