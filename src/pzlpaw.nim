import std/os
import illwill
import parloku/[io, play, craft]

const dataDir = "data"

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc mainMenu(): int =
  ## Show main menu. Returns 0=Play, 1=Craft, 2=Quit, -1=quit.
  let options = ["Play", "Craft", "Quit"]
  var selected = 0

  while true:
    var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
    tb.write(2, 1, fgYellow, "puzzlepaw")
    tb.write(2, 3, fgWhite, "Select an option:")

    for i, opt in options:
      let color = if i == selected: fgGreen else: fgWhite
      let prefix = if i == selected: "> " else: "  "
      tb.write(2, 5 + i, color, prefix & opt)

    tb.display()
    sleep(20)

    let key = getKey()
    case key
    of Key.Up:
      if selected > 0: selected.dec
    of Key.Down:
      if selected < options.len - 1: selected.inc
    of Key.Enter:
      return selected
    of Key.Escape, Key.Q, Key.ShiftQ:
      return -1
    else:
      discard

proc runPlay() =
  let idx = selectPuzzle(dataDir)
  if idx < 0:
    return
  let files = listPuzzles(dataDir)
  let puzzle = loadPuzzle(dataDir / files[idx])
  play(puzzle)

proc main() =
  illwillInit(fullscreen = true)
  setControlCHook(exitProc)
  hideCursor()

  while true:
    let choice = mainMenu()
    case choice
    of 0: runPlay()
    of 1: selectAndCraft(dataDir)
    of 2, -1:
      exitProc()
    else:
      discard

main()
