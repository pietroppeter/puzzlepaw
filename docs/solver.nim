## nimib explainer for the Parloku solver. Build from this folder:
##   sh deps.sh && nim c -r -d:release solver.nim
## writes docs/index.html.
import std/[json, os, strutils, strformat, times]
import nimib
import style
import parloku/[types, io, code, solver]

nbInit
nb.doc.filename = currentSourcePath().parentDir / "index.html"
nb.doc.context["title"] = %"Parloku solver"
nb.doc.context["stylesheet"] = %(pageStyle & extraStyle)
nb.doc.context["highlight"] = %""
nb.doc.context["disableHighlightJs"] = %true
func pageHeader(blk: JsonNode, nb: Nb): string =
  """<header><span>puzzlepaw · parloku solver</span><span>a nimib notebook · nim → js</span></header>"""
nb.backend.partials["header"] = pageHeader

nbRawHtml: """
<h1><span class="tile" style="background:#2f5d9e">S</span>olver</h1>
<p class="lede">How many grids fit these clues? A tour of the constraint solver behind the future Parloku builder.</p>
"""

nbText: """
A Parloku is a 6×6 mini sudoku spelled with six letters, plus a few words threaded through the grid.
The future builder page will let you pick letters, words and givens, and it needs to answer one
question fast: **how many solutions are left?** This notebook explains the solver in
[`src/parloku/solver.nim`](https://github.com/pietroppeter/puzzlepaw/blob/main/src/parloku/solver.nim)
and runs it on the two puzzles in `data/`.

Every grey code block below runs while nimib builds the page, and its output is printed underneath.
The last section is the same solver compiled to JavaScript, running in your browser.
"""

nbRawHtml: """
<div class="rules">
  <div><b>01 · SUDOKU</b>Each of the six letters appears once in every row, column and 2×3 box.</div>
  <div><b>02 · WORDS</b>Each word starts in its numbered cell and moves one step up, down, left or right per letter.</div>
  <div><b>03 · FREEDOM</b>By the rules a path may step back onto a cell and two words may share cells. The solver can forbid both.</div>
</div>
"""

nbRawHtml: """<h2><span class="num">01 · THE INPUT</span>A problem is letters, givens and words</h2>"""

nbText: """
Here is puzzle 1 from `data/`. Numbers in the grid mark where each word starts. The same problem also
travels as a short code, `LETTERS_GIVENS_WORDS`, with 0-based row and column digits, so the builder
can hand out a link.
"""

nbCode:
  let puzzle1 = loadPuzzle("../data/puzzle1-ITALIA-PASTA-ALPI.json")
  let p1 = puzzle1.problem
  printProblem(p1)
  echo ""
  echo "code: ", encodeProblem(p1)
  doAssert decodeProblem(encodeProblem(p1)) == p1

nbRawHtml: """<h2><span class="num">02 · THE BOARD</span>Thirty-six little sets</h2>"""

nbText: """
Internally the grid is 36 bitmasks, one per cell, where bit *i* means "letter *i* is still possible".
Every cell has 20 *peers* (the cells that share its row, column or box). Two classic sudoku rules
narrow the masks:

- **Naked single:** when a cell is down to one letter, remove that letter from all its peers.
- **Hidden single:** when a letter fits in only one cell of a row, column or box, it goes there.

Putting a letter in a cell is "eliminate the other five". Each elimination can set off more, and if any
cell ends up with no letters left, the branch is dead. That is all the sudoku part needs. On its
own it still leaves 28,200,960 possible 6×6 grids, so the words must do the real work.
"""

nbRawHtml: """<h2><span class="num">03 · THE WORDS</span>Every word becomes a list of paths</h2>"""

nbText: """
A word with *n* letters starting at a cell can wander in at most 4<sup>n−1</sup> ways. The solver lists
them all up front and throws out the ones that cannot work in any grid:

- a path that comes back to a cell must ask for the same letter there,
- two different cells in the same row, column or box can never hold the same letter.

The second rule is what makes ITALIA interesting: its two A's and two I's must land in
different rows, columns *and* boxes, so it has to cross box borders. Here is how many paths survive
for each word, with and without revisiting:
"""

nbCode:
  var strict = defaultOptions()
  strict.allowRevisit = false
  for i, h in p1.wordHints:
    echo &"{h.word:<7} from {h.pos}: ",
      &"{wordPathCounts(p1)[i]:>3} paths (revisits allowed), ",
      &"{wordPathCounts(p1, strict)[i]:>3} without"

nbText: """
While the search runs, two things happen to these lists after every step:

1. **Pruning:** a path dies as soon as one of its cells has lost the letter the path needs there.
   A word with no live paths kills the branch.
2. **Forcing:** if *every* live path of a word goes through some cell, that cell can only hold one
   of the letters those paths ask for, so the solver narrows it. With a single live path, the whole
   word gets written in.

These two steps repeat, together with the sudoku rules, until nothing changes.
"""

nbRawHtml: """<h2><span class="num">04 · COUNTING</span>Branch on cells, not on paths</h2>"""

nbText: """
When nothing more can be deduced, the solver picks the open cell with the fewest letters and tries each
one. It branches on **cells** rather than on paths on purpose: one grid can spell a word along several
paths, and branching on paths would count that grid more than once. Branching on cells counts each
grid exactly once. `solve` stops at `limit` solutions and says whether it looked at everything:
"""

nbCode:
  let r1 = solve(p1)
  echo "solutions: ", r1.count, "  (search complete: ", r1.complete, ", nodes: ", r1.nodes, ")"
  echo "matches the answer key: ", r1.solutions[0] == puzzle1.solution
  echo "isUnique: ", isUnique(p1)

nbText: """
One search node is enough: propagation alone solves puzzle 1. Now take the three givens away and see
what the words manage by themselves:
"""

nbCode:
  var bare1 = p1
  bare1.letterHints = @[]
  let t0 = cpuTime()
  let nBare = countSolutions(bare1, limit = 0)   # 0 = no cap, exact count
  echo "puzzle 1 without givens: ", nBare, " solutions in ",
    formatFloat((cpuTime() - t0) * 1000, ffDecimal, 1), " ms"

nbRawHtml: """<h2><span class="num">05 · CANDIDATES</span>The true pencil marks</h2>"""

nbText: """
The count says *how many*. For building you also want to know *where* the freedom is. `candidates`
returns, for each cell, the letters it takes in at least one solution. This is exact: each letter
listed is backed by a real solution, unlike the pencil marks a human writes. A cell with one candidate
is already forced by the words, so a given there would be wasted:
"""

nbCode:
  let c1 = candidates(bare1)
  echo forcedCells(c1), " of 36 cells forced"
  stdout.write $c1

nbText: """
The words already pin down the A at (1,0), the P and A at (3,0)–(3,1), and the I-T-A at the bottom left.
The givens in the original puzzle, S at (0,1), L at (3,3) and P at (5,4), sit in cells that still had
three or more options.
"""

nbRawHtml: """<h2><span class="num">06 · PLACING WORDS</span>Where could the next word go?</h2>"""

nbText: """
`wordStarts` answers the other builder question: given what is already placed, where can a new word
start, and how many solutions does each choice leave? The list is sorted with the most constraining
starts first. Here are the first ten for ALPI, with only ITALIA and PASTA placed:
"""

nbCode:
  let two = decodeProblem("AILPST__50ITALIA.30PASTA")
  echo "ITALIA + PASTA: ", countSolutions(two), " solutions (capped at 1000)"
  for s in wordStarts(two, "ALPI")[0 ..< 10]:
    echo &"  ALPI at ({s.pos.row},{s.pos.col}) leaves {s.count} solutions"

nbText: """
Pietro's actual choice, ALPI at (1,0), leaves 42, and three givens take it to one.
"""

nbRawHtml: """<h2><span class="num">07 · STRICTER RULES</span>Elegant puzzles</h2>"""

nbText: """
The rules allow a path to revisit a cell and two words to share cells, but Pietro avoids both
for elegance. `SolveOptions` can turn each one off, to check that a puzzle is also unique under
the stricter reading, or to see how much of its freedom comes from overlaps:
"""

nbCode:
  let puzzle2 = loadPuzzle("../data/puzzle2-AMICA-GIOCO-MAGIA.json")
  var bare2 = puzzle2.problem
  bare2.letterHints = @[]
  for (name, revisit, shared) in [("rules as written", true, true),
                                  ("no revisits", false, true),
                                  ("no shared cells", true, false),
                                  ("neither", false, false)]:
    var o = defaultOptions(limit = 0)
    o.allowRevisit = revisit
    o.allowShared = shared
    echo &"{name:<17} puzzle1: {solve(bare1, o).count:>3}   puzzle2: {solve(bare2, o).count:>3}   (no givens)"
  var strictest = defaultOptions()
  strictest.allowRevisit = false
  strictest.allowShared = false
  echo "with givens, unique under the strictest reading: ",
    solve(p1, strictest).count == 1, " and ", solve(puzzle2.problem, strictest).count == 1

nbRawHtml: """<h2><span class="num">08 · CHECKING</span>Grids and problems</h2>"""

nbText: """
Two smaller tools round it off. `checkGrid` tests a filled grid against the clues, and `wordPaths`
shows how each word is read in it. `validate` catches problems that cannot be set up at all, before
any search runs:
"""

nbCode:
  echo "answer key issues: ", checkGrid(p1, puzzle1.solution)
  echo "ITALIA is read along: ", wordPaths(puzzle1.solution, p1.wordHints[0])
  var broken = p1.withWord((row: 0, col: 0), "PIZZA")
  echo "validate PIZZA: ", validate(broken)

nbRawHtml: """<h2><span class="num">09 · CAN WE TRUST IT?</span>Cross-checked by brute force</h2>"""

nbText: """
The no-givens counts (42 and 34, and 24 for puzzle 2 without revisits) were checked against a plain
brute force run that walks all 28,200,960 grids and tests each word with `checkGrid`. That takes
about five and a half minutes. The solver gives the same numbers in milliseconds.
The test suite (`tests/test_solver.nim`) keeps these numbers fixed, and checks both answer keys.
"""

nbRawHtml: """<h2><span class="num">10 · IN THE BROWSER</span>Try it: a builder preview</h2>"""

nbText: """
This is the same `solver.nim`, compiled with `nim js`. Pick a puzzle or paste a code. Each cell shows
its candidate letters. **Tap a small letter to make it a given**, and tap a given to remove it.
The count and the code update as you go, and you are done when the count reaches **1**.
"""

nbRawHtml: """
<div class="lab">
  <div class="picker" id="presets"></div>
  <div class="row"><input id="code" spellcheck="false" autocomplete="off"><button class="btn" id="go">solve</button></div>
  <div class="row opts">
    <label><input type="checkbox" id="revisit" checked> paths may revisit</label>
    <label><input type="checkbox" id="shared" checked> words may share cells</label>
  </div>
  <div class="verdict" id="verdict"></div>
  <div class="cgrid" id="cgrid"></div>
  <div class="words" id="words"></div>
</div>
"""

nbJsFromCode:
  import std/[dom, strutils, strformat]
  import parloku/[types, code, solver]

  proc dataOf(ev: Event, k: cstring): cstring {.importjs: "((e, k) => e.target.closest('[data-' + k + ']')?.getAttribute('data-' + k) ?? null)(#, #)".}
  proc checked(e: Element): bool {.importjs: "#.checked".}
  proc value(e: Element): cstring {.importjs: "#.value".}
  proc setValue(e: Element, v: cstring) {.importjs: "#.value = #".}

  const presets = [
    ("puzzle 1", "AILPST_01S.33L.54P_50ITALIA.30PASTA.10ALPI"),
    ("puzzle 1, no givens", "AILPST__50ITALIA.30PASTA.10ALPI"),
    ("puzzle 2", "ACGIMO_41I.42O.54I.55O_00AMICA.11GIOCO.05MAGIA"),
    ("puzzle 2, no givens", "ACGIMO__00AMICA.11GIOCO.05MAGIA"),
    ("two words", "AILPST__50ITALIA.30PASTA"),
  ]
  const glazes = ["#2f5d9e", "#c8553d", "#6f8a2e", "#7d3c6b", "#2f9c95", "#e9b52f"]

  var prob: Problem

  proc opts(): SolveOptions =
    result = defaultOptions(limit = 1000, keep = 0)
    result.allowRevisit = getElementById("revisit").checked
    result.allowShared = getElementById("shared").checked

  proc isGiven(r, c: int): int =
    for i, h in prob.letterHints:
      if h.pos == (row: r, col: c): return i
    -1

  proc render() =
    let o = opts()
    getElementById("code").setValue(cstring(encodeProblem(prob)))
    let issues = validate(prob)
    let verdict = getElementById("verdict")
    if issues.len > 0:
      verdict.innerHTML = cstring("<b class=bad>invalid</b> " & issues.join("; "))
      getElementById("cgrid").innerHTML = ""
      return
    let r = solve(prob, o)
    let n = if r.complete: $r.count else: "≥ " & $r.count
    let cls = if r.count == 1: "one" elif r.count == 0: "bad" else: "many"
    let word = if r.count == 1 and r.complete: "solution · unique" else: "solutions"
    var cands: CellCandidates
    if r.count > 0: cands = candidates(prob, o)
    verdict.innerHTML = cstring(&"<b class={cls}>{n}</b> {word} · {forcedCells(cands)}/36 cells forced")
    var starts: array[6, array[6, string]]
    for i, h in prob.wordHints:
      starts[h.pos.row][h.pos.col].add &"<i style=\"background:{glazes[i mod 6]}\">{i + 1}</i>"
    var html = ""
    for row in 0 ..< 6:
      for col in 0 ..< 6:
        var k = "cell"
        if col == 2: k.add " bx"
        if row == 1 or row == 3: k.add " by"
        let g = isGiven(row, col)
        var inner = starts[row][col]
        if g >= 0:
          inner.add &"<b class=given data-given=\"{g}\">{prob.letterHints[g].letter}</b>"
        elif cands[row][col].len == 1:
          inner.add &"<b class=forced>{cands[row][col][0]}</b>"
        else:
          inner.add "<span class=marks>"
          for ch in cands[row][col]:
            inner.add &"<a data-pick=\"{row}{col}{ch}\">{ch}</a>"
          inner.add "</span>"
        html.add &"<div class=\"{k}\">{inner}</div>"
    getElementById("cgrid").innerHTML = cstring(html)
    var ws = ""
    for i, h in prob.wordHints:
      ws.add &"<span><i style=\"background:{glazes[i mod 6]}\">{i + 1}</i>{h.word}</span>"
    getElementById("words").innerHTML = cstring(ws)

  proc load(s: string) =
    try:
      prob = decodeProblem(s)
      render()
    except ValueError as e:
      getElementById("verdict").innerHTML = cstring("<b class=bad>bad code</b> " & e.msg)

  var ph = ""
  for i, (name, c) in presets:
    ph.add &"<button class=btn data-preset=\"{i}\">{name}</button>"
  getElementById("presets").innerHTML = cstring(ph)
  getElementById("presets").addEventListener("click", proc (ev: Event) =
    let i = dataOf(ev, "preset")
    if i != nil: load(presets[parseInt($i)][1]))
  getElementById("go").addEventListener("click", proc (ev: Event) =
    load($getElementById("code").value))
  for id in ["revisit", "shared"]:
    getElementById(cstring(id)).addEventListener("change", proc (ev: Event) = render())
  getElementById("cgrid").addEventListener("click", proc (ev: Event) =
    let pick = dataOf(ev, "pick")
    if pick != nil:
      let s = $pick
      prob = prob.withLetter((row: ord(s[0]) - ord('0'), col: ord(s[1]) - ord('0')), s[2])
      render()
      return
    let g = dataOf(ev, "given")
    if g != nil:
      prob.letterHints.delete(parseInt($g))
      render())
  load(presets[1][1])

nbText: """
Starting from "puzzle 1, no givens", tap S at (0,1) and then L at (3,3): the count drops from 42 to 4
and then to 1. So puzzle 1 only needs **two** of its three givens; the P at (5,4) is already forced.
The page checks this while it builds:
"""

nbCode:
  let twoGivens = decodeProblem("AILPST_01S.33L_50ITALIA.30PASTA.10ALPI")
  echo "S + L only: ", countSolutions(twoGivens), " solution(s)"
  echo "candidates at (5,4) without the P given: ", candidates(twoGivens)[5][4]

nbText: """
This count says how many solutions there are, not how hard they are to find. Pietro solves a Parloku
by hand by writing each word's first letter, then following the words letter by letter wherever the
sudoku rules leave only one place, and finishing with plain sudoku. A step-by-step solver that copies
that method could rate difficulty in the builder. It is a natural next tool.

**What's next.** The builder page in [parloku](https://github.com/pietroppeter/parloku) can import
`parloku/solver` and `parloku/code` directly, as this page does, and add letter and word pickers
around this grid. The code in the box is the same one the Parloku game reads from `?p=`.
"""

nbSave
