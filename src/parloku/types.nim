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

  Solution* = array[6, array[6, char]]
