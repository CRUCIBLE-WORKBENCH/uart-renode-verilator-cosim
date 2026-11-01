#!/usr/bin/env python3
"""Remove this project's generated output tree without following a root symlink."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parent.parent
output = root / "output"
if output.is_symlink():
    raise SystemExit("Refusing to clean: output/ is a symbolic link")
if output.exists():
    shutil.rmtree(output)
print("clean: removed generated output/; sources and installed tools preserved")
