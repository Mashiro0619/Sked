"""Start the approved source after the host has attached this process to its job."""

import json
import os
from pathlib import Path
import runpy
import sys


def main():
    if sys.stdin.buffer.read(1) != b"\x01":
        return
    run_directory = Path(sys.argv[1])
    os.environ["_SKED_EXECUTION_DIR"] = str(run_directory)
    import sked_runtime
    invocation = json.loads((run_directory / "invocation.json").read_text("utf-8"))
    source = run_directory / "source.py"
    sys.argv = [str(source), *invocation["argv"]]
    if not invocation.get("controlledReader", False):
        sys.path.insert(0, os.getcwd())
    runpy.run_path(str(source), run_name="__main__")


if __name__ == "__main__":
    main()
