"""wyoming-camoes: make wyoming-faster-whisper transcribe without timestamps.

CAMOES, the European-Portuguese Whisper fine-tune, writes junk before the first word with timestamps on,
which is faster-whisper's default, and the official server never passes the switch. This adds the one
argument to the base image's own file at build time, so every other change upstream makes is kept. The build
fails if the file no longer looks as expected, and does nothing if upstream already passes the argument.

Usage: python without_timestamps.py <path to faster_whisper_handler.py>
"""

import sys
from pathlib import Path

ANCHOR = "        kwargs = {\n"
LINE = '            "without_timestamps": True,  # wyoming-camoes: CAMOES writes junk before the first word otherwise\n'

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")

if "without_timestamps" in source:
    print(f"{path}: upstream already passes without_timestamps - nothing to patch")
    sys.exit(0)

found = source.count(ANCHOR)
if found != 1:
    sys.exit(
        f"{path}: expected the transcribe() arguments to start at one '{ANCHOR.strip()}', found {found}; "
        "the upstream file changed - update patches/without_timestamps.py"
    )

path.write_text(source.replace(ANCHOR, ANCHOR + LINE), encoding="utf-8")
print(f"{path}: without_timestamps added")
