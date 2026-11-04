## Constraint solver for Parloku (Wordoku) puzzles.
##
## Rules (see README):
## - 6x6 grid, six distinct letters, each exactly once per row, column and
##   2x3 box.
## - Letter hints are givens.
## - Each word hint is spelled starting at its cell, moving orthogonally to
##   an adjacent cell at each step. Paths may cross boxes; by the rules they
##   may also revisit cells and words may share cells (`SolveOptions` can
##   forbid this for "elegant" puzzles).
##
## The module depends only on `types` and `values` (no os/jsony), so it also
## compiles with the JS backend, for use in a browser builder page.
##
## Main entry points:
## - `countSolutions` / `solve` / `isUnique`: how many grids satisfy a problem.
## - `candidates`: for each cell, which letters appear in at least one
##   solution (the "true pencil marks"). Cells with one candidate are forced.
## - `wordStarts`: where a new word could start and how many solutions
##   each choice leaves.
## - `checkGrid` / `wordPaths`: verify a filled grid and find word paths in it.
## - `validate`: list problems with the problem definition itself.

import std/[strutils, algorithm]
import types
import values

const
  nCells* = gridSize * gridSize
  fullMask = (1 shl gridSize) - 1

type
  Mask = int                       ## bit i set = letter index i possible
  Board = array[nCells, Mask]

  SolveOptions* = object
    allowRevisit*: bool   ## a word path may step back onto a cell it used
    allowShared*: bool    ## two words may use the same cell
    limit*: int           ## stop after this many solutions (0 = no limit)
    keep*: int            ## how many solution grids to return

  SolveResult* = object
    count*: int           ## solutions found (== limit means "at least")
    complete*: bool       ## true if the search space was exhausted
    solutions*: seq[Grid] ## up to `keep` solutions
    nodes*: int           ## search nodes visited (for curiosity/benchmarks)

  CellCandidates* = array[gridSize, array[gridSize, seq[char]]]

  WordStart* = object
    pos*: Coord
    count*: int           ## solutions with the word placed here (capped)

  Step = tuple[cell, letter: int]
  WordPaths = seq[seq[Step]]       ## all geometric paths of one word

  Ctx = object
    letters: array[gridSize, char]
    opts: SolveOptions
    paths: seq[WordPaths]          ## per word hint
    res: SolveResult

proc defaultOptions*(limit = 1000, keep = 10): SolveOptions =
  SolveOptions(allowRevisit: true, allowShared: true, limit: limit, keep: keep)

# ---------------------------------------------------------------------------
# Geometry

proc cellOf*(c: Coord): int {.inline.} = c.row * gridSize + c.col
proc coordOf*(cell: int): Coord {.inline.} = (row: cell div gridSize, col: cell mod gridSize)

proc buildUnits(): seq[seq[int]] =
  for r in 0 ..< gridSize:
    var u: seq[int]
    for c in 0 ..< gridSize: u.add r * gridSize + c
    result.add u
  for c in 0 ..< gridSize:
    var u: seq[int]
    for r in 0 ..< gridSize: u.add r * gridSize + c
    result.add u
  for br in countup(0, gridSize - 1, boxRows):
    for bc in countup(0, gridSize - 1, boxCols):
      var u: seq[int]
      for r in br ..< br + boxRows:
        for c in bc ..< bc + boxCols: u.add r * gridSize + c
      result.add u

let units = buildUnits()

proc buildPeers(): array[nCells, seq[int]] =
  for u in units:
    for a in u:
      for b in u:
        if a != b and b notin result[a]: result[a].add b

let peers = buildPeers()

proc neighbors(cell: int): seq[int] =
  let (r, c) = coordOf(cell)
  if r > 0: result.add cell - gridSize
  if r < gridSize - 1: result.add cell + gridSize
  if c > 0: result.add cell - 1
  if c < gridSize - 1: result.add cell + 1

proc popcount(m: Mask): int {.inline.} =
  var x = m
  while x != 0:
    x = x and (x - 1)
    inc result

proc lowBit(m: Mask): int {.inline.} =
  for i in 0 ..< gridSize:
    if (m and (1 shl i)) != 0: return i
  -1

# ---------------------------------------------------------------------------
# Validation

proc letterIndex(letters: array[gridSize, char], ch: char): int =
  for i, l in letters:
    if l == ch.toUpperAscii: return i
  -1

proc validate*(p: Problem): seq[string] =
  ## Returns human readable issues with the problem definition (empty = ok).
  ## A problem that validates can still have zero solutions.
  for i, l in p.letters:
    if l notin {'A'..'Z'}:
      result.add "letter " & $(i + 1) & " is not set (A-Z)"
    for j in 0 ..< i:
      if p.letters[j] == l: result.add "letter " & $l & " repeated"
  proc inGrid(c: Coord): bool = c.row in 0 ..< gridSize and c.col in 0 ..< gridSize
  for h in p.letterHints:
    if not inGrid(h.pos): result.add "letter hint outside grid at " & $h.pos
    elif letterIndex(p.letters, h.letter) < 0:
      result.add "letter hint " & $h.letter & " is not one of the letters"
  for h in p.wordHints:
    if not inGrid(h.pos): result.add "word " & h.word & " starts outside grid"
    if h.word.len == 0: result.add "empty word hint"
    for ch in h.word:
      if letterIndex(p.letters, ch) < 0:
        result.add "word " & h.word & " uses " & $ch & " which is not one of the letters"
        break
    for i in 1 ..< h.word.len:
      if h.word[i].toUpperAscii == h.word[i - 1].toUpperAscii:
        result.add "word " & h.word & " has a double letter, impossible on adjacent cells"
        break

# ---------------------------------------------------------------------------
# Word paths

proc sameUnit(a, b: int): bool =
  b in peers[a]

proc enumeratePaths(start: int, idx: seq[int], allowRevisit: bool): WordPaths =
  ## All orthogonal paths spelling the word (given as letter indices) from
  ## `start`, filtered for internal consistency: a revisited cell must carry
  ## the same letter, and two distinct cells in the same unit cannot carry
  ## the same letter.
  var path: seq[Step]
  var found: WordPaths
  proc consistent(path: seq[Step], s: Step): bool =
    for p in path:
      if p.cell == s.cell:
        if p.letter != s.letter or not allowRevisit: return false
      elif p.letter == s.letter and sameUnit(p.cell, s.cell): return false
    true
  proc rec(cell, i: int) =
    let s: Step = (cell, idx[i])
    if not consistent(path, s): return
    path.add s
    if i == idx.len - 1:
      found.add path
    else:
      for n in neighbors(cell): rec(n, i + 1)
    path.setLen(path.len - 1)
  if idx.len > 0: rec(start, 0)
  found

proc pathCells(path: seq[Step]): seq[int] =
  for s in path:
    if s.cell notin result: result.add s.cell

# ---------------------------------------------------------------------------
# Propagation and search

proc assign(b: var Board, cell, d: int): bool
proc eliminate(b: var Board, cell, d: int): bool =
  let bit = 1 shl d
  if (b[cell] and bit) == 0: return true
  b[cell] = b[cell] and not bit
  let left = b[cell]
  if left == 0: return false
  if popcount(left) == 1:
    let d2 = lowBit(left)
    for p in peers[cell]:
      if not eliminate(b, p, d2): return false
  # hidden single in units of this cell
  for u in units:
    if cell notin u: continue
    var places = -1
    var n = 0
    for c in u:
      if (b[c] and bit) != 0:
        inc n
        places = c
    if n == 0: return false
    if n == 1 and b[places] != bit:
      if not assign(b, places, d): return false
  true

proc assign(b: var Board, cell, d: int): bool =
  let others = b[cell] and not (1 shl d)
  for d2 in 0 ..< gridSize:
    if (others and (1 shl d2)) != 0:
      if not eliminate(b, cell, d2): return false
  true

proc restrict(b: var Board, cell: int, mask: Mask): bool =
  let drop = b[cell] and not mask
  for d in 0 ..< gridSize:
    if (drop and (1 shl d)) != 0:
      if not eliminate(b, cell, d): return false
  true

proc pathAlive(b: Board, path: seq[Step]): bool =
  for s in path:
    if (b[s.cell] and (1 shl s.letter)) == 0: return false
  true

proc propagateWords(ctx: Ctx, b: var Board, alive: var seq[seq[int]]): bool =
  ## Filters word paths against the board, then narrows cells that every
  ## remaining path of a word passes through. Repeats to a fixpoint.
  var changed = true
  while changed:
    changed = false
    for w in 0 ..< alive.len:
      var keep: seq[int]
      for pi in alive[w]:
        if pathAlive(b, ctx.paths[w][pi]): keep.add pi
      if keep.len == 0: return false
      if keep.len != alive[w].len: alive[w] = keep
      # cells common to all alive paths: restrict to union of their letters
      var common: array[nCells, Mask]
      var hits: array[nCells, int]
      for pi in keep:
        var seen: array[nCells, bool]
        for s in ctx.paths[w][pi]:
          common[s.cell] = common[s.cell] or (1 shl s.letter)
          if not seen[s.cell]:
            seen[s.cell] = true
            inc hits[s.cell]
      for cell in 0 ..< nCells:
        if hits[cell] == keep.len and (b[cell] and not common[cell]) != 0:
          if not restrict(b, cell, common[cell]): return false
          changed = true
  true

proc sharedOk(ctx: Ctx, alive: seq[seq[int]], b: Board): bool =
  ## With allowShared = false, a full grid is accepted only if some choice of
  ## one satisfied path per word uses pairwise disjoint cells.
  var sat: seq[seq[seq[int]]]
  for w in 0 ..< alive.len:
    var s: seq[seq[int]]
    for pi in alive[w]: s.add pathCells(ctx.paths[w][pi])
    sat.add s
  var used: array[nCells, bool]
  proc rec(w: int): bool =
    if w == sat.len: return true
    for cells in sat[w]:
      var ok = true
      for c in cells:
        if used[c]: ok = false; break
      if not ok: continue
      for c in cells: used[c] = true
      if rec(w + 1): return true
      for c in cells: used[c] = false
    false
  rec(0)

proc toGrid(ctx: Ctx, b: Board): Grid =
  for cell in 0 ..< nCells:
    let (r, c) = coordOf(cell)
    result[r][c] = ctx.letters[lowBit(b[cell])]

proc search(ctx: var Ctx, b: Board, alive: seq[seq[int]]) =
  if ctx.opts.limit > 0 and ctx.res.count >= ctx.opts.limit: return
  inc ctx.res.nodes
  var b = b
  var alive = alive
  if not propagateWords(ctx, b, alive): return
  # pick most constrained open cell
  var best = -1
  var bestN = gridSize + 1
  for cell in 0 ..< nCells:
    let n = popcount(b[cell])
    if n > 1 and n < bestN:
      best = cell
      bestN = n
  if best < 0:
    if not ctx.opts.allowShared and not sharedOk(ctx, alive, b): return
    inc ctx.res.count
    if ctx.res.solutions.len < ctx.opts.keep:
      ctx.res.solutions.add toGrid(ctx, b)
    return
  for d in 0 ..< gridSize:
    if (b[best] and (1 shl d)) == 0: continue
    var b2 = b
    if assign(b2, best, d):
      search(ctx, b2, alive)
    if ctx.opts.limit > 0 and ctx.res.count >= ctx.opts.limit: return

proc initCtx(p: Problem, opts: SolveOptions, b: var Board,
             alive: var seq[seq[int]]): (Ctx, bool) =
  var ctx = Ctx(letters: p.letters, opts: opts)
  for i in 0 ..< nCells: b[i] = fullMask
  if validate(p).len > 0: return (ctx, false)
  var ok = true
  for h in p.letterHints:
    if ok: ok = assign(b, cellOf(h.pos), letterIndex(p.letters, h.letter))
  for h in p.wordHints:
    var idx: seq[int]
    for ch in h.word: idx.add letterIndex(p.letters, ch)
    let ps = enumeratePaths(cellOf(h.pos), idx, opts.allowRevisit)
    ctx.paths.add ps
    var all: seq[int]
    for i in 0 ..< ps.len: all.add i
    alive.add all
  (ctx, ok)

proc wordPathCounts*(p: Problem, opts = defaultOptions()): seq[int] =
  ## For each word hint, how many geometric paths survive the static
  ## prefilter (before any search). Handy to see how much a word constrains.
  var b: Board
  var alive: seq[seq[int]]
  let (ctx, _) = initCtx(p, opts, b, alive)
  for ps in ctx.paths: result.add ps.len

proc solve*(p: Problem, opts = defaultOptions()): SolveResult =
  ## Counts (up to `opts.limit`) and returns (up to `opts.keep`) solutions.
  var b: Board
  var alive: seq[seq[int]]
  var (ctx, ok) = initCtx(p, opts, b, alive)
  if ok: search(ctx, b, alive)
  ctx.res.complete = opts.limit == 0 or ctx.res.count < opts.limit
  ctx.res

proc countSolutions*(p: Problem, limit = 1000): int =
  ## Number of solutions, capped at `limit` (0 = exact, may be slow for
  ## nearly empty problems: an empty 6x6 has 28,200,960 grids).
  solve(p, defaultOptions(limit = limit, keep = 0)).count

proc isUnique*(p: Problem): bool =
  countSolutions(p, limit = 2) == 1

proc withLetter*(p: Problem, pos: Coord, letter: char): Problem =
  result = p
  result.letterHints.add HintLetter(pos: pos, letter: letter)

proc withWord*(p: Problem, pos: Coord, word: string): Problem =
  result = p
  result.wordHints.add HintWord(pos: pos, word: word.toUpperAscii)

proc candidates*(p: Problem, opts = defaultOptions()): CellCandidates =
  ## For every cell, the letters it takes in at least one solution, in the
  ## order of `p.letters`. Exact: each (cell, letter) is witnessed by a
  ## solution. Empty everywhere if the problem has no solution.
  var o = opts
  o.limit = 1
  o.keep = 1
  var possible: array[nCells, Mask]
  var tried: array[nCells, Mask]
  for cell in 0 ..< nCells:
    for d in 0 ..< gridSize:
      let bit = 1 shl d
      if ((possible[cell] or tried[cell]) and bit) != 0: continue
      tried[cell] = tried[cell] or bit
      let r = solve(p.withLetter(coordOf(cell), p.letters[d]), o)
      if r.count > 0:
        let g = r.solutions[0]
        for c2 in 0 ..< nCells:
          let (rr, cc) = coordOf(c2)
          possible[c2] = possible[c2] or (1 shl letterIndex(p.letters, g[rr][cc]))
  for cell in 0 ..< nCells:
    let (r, c) = coordOf(cell)
    for d in 0 ..< gridSize:
      if (possible[cell] and (1 shl d)) != 0: result[r][c].add p.letters[d]

proc forcedCells*(cands: CellCandidates): int =
  ## Number of cells whose letter is the same in every solution.
  for row in cands:
    for c in row:
      if c.len == 1: inc result

proc wordStarts*(p: Problem, word: string, limit = 100,
                 opts = defaultOptions()): seq[WordStart] =
  ## Every start cell where `word` can be added keeping at least one
  ## solution, with the (capped) solution count. Sorted by count, fewest
  ## first: the top entries are the most constraining placements.
  var o = opts
  o.limit = limit
  o.keep = 0
  for cell in 0 ..< nCells:
    let pos = coordOf(cell)
    let n = solve(p.withWord(pos, word), o).count
    if n > 0: result.add WordStart(pos: pos, count: n)
  result.sort(proc(a, b: WordStart): int = cmp(a.count, b.count))

# ---------------------------------------------------------------------------
# Checking a filled grid

proc wordPaths*(g: Grid, hint: HintWord, allowRevisit = true): seq[seq[Coord]] =
  ## All paths spelling `hint.word` from `hint.pos` in a filled grid.
  var path: seq[Coord]
  var found: seq[seq[Coord]]
  let word = hint.word.toUpperAscii
  proc rec(pos: Coord, i: int) =
    if g[pos.row][pos.col].toUpperAscii != word[i]: return
    if not allowRevisit and pos in path: return
    path.add pos
    if i == word.len - 1:
      found.add path
    else:
      for n in neighbors(cellOf(pos)): rec(coordOf(n), i + 1)
    path.setLen(path.len - 1)
  if word.len > 0: rec(hint.pos, 0)
  found

proc checkGrid*(p: Problem, g: Grid, allowRevisit = true): seq[string] =
  ## Issues found checking a filled grid against the problem (empty = valid).
  for u in units:
    var seen: Mask
    for cell in u:
      let (r, c) = coordOf(cell)
      let d = letterIndex(p.letters, g[r][c])
      if d < 0:
        result.add "cell " & $coordOf(cell) & " has " & $g[r][c] & ", not one of the letters"
      elif (seen and (1 shl d)) != 0:
        result.add "letter " & $g[r][c] & " repeated in a unit containing " & $coordOf(cell)
      else:
        seen = seen or (1 shl d)
  for h in p.letterHints:
    if g[h.pos.row][h.pos.col] != h.letter:
      result.add "letter hint " & $h.letter & " at " & $h.pos & " not respected"
  for h in p.wordHints:
    if wordPaths(g, h, allowRevisit).len == 0:
      result.add "word " & h.word & " cannot be read from " & $h.pos

# ---------------------------------------------------------------------------
# Display helpers (string based, usable from JS)

proc `$`*(cands: CellCandidates): string =
  ## Pencil-mark grid: each cell shows its candidate letters (width 6).
  let sep = "+" & ("-".repeat(boxCols * (gridSize + 1) + 1) & "+").repeat(gridSize div boxCols) & "\n"
  for r in 0 ..< gridSize:
    if r mod boxRows == 0: result.add sep
    result.add "|"
    for c in 0 ..< gridSize:
      var s = ""
      for ch in cands[r][c]: s.add ch
      if s.len == 0: s = "-"
      result.add " " & s.alignLeft(gridSize)
      if (c + 1) mod boxCols == 0: result.add " |"
    result.add "\n"
  result.add sep
