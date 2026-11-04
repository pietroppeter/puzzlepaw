## Smoke test that the solver and code modules work with the JS backend
## (they are meant to power a browser builder page). Run with:
##   nim js -d:nodejs -r tests/test_solver_js.nim
import parloku/[code, solver]

let p = decodeProblem("AILPST_01S.33L.54P_50ITALIA.30PASTA.10ALPI")
let r = solve(p)
doAssert r.count == 1, $r.count
doAssert r.solutions[0][0] == ['T', 'S', 'I', 'P', 'L', 'A']
let bare = decodeProblem("AILPST__50ITALIA.30PASTA.10ALPI")
doAssert countSolutions(bare) == 42
doAssert forcedCells(candidates(bare)) == 6
doAssert encodeProblem(p) == "AILPST_01S.33L.54P_50ITALIA.30PASTA.10ALPI"
echo "JS solver tests passed."
