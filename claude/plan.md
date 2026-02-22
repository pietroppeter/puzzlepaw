# Plan: Web UI for GitHub Pages (Nimib + Karax)

Status: **PENDING**

## Goal

Add a client-only web UI using Nimib + Karax that:
- Generates `docs/index.html` (a static, self-contained HTML+JS page)
- Embeds all puzzle data at compile time (no server needed)
- Renders an interactive play UI for all existing puzzles
- Persists game state to `localStorage`
- Gets deployed to GitHub Pages

---

## Architecture Overview

```
nim r src/webui.nim
    │
    ├─ [compile-time] staticRead puzzle JSONs into Nim constants
    ├─ nbInit → configure output path = docs/index.html
    ├─ nbRawHtml → inject puzzle data as JS globals (see §Data Embedding)
    ├─ nbKaraxCode → compile Karax game UI to JS, embed in HTML
    └─ nbSave → write docs/index.html
```

The generated `docs/index.html` is a standalone file with all JS inlined.
GitHub Pages serves it directly from the `docs/` folder on the main branch.

---

## Dependencies to Add

Two new packages via atlas:

```
atlas use nimib    # HTML builder + Karax integration
atlas use karax    # Nim-to-JS frontend framework
```

Atlas clones them into `deps/nimib/` and `deps/karax/`, updates `nim.cfg`.

nimib path layout (standard):  `deps/nimib/src`
karax path layout (standard):  `deps/karax`

---

## Files to Create / Modify

### New files
| File | Purpose |
|---|---|
| `src/webui.nim` | Web UI entry point; run to generate `docs/index.html` |
| `docs/index.html` | Generated output; committed for GitHub Pages |
| `.github/workflows/pages.yml` | CI: auto-build and deploy on push to main |

### Modified files
| File | Change |
|---|---|
| `puzzlepaw.nimble` | Add `nimib`, `karax` requires; add `webui` task |
| `nim.cfg` | Add atlas-managed paths for nimib and karax |
| `.gitignore` | Add `src/webui` binary; un-ignore `docs/index.html` |

---

## Data Embedding Strategy

Because `staticRead` paths inside `nbKaraxCode` resolve relative to a nimib
temp file (not the project root), we embed puzzle data in two safe steps:

### Step 1 — read at compile time in outer scope (regular Nim)

```nim
const puzzle1Json = staticRead("../data/puzzle1-ITALIA-PASTA-ALPI.json")
const puzzle2Json = staticRead("../data/puzzle2-AMICA-GIOCO-MAGIA.json")
```

### Step 2 — inject as a JS global via nbRawHtml

```nim
import std/json
# Encode each JSON file content as a JSON string element,
# so special characters are properly escaped.
let jsGlobal = "const PUZZLE_STRINGS=" &
  $(%*[puzzle1Json, puzzle2Json]) & ";" &
  "const PUZZLE_NAMES=" &
  $(%*["1. ITALIA PASTA ALPI", "2. AMICA GIOCO MAGIA"]) & ";"
nbRawHtml: "<script>" & jsGlobal & "</script>"
```

Result in HTML:
```html
<script>
const PUZZLE_STRINGS=["{\\"problem\\":...}","{\\"problem\\":...}"];
const PUZZLE_NAMES=["1. ITALIA PASTA ALPI","2. AMICA GIOCO MAGIA"];
</script>
```

### Step 3 — access from Karax via importc

```nim
nbKaraxCode:
  var PUZZLE_STRINGS {.importc, nodecl.}: JsObject
  var PUZZLE_NAMES   {.importc, nodecl.}: JsObject
  # PUZZLE_STRINGS[0], PUZZLE_STRINGS[1] are JS strings → parse with std/json
```

---

## `src/webui.nim` Structure

```nim
import nimib, nimib/[nbkarax]
import std/[json, strutils]

# ── Compile-time data embedding ──────────────────────────────────────────────
const puzzle1Json = staticRead("../data/puzzle1-ITALIA-PASTA-ALPI.json")
const puzzle2Json = staticRead("../data/puzzle2-AMICA-GIOCO-MAGIA.json")
# (add more puzzles here as data/ grows)

# ── nimib document setup ──────────────────────────────────────────────────────
nbInit(theme = useBootstrap)
nb.filename = "docs/index.html"

nbText: md"""
# PuzzlePaw 🐾
**Parloku** — a 6×6 letter sudoku with word-path hints.
"""

# ── Inject puzzle data as JS globals ─────────────────────────────────────────
let jsGlobal = ...   # (see §Data Embedding)
nbRawHtml: "<script>" & jsGlobal & "</script>"

# ── Custom CSS for grid ───────────────────────────────────────────────────────
nbRawHtml: "<style>" & gridCss & "</style>"

# ── Karax game UI ─────────────────────────────────────────────────────────────
nbKaraxCode:
  # (see §Karax App below)

nbSave
```

---

## Karax App

### Imports (inside nbKaraxCode)

```nim
import std/[json, strutils, sequtils]
import karax/[kdom, karaxdsl, vdom, vstyles, kbase]
```

### Type Definitions

`parloku/types.nim` has no imports (pure type declarations), so it can be
imported directly in the Karax block — no need to redeclare `Coord`,
`HintLetter`, `HintWord`, `Problem`, `Grid`, or `Puzzle`.

Only `AppState` is new and must be declared in `webui.nim`:

```nim
import parloku/types   # Coord, HintLetter, HintWord, Problem, Grid, Puzzle

type
  AppState = object
    puzzles:       seq[Puzzle]
    currentIdx:    int
    grids:         seq[Grid]         # per-puzzle user state
    solved:        seq[bool]         # per-puzzle solved flag
    selectedRow:   int               # -1 = no selection
    selectedCol:   int
    message:       string
```

### JSON Parsing

```nim
proc parseCoord(j: JsonNode): Coord =
  (j[0].getInt, j[1].getInt)

proc parsePuzzle(s: string): Puzzle =
  let j = parseJson(s)
  let prob = j["problem"]
  for i, lj in prob["letters"]: result.problem.letters[i] = lj.getStr[0]
  for h in prob["letterHints"]:
    result.problem.letterHints.add HintLetter(
      pos: parseCoord(h["pos"]), letter: h["letter"].getStr[0])
  for h in prob["wordHints"]:
    result.problem.wordHints.add HintWord(
      pos: parseCoord(h["pos"]), word: h["word"].getStr)
  for r in 0..<6:
    for c in 0..<6:
      result.solution[r][c] = j["solution"][r][c].getStr[0]
```

### localStorage

```nim
const STORAGE_KEY = "puzzlepaw_v1"

proc saveState(state: AppState) =
  var root = newJObject()
  root["currentIdx"] = newJInt(state.currentIdx)
  var gridsArr = newJArray()
  for g in state.grids:
    var rowsArr = newJArray()
    for row in g:
      var colsArr = newJArray()
      for ch in row: colsArr.add newJString($ch)
      rowsArr.add colsArr
    gridsArr.add rowsArr
  root["grids"] = gridsArr
  var solvedArr = newJArray()
  for s in state.solved: solvedArr.add newJBool(s)
  root["solved"] = solvedArr
  window.localStorage.setItem(STORAGE_KEY, cstring($root))

proc loadSavedGrids(state: var AppState) =
  let raw = window.localStorage.getItem(STORAGE_KEY)
  if raw.isNil or raw == "": return
  try:
    let j = parseJson($raw)
    state.currentIdx = j["currentIdx"].getInt
    for pi, gjn in j["grids"]:
      if pi >= state.grids.len: break
      for r in 0..<6:
        for c in 0..<6:
          let ch = gjn[r][c].getStr[0]
          state.grids[pi][r][c] = ch
    for pi, sj in j["solved"]:
      if pi >= state.solved.len: break
      state.solved[pi] = sj.getBool
  except: discard  # ignore corrupt saved state
```

### State Initialization

```nim
var PUZZLE_STRINGS {.importc, nodecl.}: JsObject
var PUZZLE_NAMES   {.importc, nodecl.}: JsObject

var app: AppState

proc initApp() =
  let count = PUZZLE_STRINGS.length.to(int)
  for i in 0..<count:
    let s = ($PUZZLE_STRINGS[i].to(cstring))
    app.puzzles.add parsePuzzle(s)
    var emptyGrid: Grid
    for r in 0..<6:
      for c in 0..<6: emptyGrid[r][c] = '.'
    # Pre-place letter hints
    for h in app.puzzles[i].problem.letterHints:
      emptyGrid[h.pos.row][h.pos.col] = h.letter
    app.grids.add emptyGrid
    app.solved.add false
  app.selectedRow = -1
  app.selectedCol = -1
  loadSavedGrids(app)
```

### Solved Check

```nim
proc checkSolved(state: var AppState) =
  let p = state.puzzles[state.currentIdx]
  let g = state.grids[state.currentIdx]
  for r in 0..<6:
    for c in 0..<6:
      if g[r][c] != p.solution[r][c]: return
  state.solved[state.currentIdx] = true
  state.message = "Puzzle solved!"
  saveState(state)
```

### Grid CSS

6×6 grid with 2×3 box separators (thicker borders at col 3 and rows 2, 4):

```css
.pzl-grid { border-collapse: collapse; margin: 1rem auto; }
.pzl-grid td {
  width: 2.5rem; height: 2.5rem;
  text-align: center; vertical-align: middle;
  border: 1px solid #888;
  font-size: 1.2rem; font-weight: bold; cursor: pointer;
  user-select: none;
}
/* Box separators */
.pzl-grid td.box-top    { border-top: 3px solid #333; }
.pzl-grid td.box-left   { border-left: 3px solid #333; }
/* Cell states */
.pzl-grid td.fixed      { background: #ddeeff; color: #0044aa; }
.pzl-grid td.user       { color: #226622; }
.pzl-grid td.selected   { background: #fff3cd; outline: 2px solid #ffaa00; }
.pzl-grid td.wstart-0   { color: #e74c3c; }
.pzl-grid td.wstart-1   { color: #e67e22; }
.pzl-grid td.wstart-2   { color: #27ae60; }
.pzl-grid td.wstart-3   { color: #2980b9; }
.pzl-grid td.wstart-4   { color: #8e44ad; }
.pzl-grid td.wstart-5   { color: #16a085; }
.pzl-palette button     { margin: 0.2rem; min-width: 2.5rem; font-size: 1.1rem; }
.pzl-solved             { color: green; font-weight: bold; font-size: 1.2rem; }
```

### Karax Render Tree

```
renderApp()
  ├── renderPuzzleSelector()   tabs: one button per puzzle
  ├── renderGrid()             6×6 table
  ├── renderPalette()          6 letter buttons + Backspace
  ├── renderWordHints()        numbered word list with colors
  └── renderStatus()           message / solved banner
```

#### renderPuzzleSelector

```nim
proc renderPuzzleSelector(): VNode =
  buildHtml(tdiv(class = "btn-group mb-3")):
    for i in 0..<app.puzzles.len:
      let label = ($PUZZLE_NAMES[i].to(cstring))
      let active = if i == app.currentIdx: "btn btn-primary" else: "btn btn-outline-primary"
      let idx = i
      button(class = active,
             onclick = proc() =
               app.currentIdx = idx
               app.selectedRow = -1; app.selectedCol = -1
               app.message = ""):
        text label
```

#### renderGrid

```nim
proc renderGrid(): VNode =
  let p = app.puzzles[app.currentIdx]
  let g = app.grids[app.currentIdx]
  # Build fixed/wordStart lookup tables
  var fixed:     array[6, array[6, bool]]
  var wordStart: array[6, array[6, int]]
  for r in 0..<6:
    for c in 0..<6: wordStart[r][c] = -1
  for h in p.problem.letterHints:
    fixed[h.pos.row][h.pos.col] = true
  for i, h in p.problem.wordHints:
    wordStart[h.pos.row][h.pos.col] = i

  buildHtml(table(class = "pzl-grid")):
    for row in 0..<6:
      tr:
        for col in 0..<6:
          let ch    = g[row][col]
          let isFix = fixed[row][col]
          let wi    = wordStart[row][col]
          let isSel = row == app.selectedRow and col == app.selectedCol
          # Build CSS class
          var cls = ""
          if row == 2 or row == 4: cls &= " box-top"
          if col == 3:             cls &= " box-left"
          if isFix:   cls &= " fixed"
          elif isSel: cls &= " selected"
          elif ch != '.': cls &= " user"
          if wi >= 0 and not isFix: cls &= " wstart-" & $wi
          let r = row; let c = col
          td(class = cls.strip,
             onclick = proc() =
               app.selectedRow = r; app.selectedCol = c):
            if ch == '.' and wi >= 0 and not isFix:
              text $(wi + 1)
            elif ch == '.':
              text ""
            else:
              text $ch
```

#### renderPalette

```nim
proc renderPalette(): VNode =
  let p = app.puzzles[app.currentIdx]
  buildHtml(tdiv(class = "pzl-palette d-flex flex-wrap justify-content-center mb-2")):
    for letter in p.problem.letters:
      let ltr = letter
      button(class = "btn btn-outline-secondary btn-sm",
             onclick = proc() = placeOrClear(ltr)):
        text $ltr
    button(class = "btn btn-outline-danger btn-sm",
           onclick = proc() = clearSelected()):
      text "⌫"
```

#### renderWordHints

```nim
proc renderWordHints(): VNode =
  let p = app.puzzles[app.currentIdx]
  let colors = ["#e74c3c","#e67e22","#27ae60","#2980b9","#8e44ad","#16a085"]
  buildHtml(ul(class = "list-unstyled")):
    for i, hint in p.problem.wordHints:
      li(style = style(StyleAttr.color, colors[i mod colors.len])):
        text $(i+1) & ". " & hint.word
```

#### renderStatus

```nim
proc renderStatus(): VNode =
  buildHtml(tdiv):
    if app.solved[app.currentIdx]:
      p(class = "pzl-solved"): text "✓ Puzzle solved!"
    elif app.message.len > 0:
      p(class = "text-warning"): text app.message
    else:
      p(class = "text-muted small"):
        text "Click a cell, then click a letter (or type it). Click again to deselect."
```

### Keyboard Input

Attach a keydown listener on the document at init time:

```nim
proc onKeyDown(e: Event) =
  let ke = KeyboardEvent(e)
  if app.selectedRow < 0: return
  let key = $ke.key
  if key.len == 1 and key[0] in {'A'..'Z', 'a'..'z'}:
    placeOrClear(key.toUpperAscii[0])
  elif key == "Backspace" or key == "Delete":
    clearSelected()
  elif key == "ArrowUp"    and app.selectedRow > 0: app.selectedRow.dec
  elif key == "ArrowDown"  and app.selectedRow < 5: app.selectedRow.inc
  elif key == "ArrowLeft"  and app.selectedCol > 0: app.selectedCol.dec
  elif key == "ArrowRight" and app.selectedCol < 5: app.selectedCol.inc

document.addEventListener("keydown", onKeyDown)
```

### Place / Clear Helpers

```nim
proc isFixed(r, c: int): bool =
  for h in app.puzzles[app.currentIdx].problem.letterHints:
    if h.pos == (r, c): return true

proc placeOrClear(letter: char) =
  let r = app.selectedRow; let c = app.selectedCol
  if r < 0 or isFixed(r, c): return
  if letter notin app.puzzles[app.currentIdx].problem.letters:
    app.message = $letter & " is not a puzzle letter"; return
  app.grids[app.currentIdx][r][c] = letter
  app.message = ""
  app.checkSolved()
  saveState(app)

proc clearSelected() =
  let r = app.selectedRow; let c = app.selectedCol
  if r < 0 or isFixed(r, c): return
  app.grids[app.currentIdx][r][c] = '.'
  app.message = ""
  app.solved[app.currentIdx] = false
  saveState(app)
```

### Main Render + setRenderer

```nim
proc render(): VNode =
  buildHtml(tdiv(class = "container py-4")):
    h1(class = "mb-3"): text "PuzzlePaw"
    renderPuzzleSelector()
    renderGrid()
    renderPalette()
    renderWordHints()
    renderStatus()

initApp()
document.addEventListener("keydown", onKeyDown)
setRenderer render
```

---

## GitHub Pages Deployment

### Option A — Pre-built (simpler)

1. Run `nim r src/webui.nim` locally to regenerate `docs/index.html`
2. Commit `docs/index.html`
3. In GitHub repo Settings → Pages → Source: `main` branch, `/docs` folder

Add a nimble task:
```nim
task webui, "Build the web UI":
  exec "nim r src/webui.nim"
```

### Option B — GitHub Actions (automatic)

`.github/workflows/pages.yml`:
```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Nim
        uses: jiro4989/setup-nim-action@v2
        with:
          nim-version: 'stable'

      - name: Install atlas
        run: nimble install atlas -y

      - name: Install deps
        run: |
          atlas use nimib
          atlas use karax
          atlas use jsony
          atlas use illwill

      - name: Build web UI
        run: nim r src/webui.nim

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs
```

**Recommended**: Start with Option A (pre-built), add Option B later.

---

## Implementation Steps

1. **Install deps** — `atlas use nimib` + `atlas use karax` in project root
2. **Update nim.cfg** — atlas auto-updates; verify nimib/karax paths added
3. **Update puzzlepaw.nimble** — add `requires "nimib"` + `requires "karax"` + `task webui`
4. **Update .gitignore** — add `src/webui` binary; ensure `docs/` is NOT ignored
5. **Create docs/ directory** — add a placeholder or generate immediately
6. **Create src/webui.nim** — full implementation per spec above
7. **Build** — `nim r src/webui.nim` → verify `docs/index.html` generated
8. **Test in browser** — open `docs/index.html` locally; test gameplay + localStorage
9. **Commit** — add all new/modified files; commit with descriptive message
10. **Push** — push to `claude/add-web-ui-BIwCC`
11. **Optionally** add GitHub Actions workflow

---

## Key Constraints & Notes

- **No server**: all game logic runs in JS in the browser; puzzle data is embedded
- **No jsony in JS**: `std/json` is used for parsing inside Karax (jsony is C-only)
- **No illwill in JS**: `parloku/play.nim` cannot be imported; types redeclared inline
- **staticRead in nbKaraxCode is risky**: path resolution may fail from nimib's temp dir → use the `nbRawHtml` injection approach instead
- **JS FFI for localStorage**: `window.localStorage` is accessible via `karax/kdom`
- **Box grid**: 2×3 boxes (not 3×3); thick border after row 1/3 and after col 2
- **Word paths**: not rendered as paths (too complex for v1); word start cell shows hint number + color, list shown below grid
- **Adding puzzles later**: requires re-running `nim r src/webui.nim` and committing updated `docs/index.html`
