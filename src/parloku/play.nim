import std/[os, strutils]
import illwill
import types
import values
import io
import tui

type
  GameState = object
    puzzle: Puzzle
    grid: Grid
    cursorRow: int
    cursorCol: int
    fixed: array[gridSize, array[gridSize, bool]]
    wordStart: array[gridSize, array[gridSize, int]] # -1 or hint index
    message: string
    solved: bool

proc initGame(puzzle: Puzzle): GameState =
  result.puzzle = puzzle

  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      result.grid[row][col] = '.'
      result.wordStart[row][col] = -1

  for hint in puzzle.problem.letterHints:
    result.grid[hint.pos.row][hint.pos.col] = hint.letter
    result.fixed[hint.pos.row][hint.pos.col] = true

  for i, hint in puzzle.problem.wordHints:
    result.wordStart[hint.pos.row][hint.pos.col] = i

proc isValidLetter(game: GameState, ch: char): bool =
  ch in game.puzzle.problem.letters

proc checkSolved(game: var GameState) =
  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      if game.grid[row][col] != game.puzzle.solution[row][col]:
        return
  game.solved = true
  game.message = "Puzzle solved! Press Q to go back."

proc drawPlayGrid(tb: var TerminalBuffer, game: GameState) =
  tb.write(gridX, gridY - 3, fgWhite, "Letters: " &
    game.puzzle.problem.letters.join(" "))

  drawGridLines(tb)

  for row in 0 ..< gridSize:
    drawGridSeparators(tb, row)
    let y = cellScreenY(row)

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
        tb.write(x, y, hintColor(wi), $(wi + 1))
      elif wi >= 0:
        tb.write(x, y, hintColor(wi), $ch)
      elif ch != '.':
        tb.write(x, y, fgGreen, $ch)
      else:
        tb.write(x, y, fgWhite, ".")

proc drawWordHints(tb: var TerminalBuffer, game: GameState) =
  let hintsY = gridY + (gridSize div boxRows) * (boxRows + 1) + 2
  tb.write(gridX, hintsY, fgWhite, "Word hints:")
  for i, hint in game.puzzle.problem.wordHints:
    tb.write(gridX + 2, hintsY + 1 + i, hintColor(i),
      $(i + 1) & ". " & hint.word)

proc drawHelp(tb: var TerminalBuffer, game: GameState) =
  let helpY = gridY + (gridSize div boxRows) * (boxRows + 1) +
    game.puzzle.problem.wordHints.len + 4
  tb.write(gridX, helpY, fgWhite,
    "Arrows: move | Letter: place | Backspace: clear | Q: back")
  if game.message.len > 0:
    let msgColor = if game.solved: fgGreen else: fgYellow
    tb.write(gridX, helpY + 2, msgColor, game.message)

proc play*(puzzle: Puzzle) =
  ## Play a puzzle. Returns when the user presses Q/Escape.
  var game = initGame(puzzle)

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

    var key = getKey()
    case key
    of Key.Escape, Key.Q, Key.ShiftQ:
      return
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

    drawPlayGrid(tb, game)
    drawWordHints(tb, game)
    drawHelp(tb, game)

    tb.display()
    sleep(20)

proc selectPuzzle*(dataDir: string): int =
  ## Show a list of available puzzles. Returns selected index (0-based), or -1 if cancelled.
  let files = listPuzzles(dataDir)
  if files.len == 0:
    return -1

  var selected = 0

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    tb.write(2, 1, fgWhite, "Select a puzzle (Up/Down, Enter to play, Q to go back):")

    for i, f in files:
      let color = if i == selected: fgGreen else: fgWhite
      let prefix = if i == selected: "> " else: "  "
      tb.write(2, 3 + i, color, prefix & f)

    tb.display()
    sleep(20)

    let key = getKey()
    case key
    of Key.Up:
      if selected > 0: selected.dec
    of Key.Down:
      if selected < files.len - 1: selected.inc
    of Key.Enter:
      return selected
    of Key.Escape, Key.Q, Key.ShiftQ:
      return -1
    else:
      discard
