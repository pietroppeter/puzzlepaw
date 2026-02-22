import nimib, std/os
from nimib/themes import nil

# Embed puzzle data at compile time (outer scope, reliable staticRead)
const puzzle1Json = staticRead("../data/puzzle1-ITALIA-PASTA-ALPI.json")
const puzzle2Json = staticRead("../data/puzzle2-AMICA-GIOCO-MAGIA.json")

nbInit(theme = themes.useDefault)
nb.filename = getCurrentDir() / "docs" / "index.html"
nb.title = "PuzzlePaw"

# Bootstrap 5 + custom CSS for the game grid
nbRawHtml: """<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
<style>
.parloku-grid { border-collapse: collapse; margin: 0.5rem 0; }
.parloku-cell {
  width: 2.5rem; height: 2.5rem; padding: 0;
  border: 1px solid #888; text-align: center; vertical-align: middle;
  font-size: 1.1rem; font-weight: bold; cursor: pointer; user-select: none;
}
.box-top  { border-top:  3px solid #222 !important; }
.box-left { border-left: 3px solid #222 !important; }
.cell-fixed    { background-color: #ddeeff; color: #0044cc; cursor: default; }
.cell-user     { color: #228B22; }
.cell-selected { background-color: #fff3cd; outline: 2px solid #ffc107; outline-offset: -2px; }
.word-hint-label { font-weight: 600; }
</style>"""

nbText: """# PuzzlePaw

**Parloku** — a 6×6 letter sudoku with word-path hints.
Each row, column, and 2×3 box must contain all 6 letters exactly once.
Word hints show where a word *starts* in the grid (its path winds through adjacent cells).
"""

nbKaraxCode:
  import std/[json, strutils]
  import karax/[localstorage, vstyles]
  import parloku/types

  # Puzzle data embedded at compile time via staticRead in outer scope;
  # re-read here in the JS compilation (temp file is written to src/, same dir)
  const puzzleJsons = [
    staticRead("../data/puzzle1-ITALIA-PASTA-ALPI.json"),
    staticRead("../data/puzzle2-AMICA-GIOCO-MAGIA.json"),
  ]
  const puzzleNames = [
    "puzzle1-ITALIA-PASTA-ALPI",
    "puzzle2-AMICA-GIOCO-MAGIA",
  ]
  const wordColors = [
    "#c0392b", "#d35400", "#27ae60",
    "#2980b9", "#8e44ad", "#16a085",
  ]

  type
    AppState = object
      puzzles:     seq[Puzzle]
      currentIdx:  int
      grids:       seq[Grid]     # user-filled cells; '.' = empty
      solved:      seq[bool]
      selectedRow: int           # -1 = no cell selected
      selectedCol: int
      message:     string

  var app: AppState

  const storageKey = cstring"puzzlepaw_v1"

  # ── JSON parsing ────────────────────────────────────────────────────────────

  proc parsePuzzle(s: string): Puzzle =
    let j = parseJson(s)
    let prob = j["problem"]
    let lj = prob["letters"]
    for i in 0..<6:
      result.problem.letters[i] = lj[i].getStr[0]
    for h in prob["letterHints"]:
      let p = h["pos"]
      result.problem.letterHints.add HintLetter(
        pos: (p[0].getInt, p[1].getInt),
        letter: h["letter"].getStr[0])
    for h in prob["wordHints"]:
      let p = h["pos"]
      result.problem.wordHints.add HintWord(
        pos: (p[0].getInt, p[1].getInt),
        word: h["word"].getStr)
    let sj = j["solution"]
    for r in 0..<6:
      for c in 0..<6:
        result.solution[r][c] = sj[r][c].getStr[0]

  # ── Helpers ─────────────────────────────────────────────────────────────────

  proc isFixed(pi, r, c: int): bool =
    for h in app.puzzles[pi].problem.letterHints:
      if h.pos.row == r and h.pos.col == c: return true

  proc wordStartOf(pi, r, c: int): int =
    ## Returns the word-hint index if (r,c) is a word start, else -1.
    for i, h in app.puzzles[pi].problem.wordHints:
      if h.pos.row == r and h.pos.col == c: return i
    return -1

  proc puzzleLabel(name: string): string =
    ## "puzzle1-ITALIA-PASTA-ALPI" -> "1. ITALIA PASTA ALPI"
    let parts = name.split('-')
    if parts.len < 2: return name
    parts[0].replace("puzzle", "") & ". " & parts[1..^1].join(" ")

  # ── localStorage ────────────────────────────────────────────────────────────

  proc saveState() =
    var parts: seq[string]
    parts.add $app.currentIdx
    for i in 0..<app.puzzles.len:
      var gs = newString(36)
      for r in 0..<6:
        for c in 0..<6:
          gs[r * 6 + c] = app.grids[i][r][c]
      parts.add gs
      let solvedStr = if app.solved[i]: "1" else: "0"
      parts.add solvedStr
    localstorage.setItem(storageKey, parts.join("|").cstring)

  proc loadState() =
    if not localstorage.hasItem(storageKey): return
    let raw = localstorage.getItem(storageKey)
    if raw.isNil: return
    let parts = ($raw).split("|")
    if parts.len < 1: return
    try:
      app.currentIdx = min(parseInt(parts[0]), app.puzzles.len - 1)
      for i in 0..<app.puzzles.len:
        let gi = 1 + i * 2
        if gi >= parts.len: break
        let gs = parts[gi]
        for r in 0..<6:
          for c in 0..<6:
            let idx = r * 6 + c
            if idx < gs.len and not isFixed(i, r, c):
              app.grids[i][r][c] = gs[idx]
        let si = gi + 1
        if si < parts.len:
          app.solved[i] = parts[si] == "1"
    except: discard

  # ── Game logic ───────────────────────────────────────────────────────────────

  proc checkSolved() =
    let pi = app.currentIdx
    for r in 0..<6:
      for c in 0..<6:
        if app.grids[pi][r][c] != app.puzzles[pi].solution[r][c]: return
    app.solved[pi] = true
    app.message = "Puzzle solved!"
    saveState()

  proc placeOrClear(ch: char) =
    let pi = app.currentIdx
    let r = app.selectedRow
    let c = app.selectedCol
    if r < 0 or isFixed(pi, r, c): return
    if ch notin app.puzzles[pi].problem.letters:
      app.message = $ch & " is not one of the puzzle letters"
      return
    app.grids[pi][r][c] = ch
    app.message = ""
    app.solved[pi] = false
    checkSolved()
    saveState()

  proc clearSelected() =
    let pi = app.currentIdx
    let r = app.selectedRow
    let c = app.selectedCol
    if r < 0 or isFixed(pi, r, c): return
    app.grids[pi][r][c] = '.'
    app.solved[pi] = false
    app.message = ""
    saveState()

  # ── Initialization ───────────────────────────────────────────────────────────

  proc initApp() =
    for i, jsonStr in puzzleJsons:
      app.puzzles.add parsePuzzle(jsonStr)
      var g: Grid
      for r in 0..<6:
        for c in 0..<6: g[r][c] = '.'
      for h in app.puzzles[i].problem.letterHints:
        g[h.pos.row][h.pos.col] = h.letter
      app.grids.add g
      app.solved.add false
    app.selectedRow = -1
    app.selectedCol = -1
    loadState()

  # ── Keyboard handler ─────────────────────────────────────────────────────────

  proc onKeyDown(e: Event) =
    let ke = KeyboardEvent(e)
    let key = $ke.key
    if key.len == 1 and key[0] in {'A'..'Z', 'a'..'z'}:
      placeOrClear(key.toUpperAscii[0])
    elif key == "Backspace" or key == "Delete":
      clearSelected()
    elif key == "ArrowUp"    and app.selectedRow > 0: dec app.selectedRow
    elif key == "ArrowDown"  and app.selectedRow < 5: inc app.selectedRow
    elif key == "ArrowLeft"  and app.selectedCol > 0: dec app.selectedCol
    elif key == "ArrowRight" and app.selectedCol < 5: inc app.selectedCol
    else: return
    redraw()

  # ── Render ────────────────────────────────────────────────────────────────────

  proc renderTabs(): VNode =
    buildHtml(tdiv(class = "mb-3")):
      for i in 0..<app.puzzles.len:
        let lbl = puzzleLabel(puzzleNames[i])
        let cls =
          if i == app.currentIdx: cstring"btn btn-primary me-1"
          else: cstring"btn btn-outline-primary me-1"
        let idx = i
        button(class = cls,
               onclick = proc() =
                 app.currentIdx = idx
                 app.selectedRow = -1
                 app.selectedCol = -1
                 app.message = ""
                 redraw()):
          text lbl

  proc renderGrid(): VNode =
    let pi = app.currentIdx
    buildHtml(table(class = "parloku-grid mb-3")):
      for row in 0..<6:
        tr:
          for col in 0..<6:
            let ch    = app.grids[pi][row][col]
            let isFix = isFixed(pi, row, col)
            let wi    = wordStartOf(pi, row, col)
            let isSel = row == app.selectedRow and col == app.selectedCol
            var cls = "parloku-cell"
            if row == 2 or row == 4: cls &= " box-top"
            if col == 3:             cls &= " box-left"
            if isFix:       cls &= " cell-fixed"
            elif ch != '.': cls &= " cell-user"
            if isSel:       cls &= " cell-selected"
            let r = row; let c = col
            td(class = cls.cstring,
               onclick = proc() =
                 if not isFixed(pi, r, c):
                   app.selectedRow = r
                   app.selectedCol = c
                   redraw()):
              if wi >= 0 and ch == '.':
                span(style = style(StyleAttr.color,
                                   wordColors[wi mod wordColors.len].cstring)):
                  text $(wi + 1)
              elif ch != '.':
                text $ch

  proc renderPalette(): VNode =
    let pi = app.currentIdx
    buildHtml(tdiv(class = "d-flex flex-wrap gap-2 align-items-center mb-3")):
      span(class = "fw-bold me-1"): text "Letters:"
      for letter in app.puzzles[pi].problem.letters:
        let ch = letter
        button(class = cstring"btn btn-outline-secondary btn-sm fw-bold px-2",
               onclick = proc() =
                 placeOrClear(ch)
                 redraw()):
          text $ch
      button(class = cstring"btn btn-outline-danger btn-sm",
             onclick = proc() =
               clearSelected()
               redraw()):
        text "⌫ Clear"

  proc renderWordHints(): VNode =
    let pi = app.currentIdx
    buildHtml(tdiv(class = "mb-3")):
      p(class = "fw-bold mb-1 word-hint-label"): text "Word hints:"
      for i, hint in app.puzzles[pi].problem.wordHints:
        p(class = "mb-0",
          style = style(StyleAttr.color, wordColors[i mod wordColors.len].cstring)):
          text $(i + 1) & ". " & hint.word

  proc renderStatus(): VNode =
    buildHtml(tdiv(class = "mt-2")):
      if app.solved[app.currentIdx]:
        p(class = "text-success fw-bold fs-5 mb-0"): text "Puzzle solved! ✓"
      elif app.message.len > 0:
        p(class = "text-danger mb-0"): text app.message
      else:
        p(class = "text-muted small mb-0"):
          text "Click a cell, then type a letter or click a letter button. Arrow keys move the selection."

  # ── Boot ─────────────────────────────────────────────────────────────────────

  initApp()
  document.addEventListener("keydown", proc(e: Event) = onKeyDown(e))

  karaxHtml:
    tdiv(class = "container py-3"):
      renderTabs()
      renderGrid()
      renderPalette()
      renderWordHints()
      renderStatus()

nbSave
