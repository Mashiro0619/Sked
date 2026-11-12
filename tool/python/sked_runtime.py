"""Frozen task inputs and files to include in the execution receipt."""

import json
import os
from pathlib import Path
import threading
from types import MappingProxyType

inputs = MappingProxyType({})
output_dir = None
_published = None
_publish_lock = threading.Lock()


def _initialize(run_directory):
    global inputs, output_dir, _published
    inputs = MappingProxyType(json.loads(os.environ.get("SKED_INPUTS_JSON", "{}")))
    output_dir = run_directory / "artifacts"
    _published = run_directory / "published.ndjson"


def publish(path, name=None, media_type=None):
    """Register an existing output file; return its absolute path."""
    if _published is None:
        raise RuntimeError("This module requires a Sked execution task")
    resolved = Path(path).resolve(strict=True)
    if not resolved.is_file():
        raise ValueError("publish expects a file")
    if name is not None and not isinstance(name, str):
        raise TypeError("name must be a string")
    if media_type is not None and not isinstance(media_type, str):
        raise TypeError("media_type must be a string")
    record = {"path": str(resolved), "name": name, "mediaType": media_type}
    with _publish_lock:
        with _published.open("a", encoding="utf-8", newline="\n") as target:
            target.write(json.dumps(record, ensure_ascii=False) + "\n")
            target.flush()
            os.fsync(target.fileno())
    return str(resolved)


if "_SKED_EXECUTION_DIR" in os.environ:
    _initialize(Path(os.environ["_SKED_EXECUTION_DIR"]))
