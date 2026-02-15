import std/[os, strutils]
import illwill
import types

const
  gridSize = 6
  boxRows = 2
  boxCols = 3
  gridX = 2
  gridY = 3
  hLine = "+-------+-------+"

# Colors assigned to word hints (one per hint)
const wordColors = [fgRed, fgMagenta, fgBlue, fgYellow, fgGreen, fgCyan]

type
  GameState = object
    problem: Problem
    solution: Solution
    grid: array[gridSize, array[gridSize, char]]
    cursorRow: int
    cursorCol: int
    fixed: array[gridSize, array[gridSize, bool]]
    wordStart: array[gridSize, array[gridSize, int]] # -1 or hint index
    message: string
    solved: bool

proc initGame(problem: Problem, solution: Solution): GameState =
  result.problem = problem
  result.solution = solution

  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      result.grid[row][col] = '.'
      result.wordStart[row][col] = -1

  for hint in problem.letterHints:
    result.grid[hint.pos.row][hint.pos.col] = hint.letter
    result.fixed[hint.pos.row][hint.pos.col] = true

  for i, hint in problem.wordHints:
    result.wordStart[hint.pos.row][hint.pos.col] = i

proc cellScreenX(col: int): int =
  ## Map grid column to x. Layout: "| X X X | X X X |"
  ## Positions:                     0123456789...
  let box = col div boxCols
  let inBox = col mod boxCols
  result = gridX + 1 + box * 8 + inBox * 2 + 1

proc cellScreenY(row: int): int =
  ## Map grid row to y. Horizontal lines at box boundaries.
  let box = row div boxRows
  result = gridY + 1 + box * (boxRows + 1) + (row mod boxRows)

proc isValidLetter(game: GameState, ch: char): bool =
  ch in game.problem.letters

proc checkSolved(game: var GameState) =
  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      if game.grid[row][col] != game.solution[row][col]:
        return
  game.solved = true
  game.message = "Puzzle solved!"

proc hintColor(idx: int): ForegroundColor =
  wordColors[idx mod wordColors.len]

proc drawGrid(tb: var TerminalBuffer, game: GameState) =
  tb.write(gridX, gridY - 2, fgWhite, "Letters: " &
    game.problem.letters.join(" "))

  # Horizontal lines
  for boxRow in 0 .. (gridSize div boxRows):
    let y = gridY + boxRow * (boxRows + 1)
    tb.write(gridX, y, fgYellow, hLine)

  # Vertical separators and cell contents
  for row in 0 ..< gridSize:
    let y = cellScreenY(row)
    # Draw the full row template: "| . . . | . . . |"
    tb.write(gridX, y, fgYellow, "|")
    tb.write(gridX + 8, y, fgYellow, "|")
    tb.write(gridX + 16, y, fgYellow, "|")

    for col in 0 ..< gridSize:
      let x = cellScreenX(col)
      let ch = game.grid[row][col]
      let isCursor = row == game.cursorRow and col == game.cursorCol
      let wi = game.wordStart[row][col]

      if isCursor:
        tb.setBackgroundColor(bgWhite)
        if game.fixed[row][col]:
          tb.write(x, y, fgBlue, $ch)
        elif wi >= 0 and ch == '.':
          tb.write(x, y, fgBlack, $(wi + 1))
        elif ch == '.':
          tb.write(x, y, fgBlack, " ")
        else:
          tb.write(x, y, fgBlack, $ch)
        tb.setBackgroundColor(bgNone)
      elif game.fixed[row][col]:
        tb.write(x, y, fgCyan, $ch)
      elif wi >= 0 and ch == '.':
        # Show word hint number in its color
        tb.write(x, y, hintColor(wi), $(wi + 1))
      elif wi >= 0:
        # Cell has a letter and is a word start: show letter in hint color
        tb.write(x, y, hintColor(wi), $ch)
      elif ch != '.':
        tb.write(x, y, fgGreen, $ch)
      else:
        tb.write(x, y, fgWhite, ".")

proc drawWordHints(tb: var TerminalBuffer, game: GameState) =
  let hintsY = gridY + (gridSize div boxRows) * (boxRows + 1) + 2
  tb.write(gridX, hintsY, fgWhite, "Word hints:")
  for i, hint in game.problem.wordHints:
    tb.write(gridX + 2, hintsY + 1 + i, hintColor(i),
      $(i + 1) & ". " & hint.word)

proc drawHelp(tb: var TerminalBuffer, game: GameState) =
  let helpY = gridY + (gridSize div boxRows) * (boxRows + 1) +
    game.problem.wordHints.len + 4
  tb.write(gridX, helpY, fgWhite,
    "Arrows: move | Letter: place | Backspace: clear | Q: quit")
  if game.message.len > 0:
    let msgColor = if game.solved: fgGreen else: fgYellow
    tb.write(gridX, helpY + 2, msgColor, game.message)

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc keyToChar(key: Key): char =
  let ord = key.int
  if ord >= Key.A.int and ord <= Key.Z.int:
    return chr(ord - Key.A.int + 'A'.int)
  if ord >= Key.ShiftA.int and ord <= Key.ShiftZ.int:
    return chr(ord - Key.ShiftA.int + 'A'.int)
  return '\0'

proc play*(problem: Problem, solution: Solution) =
  var game = initGame(problem, solution)

  illwillInit(fullscreen = true)
  setControlCHook(exitProc)
  hideCursor()

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

    var key = getKey()
    case key
    of Key.Escape, Key.Q, Key.ShiftQ:
      exitProc()
    of Key.Up:
      if game.cursorRow > 0: game.cursorRow.dec
    of Key.Down:
      if game.cursorRow < gridSize - 1: game.cursorRow.inc
    of Key.Left:
      if game.cursorCol > 0: game.cursorCol.dec
    of Key.Right:
      if game.cursorCol < gridSize - 1: game.cursorCol.inc
    of Key.Backspace, Key.Delete:
      if not game.fixed[game.cursorRow][game.cursorCol]:
        game.grid[game.cursorRow][game.cursorCol] = '.'
        game.message = ""
        game.solved = false
    else:
      let ch = keyToChar(key)
      if ch != '\0' and not game.fixed[game.cursorRow][game.cursorCol]:
        if game.isValidLetter(ch):
          game.grid[game.cursorRow][game.cursorCol] = ch
          game.message = ""
          game.checkSolved()
        else:
          game.message = $ch & " is not one of the puzzle letters"

    drawGrid(tb, game)
    drawWordHints(tb, game)
    drawHelp(tb, game)

    tb.display()
    sleep(20)

when isMainModule:
  let problem = Problem(
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

  let solution: Solution = [
    ['T', 'S', 'I', 'P', 'L', 'A'],
    ['A', 'L', 'P', 'T', 'I', 'S'],
    ['L', 'I', 'T', 'A', 'S', 'P'],
    ['P', 'A', 'S', 'L', 'T', 'I'],
    ['S', 'P', 'L', 'I', 'A', 'T'],
    ['I', 'T', 'A', 'S', 'P', 'L'],
  ]

  play(problem, solution)
