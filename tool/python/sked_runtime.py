"""Frozen task inputs and files to include in the execution receipt."""

import json
import os
from pathlib import Path
import time
from types import MappingProxyType
import uuid

inputs = MappingProxyType({})
output_dir = None
_published = None


def _initialize(run_directory):
    global inputs, output_dir, _published
    inputs = MappingProxyType(json.loads(os.environ.get("SKED_INPUTS_JSON", "{}")))
    output_dir = run_directory / "artifacts"
    _published = run_directory / "publications"


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
    publication = _published / f"{time.monotonic_ns():020d}-{uuid.uuid4().hex}.json"
    temporary = publication.with_suffix(".tmp")
    with temporary.open("x", encoding="utf-8", newline="\n") as target:
        json.dump(record, target, ensure_ascii=False)
        target.write("\n")
        target.flush()
        os.fsync(target.fileno())
    os.replace(temporary, publication)
    return str(resolved)


if "_SKED_EXECUTION_DIR" in os.environ:
    _initialize(Path(os.environ["_SKED_EXECUTION_DIR"]))
