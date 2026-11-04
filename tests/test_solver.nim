import std/os
import parloku/[types, io, code, solver]

let dataDir = parentDir(currentSourcePath()) / ".." / "data"
let files = ["puzzle1-ITALIA-PASTA-ALPI.json", "puzzle2-AMICA-GIOCO-MAGIA.json"]

proc withoutGivens(p: Problem): Problem =
  result = p
  result.letterHints = @[]

block testAnswerKeysAreUniqueSolutions:
  for f in files:
    let pz = loadPuzzle(dataDir / f)
    doAssert validate(pz.problem).len == 0, f
    doAssert checkGrid(pz.problem, pz.solution).len == 0, f
    let r = solve(pz.problem)
    doAssert r.count == 1 and r.complete, f & ": " & $r.count
    doAssert r.solutions[0] == pz.solution, f
    doAssert isUnique(pz.problem), f

block testCountsWithoutGivens:
  # counts cross-checked against brute force enumeration of all
  # 28,200,960 grids (allowShared = false counts are solver-only)
  let p1 = loadPuzzle(dataDir / files[0]).problem.withoutGivens
  let p2 = loadPuzzle(dataDir / files[1]).problem.withoutGivens
  doAssert countSolutions(p1, 0) == 42
  doAssert countSolutions(p2, 0) == 34
  var o = defaultOptions(limit = 0)
  o.allowRevisit = false
  doAssert solve(p2, o).count == 24
  o = defaultOptions(limit = 0)
  o.allowShared = false
  doAssert solve(p1, o).count == 8   # words in p1 can overlap
  doAssert solve(p2, o).count == 34  # p2 words never overlap anyway
  o.allowRevisit = false
  doAssert solve(p2, o).count == 24

block testLimit:
  var empty: Problem
  empty.letters = ['A', 'B', 'C', 'D', 'E', 'F']
  let r = solve(empty, defaultOptions(limit = 500, keep = 3))
  doAssert r.count == 500 and not r.complete
  doAssert r.solutions.len == 3
  for g in r.solutions: doAssert checkGrid(empty, g).len == 0

block testCandidates:
  let pz = loadPuzzle(dataDir / files[0])
  let bare = pz.problem.withoutGivens
  let c = candidates(bare)
  doAssert forcedCells(c) == 6
  doAssert c[5][0] == @['I'] and c[5][1] == @['T'] and c[1][0] == @['A']
  doAssert c[0][4] == @['A', 'I', 'L', 'P', 'S', 'T']
  # every solution letter is among the candidates
  for r in 0 ..< 6:
    for col in 0 ..< 6:
      doAssert pz.solution[r][col] in c[r][col]
  # unique puzzle: all cells forced
  doAssert forcedCells(candidates(pz.problem)) == 36

block testNoSolution:
  let pz = loadPuzzle(dataDir / files[0])
  let bad = pz.problem.withLetter((row: 0, col: 0), 'S')  # S already at (0,1)
  doAssert countSolutions(bad) == 0
  doAssert forcedCells(candidates(bad)) == 0

block testWordPathsAndCheckGrid:
  let pz = loadPuzzle(dataDir / files[0])
  let paths = wordPaths(pz.solution, pz.problem.wordHints[0])  # ITALIA
  doAssert paths == @[@[(row: 5, col: 0), (row: 5, col: 1), (row: 5, col: 2),
                        (row: 4, col: 2), (row: 4, col: 3), (row: 4, col: 4)]]
  var g = pz.solution
  swap(g[0][0], g[0][1])
  let errs = checkGrid(pz.problem, g)
  doAssert errs.len > 0

block testValidate:
  var p = loadPuzzle(dataDir / files[0]).problem
  p.wordHints.add HintWord(pos: (row: 0, col: 0), word: "ZA")
  p.letterHints.add HintLetter(pos: (row: 9, col: 0), letter: 'A')
  doAssert validate(p).len == 2
  doAssert countSolutions(p) == 0

block testWordStarts:
  let p = decodeProblem("AILPST__50ITALIA.30PASTA")
  let starts = wordStarts(p, "ALPI")
  doAssert starts.len > 0
  for i in 1 ..< starts.len: doAssert starts[i - 1].count <= starts[i].count
  var found = false
  for s in starts:
    if s.pos == (row: 1, col: 0):
      found = true
      doAssert s.count == 42
  doAssert found

block testCodeRoundtrip:
  for f in files:
    let p = loadPuzzle(dataDir / f).problem
    let c = encodeProblem(p)
    doAssert decodeProblem(c) == p, c
  doAssert encodeProblem(loadPuzzle(dataDir / files[0]).problem) ==
    "AILPST_01S.33L.54P_50ITALIA.30PASTA.10ALPI"
  doAssert decodeProblem("ailpst__50italia").wordHints[0].word == "ITALIA"
  for bad in ["AILPST", "AILPS__", "AILPST_9xS_", "AILPST__6"]:
    doAssertRaises(ValueError): discard decodeProblem(bad)

echo "All solver tests passed."
