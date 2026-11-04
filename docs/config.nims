# Paths for the nimib explainer (deps from docs/deps.sh, not committed).
import std/os
let deps = getEnv("PUZZLEPAW_DOCS_DEPS", thisDir() / "deps")
for d in ["nimib", "fusion", "markdown", "parsetoml"]:
  switch("path", deps / d / "src")
switch("path", thisDir() / ".." / "src")
switch("hints", "off")
