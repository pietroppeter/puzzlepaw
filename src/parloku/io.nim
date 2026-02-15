import std/strutils
import types

const
  boxRows = 2
  boxCols = 3
  gridSize = 6

proc printGrid(grid: array[gridSize, array[gridSize, char]]) =
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
  var grid: array[gridSize, array[gridSize, char]]
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

proc printSolution*(s: Solution) =
  ## Pretty-prints a Parloku solution to stdout.
  printGrid(s)
