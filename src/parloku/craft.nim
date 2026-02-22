import std/[os, strformat, strutils, sets, algorithm]
import illwill
import types
import values
import io
import tui

type
  CraftMode* = enum
    cmWordHints    # add/edit word hints (first mode)
    cmLetterHints  # place individual letter hints on the grid
    cmSolution     # fill in the solution grid
    cmLetters      # manually edit the 6 available letters

  CraftState = object
    puzzle: Puzzle
    cursorRow: int
    cursorCol: int
    mode: CraftMode
    letterIdx: int        # which of the 6 letters is being edited (cmLetters)
    wordInput: string     # current word being typed (cmWordHints word entry)
    enteringWord: bool    # true when typing a word hint
    editingWordIdx: int   # -1 = adding new, >= 0 = editing existing hint
    message: string
    dataDir: string
    editingFile: string   # non-empty if editing an existing puzzle

proc nextPuzzleFile(dataDir: string): string =
  var n = 1
  while fileExists(dataDir / fmt"puzzle{n}.json"):
    n.inc
  dataDir / fmt"puzzle{n}.json"

proc inferLetters(state: var CraftState) =
  ## Collect unique letters from all word hints, sorted alphabetically.
  var charSet: HashSet[char]
  for hint in state.puzzle.problem.wordHints:
    for ch in hint.word:
      if ch != ' ':
        charSet.incl ch.toUpperAscii
  var chars: seq[char]
  for ch in charSet:
    chars.add ch
  chars.sort()
  for i in 0 ..< 6:
    state.puzzle.problem.letters[i] = if i < chars.len: chars[i] else: '\0'

proc nextMode(mode: CraftMode): CraftMode =
  case mode
  of cmWordHints: cmLetterHints
  of cmLetterHints: cmSolution
  of cmSolution: cmLetters
  of cmLetters: cmWordHints

proc prevMode(mode: CraftMode): CraftMode =
  case mode
  of cmWordHints: cmLetters
  of cmLetterHints: cmWordHints
  of cmSolution: cmLetterHints
  of cmLetters: cmSolution

proc findLetterHintAt(state: CraftState, row, col: int): int =
  for i, hint in state.puzzle.problem.letterHints:
    if hint.pos.row == row and hint.pos.col == col:
      return i
  return -1

proc findWordHintAt(state: CraftState, row, col: int): int =
  for i, hint in state.puzzle.problem.wordHints:
    if hint.pos.row == row and hint.pos.col == col:
      return i
  return -1

proc isLetterHint(state: CraftState, row, col: int): bool =
  findLetterHintAt(state, row, col) >= 0

proc wordHintIdx(state: CraftState, row, col: int): int =
  findWordHintAt(state, row, col)

proc syncLetterHintsToSolution(state: var CraftState) =
  for hint in state.puzzle.problem.letterHints:
    state.puzzle.solution[hint.pos.row][hint.pos.col] = hint.letter

proc drawLettersBar(tb: var TerminalBuffer, state: CraftState) =
  tb.write(gridX, gridY - 3, fgWhite, "Letters: ")
  for i in 0 ..< 6:
    let ch = state.puzzle.problem.letters[i]
    let display = if ch == '\0': "_" else: $ch
    if state.mode == cmLetters and i == state.letterIdx:
      tb.setBackgroundColor(bgWhite)
      tb.write(gridX + 9 + i * 2, gridY - 3, fgBlack, display)
      tb.setBackgroundColor(bgNone)
    else:
      tb.write(gridX + 9 + i * 2, gridY - 3, fgYellow, display)

proc buildHintsGrid(state: CraftState): Grid =
  var g: Grid
  for row in 0 ..< gridSize:
    for col in 0 ..< gridSize:
      g[row][col] = '.'
  for hint in state.puzzle.problem.letterHints:
    g[hint.pos.row][hint.pos.col] = hint.letter
  for i, hint in state.puzzle.problem.wordHints:
    g[hint.pos.row][hint.pos.col] = chr(ord('1') + i)
  g

proc drawCraftGrid(tb: var TerminalBuffer, state: CraftState) =
  let hintsGrid = if state.mode != cmSolution: buildHintsGrid(state)
                  else: default(Grid)

  drawGridLines(tb)

  for row in 0 ..< gridSize:
    drawGridSeparators(tb, row)
    let y = cellScreenY(row)

    for col in 0 ..< gridSize:
      let x = cellScreenX(col)
      let isCursor = (state.mode in {cmSolution, cmLetterHints, cmWordHints}) and
                     row == state.cursorRow and col == state.cursorCol
      let isFixed = state.isLetterHint(row, col)
      let wi = state.wordHintIdx(row, col)

      if state.mode == cmSolution:
        let ch = state.puzzle.solution[row][col]
        if isCursor:
          tb.setBackgroundColor(bgWhite)
          if isFixed:
            tb.write(x, y, fgBlue, $ch)
          elif wi >= 0 and (ch == '\0' or ch == '.'):
            tb.write(x, y, fgBlack, $(wi + 1))
          elif ch == '\0' or ch == '.':
            tb.write(x, y, fgBlack, " ")
          else:
            tb.write(x, y, fgBlack, $ch)
          tb.setBackgroundColor(bgNone)
        elif isFixed:
          tb.write(x, y, fgCyan, $ch)
        elif wi >= 0 and (ch == '\0' or ch == '.'):
          tb.write(x, y, hintColor(wi), $(wi + 1))
        elif wi >= 0 and ch != '\0':
          tb.write(x, y, hintColor(wi), $ch)
        elif ch != '\0' and ch != '.':
          tb.write(x, y, fgGreen, $ch)
        else:
          tb.write(x, y, fgWhite, ".")
      else:
        let ch = hintsGrid[row][col]
        if isCursor:
          tb.setBackgroundColor(bgWhite)
          let display = if ch == '.' or ch == '\0': " " else: $ch
          tb.write(x, y, fgBlack, display)
          tb.setBackgroundColor(bgNone)
        elif ch >= '1' and ch <= '9':
          let idx = ord(ch) - ord('1')
          tb.write(x, y, hintColor(idx), $ch)
        elif ch != '.' and ch != '\0':
          tb.write(x, y, fgCyan, $ch)
        else:
          tb.write(x, y, fgWhite, ".")

proc drawWordHintsList(tb: var TerminalBuffer, state: CraftState) =
  let hintsY = gridY + (gridSize div boxRows) * (boxRows + 1) + 2
  tb.write(gridX, hintsY, fgWhite, "Word hints:")
  for i, hint in state.puzzle.problem.wordHints:
    tb.write(gridX + 2, hintsY + 1 + i, hintColor(i),
      fmt"{i + 1}. ({hint.pos.row},{hint.pos.col}) {hint.word}")

proc drawCraftHelp(tb: var TerminalBuffer, state: CraftState) =
  let baseY = gridY + (gridSize div boxRows) * (boxRows + 1) +
    state.puzzle.problem.wordHints.len + 4

  let modeStr = case state.mode
    of cmWordHints: "WORD HINTS"
    of cmLetterHints: "LETTER HINTS"
    of cmSolution: "SOLUTION"
    of cmLetters: "LETTERS"

  tb.write(gridX, gridY - 1, fgGreen, fmt"Mode: {modeStr}  (Tab / [ ] to switch)")

  case state.mode
  of cmWordHints:
    if state.enteringWord:
      tb.write(gridX, baseY, fgWhite,
        fmt"Type word: {state.wordInput}_ (Enter to confirm, Esc to cancel)")
    else:
      tb.write(gridX, baseY, fgWhite,
        "Arrows: move | W: add word | E: edit word | D: delete | I: infer letters | S: save | Q: done")
  of cmLetterHints:
    tb.write(gridX, baseY, fgWhite,
      "Arrows: move | Letter: place hint | Backspace: remove | S: save | Q: done")
  of cmSolution:
    tb.write(gridX, baseY, fgWhite,
      "Arrows: move | Letter: place | Backspace: clear | S: save | Q: done")
  of cmLetters:
    tb.write(gridX, baseY, fgWhite,
      "Left/Right: select | Letter: set | I: infer from words | S: save | Q: done")

  if state.message.len > 0:
    tb.write(gridX, baseY + 2, fgYellow, state.message)

proc saveCurrent(state: var CraftState) =
  let path = if state.editingFile.len > 0:
    state.editingFile
  else:
    nextPuzzleFile(state.dataDir)
  savePuzzle(state.puzzle, path)
  state.editingFile = path
  state.message = "Saved to " & path.extractFilename

proc handleWordHintsMode(state: var CraftState, key: Key) =
  case key
  of Key.Up:
    if state.cursorRow > 0: state.cursorRow.dec
  of Key.Down:
    if state.cursorRow < gridSize - 1: state.cursorRow.inc
  of Key.Left:
    if state.cursorCol > 0: state.cursorCol.dec
  of Key.Right:
    if state.cursorCol < gridSize - 1: state.cursorCol.inc
  of Key.W, Key.ShiftW:
    state.enteringWord = true
    state.editingWordIdx = -1
    state.wordInput = ""
    state.message = ""
  of Key.E, Key.ShiftE:
    let wi = findWordHintAt(state, state.cursorRow, state.cursorCol)
    if wi >= 0:
      state.enteringWord = true
      state.editingWordIdx = wi
      state.wordInput = state.puzzle.problem.wordHints[wi].word
      state.message = ""
    else:
      state.message = "No word hint at cursor to edit"
  of Key.D, Key.ShiftD:
    let wi = findWordHintAt(state, state.cursorRow, state.cursorCol)
    if wi >= 0:
      state.puzzle.problem.wordHints.delete(wi)
      state.message = "Removed word hint"
    else:
      let li = findLetterHintAt(state, state.cursorRow, state.cursorCol)
      if li >= 0:
        state.puzzle.problem.letterHints.delete(li)
        state.message = "Removed letter hint"
      else:
        state.message = "No hint at cursor"
  of Key.I, Key.ShiftI:
    inferLetters(state)
    state.message = "Letters inferred from word hints"
  else:
    discard

proc handleLetterHintsMode(state: var CraftState, key: Key) =
  case key
  of Key.Up:
    if state.cursorRow > 0: state.cursorRow.dec
  of Key.Down:
    if state.cursorRow < gridSize - 1: state.cursorRow.inc
  of Key.Left:
    if state.cursorCol > 0: state.cursorCol.dec
  of Key.Right:
    if state.cursorCol < gridSize - 1: state.cursorCol.inc
  of Key.Backspace, Key.Delete:
    let existing = findLetterHintAt(state, state.cursorRow, state.cursorCol)
    if existing >= 0:
      state.puzzle.problem.letterHints.delete(existing)
      state.message = "Removed letter hint"
  else:
    let ch = keyToChar(key)
    if ch != '\0':
      let existing = findLetterHintAt(state, state.cursorRow, state.cursorCol)
      if existing >= 0:
        state.puzzle.problem.letterHints.delete(existing)
      state.puzzle.problem.letterHints.add HintLetter(
        pos: (row: state.cursorRow, col: state.cursorCol),
        letter: ch,
      )
      state.puzzle.solution[state.cursorRow][state.cursorCol] = ch
      state.message = fmt"Placed letter hint: {ch}"

proc handleSolutionMode(state: var CraftState, key: Key) =
  let fixed = state.isLetterHint(state.cursorRow, state.cursorCol)
  case key
  of Key.Up:
    if state.cursorRow > 0: state.cursorRow.dec
  of Key.Down:
    if state.cursorRow < gridSize - 1: state.cursorRow.inc
  of Key.Left:
    if state.cursorCol > 0: state.cursorCol.dec
  of Key.Right:
    if state.cursorCol < gridSize - 1: state.cursorCol.inc
  of Key.Backspace, Key.Delete:
    if not fixed:
      state.puzzle.solution[state.cursorRow][state.cursorCol] = '\0'
      state.message = ""
  else:
    let ch = keyToChar(key)
    if ch != '\0' and not fixed:
      if ch in state.puzzle.problem.letters:
        state.puzzle.solution[state.cursorRow][state.cursorCol] = ch
        state.message = ""
      else:
        state.message = $ch & " is not one of the puzzle letters"

proc handleLettersMode(state: var CraftState, key: Key) =
  case key
  of Key.Left:
    if state.letterIdx > 0: state.letterIdx.dec
  of Key.Right:
    if state.letterIdx < 5: state.letterIdx.inc
  of Key.I, Key.ShiftI:
    inferLetters(state)
    state.message = "Letters inferred from word hints"
  else:
    let ch = keyToChar(key)
    if ch != '\0':
      state.puzzle.problem.letters[state.letterIdx] = ch
      state.message = ""
      if state.letterIdx < 5:
        state.letterIdx.inc

proc switchMode(state: var CraftState, newMode: CraftMode) =
  state.mode = newMode
  if newMode == cmSolution:
    syncLetterHintsToSolution(state)

proc craft*(dataDir: string, existingPuzzle: Puzzle = Puzzle(), existingFile: string = "") =
  var state = CraftState(
    puzzle: existingPuzzle,
    mode: cmWordHints,
    dataDir: dataDir,
    editingFile: existingFile,
  )

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    tb.write(gridX, 1, fgYellow, "puzzlepaw craft")

    drawLettersBar(tb, state)
    drawCraftGrid(tb, state)
    drawWordHintsList(tb, state)
    drawCraftHelp(tb, state)
    tb.display()
    sleep(20)

    let key = getKey()

    # Word input sub-mode
    if state.enteringWord:
      let ch = keyToChar(key)
      case key
      of Key.Enter:
        if state.wordInput.len > 0:
          if state.editingWordIdx >= 0:
            state.puzzle.problem.wordHints[state.editingWordIdx].word = state.wordInput
            state.message = fmt"Updated word hint: {state.wordInput}"
          else:
            state.puzzle.problem.wordHints.add HintWord(
              pos: (row: state.cursorRow, col: state.cursorCol),
              word: state.wordInput,
            )
            state.message = fmt"Added word hint: {state.wordInput}"
        state.wordInput = ""
        state.enteringWord = false
        state.editingWordIdx = -1
      of Key.Escape:
        state.wordInput = ""
        state.enteringWord = false
        state.editingWordIdx = -1
      of Key.Backspace:
        if state.wordInput.len > 0:
          state.wordInput.setLen(state.wordInput.len - 1)
      else:
        if ch != '\0':
          state.wordInput.add ch
      continue

    # Global keys
    case key
    of Key.Escape, Key.Q, Key.ShiftQ:
      return
    of Key.Tab, Key.RightBracket:
      switchMode(state, nextMode(state.mode))
      continue
    of Key.LeftBracket:
      switchMode(state, prevMode(state.mode))
      continue
    of Key.S, Key.ShiftS:
      saveCurrent(state)
      continue
    else:
      discard

    # Mode-specific keys
    case state.mode
    of cmWordHints: handleWordHintsMode(state, key)
    of cmLetterHints: handleLetterHintsMode(state, key)
    of cmSolution: handleSolutionMode(state, key)
    of cmLetters: handleLettersMode(state, key)

proc selectAndCraft*(dataDir: string) =
  var options = @["New puzzle"]
  let files = listPuzzles(dataDir)
  for f in files:
    options.add "Edit " & f

  var selected = 0

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    tb.write(2, 1, fgWhite, "Craft a puzzle (Up/Down, Enter to select, Q to go back):")

    for i, opt in options:
      let color = if i == selected: fgGreen else: fgWhite
      let prefix = if i == selected: "> " else: "  "
      tb.write(2, 3 + i, color, prefix & opt)

    tb.display()
    sleep(20)

    let key = getKey()
    case key
    of Key.Up:
      if selected > 0: selected.dec
    of Key.Down:
      if selected < options.len - 1: selected.inc
    of Key.Enter:
      if selected == 0:
        craft(dataDir)
      else:
        let file = files[selected - 1]
        let puzzle = loadPuzzle(dataDir / file)
        craft(dataDir, puzzle, dataDir / file)
      return
    of Key.Escape, Key.Q, Key.ShiftQ:
      return
    else:
      discard
