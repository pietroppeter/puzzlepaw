## Compact, URL-safe text code for a Parloku problem, so a builder can
## produce a link that opens the game (e.g. `play.html?p=<code>`).
##
## Format: `LETTERS_GIVENS_WORDS`
## - LETTERS: the six letters, e.g. `AILPST`
## - GIVENS: `.`-separated `<row><col><letter>`, e.g. `01S.33L.54P`
## - WORDS: `.`-separated `<row><col><WORD>`, e.g. `50ITALIA.30PASTA.10ALPI`
## Rows and columns are 0-based digits. Empty sections are allowed
## (`AILPST__50ITALIA`). Only `A-Z`, `0-9`, `_` and `.` are used, all
## URL-safe without escaping. Pure Nim, works with the JS backend.

import std/strutils
import types
import values

proc encodeProblem*(p: Problem): string =
  for l in p.letters: result.add l
  result.add '_'
  for i, h in p.letterHints:
    if i > 0: result.add '.'
    result.add $h.pos.row & $h.pos.col & $h.letter
  result.add '_'
  for i, h in p.wordHints:
    if i > 0: result.add '.'
    result.add $h.pos.row & $h.pos.col & h.word.toUpperAscii

proc parseCoord(s: string): Coord =
  if s.len < 2 or s[0] notin '0'..'9' or s[1] notin '0'..'9':
    raise newException(ValueError, "bad coordinate in " & s)
  result = (row: ord(s[0]) - ord('0'), col: ord(s[1]) - ord('0'))
  if result.row >= gridSize or result.col >= gridSize:
    raise newException(ValueError, "coordinate outside grid in " & s)

proc decodeProblem*(code: string): Problem =
  ## Raises ValueError on malformed codes. Does not check solvability
  ## (use `solver.validate` / `solver.countSolutions`).
  let parts = code.strip.toUpperAscii.split('_')
  if parts.len != 3:
    raise newException(ValueError, "expected LETTERS_GIVENS_WORDS")
  if parts[0].len != gridSize:
    raise newException(ValueError, "expected " & $gridSize & " letters")
  for i, ch in parts[0]: result.letters[i] = ch
  if parts[1].len > 0:
    for item in parts[1].split('.'):
      if item.len != 3: raise newException(ValueError, "bad given " & item)
      result.letterHints.add HintLetter(pos: parseCoord(item), letter: item[2])
  if parts[2].len > 0:
    for item in parts[2].split('.'):
      if item.len < 3: raise newException(ValueError, "bad word " & item)
      result.wordHints.add HintWord(pos: parseCoord(item), word: item[2..^1])
