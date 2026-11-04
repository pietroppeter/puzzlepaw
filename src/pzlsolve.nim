## Command line front end for the Parloku solver.
##
##   nim r src/pzlsolve.nim data/puzzle1-ITALIA-PASTA-ALPI.json
##   nim r src/pzlsolve.nim AILPST__50ITALIA.30PASTA.10ALPI --limit:100
##   nim r src/pzlsolve.nim AILPST__50ITALIA --starts:PASTA
##
## Options:
##   --limit:N       stop counting at N solutions (default 1000, 0 = exact)
##   --show:N        print up to N solutions (default 1)
##   --no-revisit    word paths may not step back onto a used cell
##   --no-shared     two words may not use the same cell
##   --starts:WORD   list where WORD could start, with solution counts
##   --no-candidates skip the candidate (pencil mark) grid

import std/[os, parseopt, strutils, strformat]
import parloku/[types, io, code, solver]

proc main() =
  var source = ""
  var opts = defaultOptions()
  var show = 1
  var startsWord = ""
  var showCands = true
  for kind, key, val in getopt():
    case kind
    of cmdArgument: source = key
    of cmdLongOption, cmdShortOption:
      case key
      of "limit": opts.limit = parseInt(val)
      of "show": show = parseInt(val)
      of "no-revisit": opts.allowRevisit = false
      of "no-shared": opts.allowShared = false
      of "starts": startsWord = val.toUpperAscii
      of "no-candidates": showCands = false
      else: quit "unknown option --" & key
    of cmdEnd: discard
  if source == "":
    quit "usage: pzlsolve <puzzle.json | code> [options]"

  var p: Problem
  var key: Grid
  var hasKey = false
  if fileExists(source):
    let pz = loadPuzzle(source)
    p = pz.problem
    key = pz.solution
    hasKey = key[0][0] != '\0'
  else:
    p = decodeProblem(source)

  printProblem(p)
  echo ""
  echo "Code: ", encodeProblem(p)
  let issues = validate(p)
  if issues.len > 0:
    echo "Invalid problem:"
    for i in issues: echo "  - ", i
    quit 1

  opts.keep = show
  let r = solve(p, opts)
  let countStr = if r.complete: $r.count else: &">= {r.count}"
  echo &"Solutions: {countStr}  ({r.nodes} search nodes)"
  if hasKey:
    let errs = checkGrid(p, key, opts.allowRevisit)
    if errs.len == 0:
      echo "Answer key: valid", (if r.count == 1: " and unique" else: "")
    else:
      echo "Answer key: INVALID"
      for e in errs: echo "  - ", e
  for i, g in r.solutions:
    echo ""
    echo "Solution ", i + 1, ":"
    printSolution(g)

  if showCands and r.count > 1:
    let c = candidates(p, opts)
    echo ""
    echo &"Candidates ({forcedCells(c)}/36 cells forced):"
    stdout.write $c

  if startsWord != "":
    echo ""
    echo &"Possible starts for {startsWord} (solutions, capped at {opts.limit}):"
    for s in wordStarts(p, startsWord, opts.limit, opts):
      echo &"  ({s.pos.row},{s.pos.col}): {s.count}"

main()
