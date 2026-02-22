# Package
version       = "0.1.0"
author        = "Pietro Peterlongo"
description   = "Small tools for crafting logic puzzles"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.2.0"
requires "illwill"
requires "jsony"
requires "nimib >= 0.3.12"
requires "karax >= 1.5.0"

task play, "Run the TUI":
  exec "nim r src/pzlpaw.nim"

task webui, "Build the web UI (outputs docs/index.html)":
  exec "nim r src/webui.nim"
