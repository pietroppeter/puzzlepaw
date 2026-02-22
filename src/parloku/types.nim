type
  Coord* = tuple[row, col: int]

  HintLetter* = object
    pos*: Coord
    letter*: char

  HintWord* = object
    pos*: Coord
    word*: string

  Problem* = object
    letters*: array[6, char]
    letterHints*: seq[HintLetter]
    wordHints*: seq[HintWord]

  Grid* = array[6, array[6, char]]

  Puzzle* = object
    problem*: Problem
    solution*: Grid
