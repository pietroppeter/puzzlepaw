import illwill
import values

const
  gridX* = 2
  gridY* = 5
  hLine* = "+-------+-------+"

const wordColors* = [fgRed, fgMagenta, fgBlue, fgYellow, fgGreen, fgCyan]

proc hintColor*(idx: int): ForegroundColor =
  wordColors[idx mod wordColors.len]

proc cellScreenX*(col: int): int =
  let box = col div boxCols
  let inBox = col mod boxCols
  result = gridX + 1 + box * 8 + inBox * 2 + 1

proc cellScreenY*(row: int): int =
  let box = row div boxRows
  result = gridY + 1 + box * (boxRows + 1) + (row mod boxRows)

proc keyToChar*(key: Key): char =
  let ord = key.int
  if ord >= Key.A.int and ord <= Key.Z.int:
    return chr(ord - Key.A.int + 'A'.int)
  if ord >= Key.ShiftA.int and ord <= Key.ShiftZ.int:
    return chr(ord - Key.ShiftA.int + 'A'.int)
  return '\0'

proc drawGridLines*(tb: var TerminalBuffer) =
  ## Draw the horizontal separator lines for a 6x6 grid.
  for boxRow in 0 .. (gridSize div boxRows):
    let y = gridY + boxRow * (boxRows + 1)
    tb.write(gridX, y, fgYellow, hLine)

proc drawGridSeparators*(tb: var TerminalBuffer, row: int) =
  ## Draw the vertical separators for a grid row.
  let y = cellScreenY(row)
  tb.write(gridX, y, fgYellow, "|")
  tb.write(gridX + 8, y, fgYellow, "|")
  tb.write(gridX + 16, y, fgYellow, "|")
