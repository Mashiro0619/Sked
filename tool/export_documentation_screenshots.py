"""Validate a complete desktop UI capture and export documentation JPEGs (requires Pillow)."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

SCENES = {
    "student-week-desktop", "general-week-desktop", "general-month-desktop",
    "course-editor-desktop", "settings-desktop", "course-details-desktop",
    "event-details-desktop", "event-editor-desktop",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(source: Path, destination: Path) -> None:
    source = source.resolve(strict=True)
    destination = destination.resolve()
    if (source == destination or source.is_relative_to(destination)
            or destination.is_relative_to(source)):
        raise ValueError("Keep raw captures outside the published screenshot directory.")
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    captures = manifest["captures"]
    expected = {(locale, scene) for locale in ("zh", "en") for scene in SCENES}
    actual = {(item["locale"], item["scene"]) for item in captures}
    if actual != expected or len(captures) != len(expected):
        raise ValueError(f"Incomplete or duplicate capture set: missing={expected - actual}, extra={actual - expected}")
    # Check every input before replacing any published file.
    for item in captures:
        relative = Path(item["file"])
        path = (source / relative).resolve(strict=True)
        if not path.is_relative_to(source) or relative.as_posix() != f'{item["locale"]}/{item["scene"]}.png':
            raise ValueError(f"Unexpected capture path: {relative}")
        expected_size = (1440, 900)
        if (item["brightness"] != "light" or item["platformStyle"] != "windows"
                or (item["widthDp"], item["heightDp"]) != expected_size
                or (item["widthPx"], item["heightPx"]) != expected_size):
            raise ValueError(f"Expected a light Windows capture at {expected_size}: {relative}")
        with Image.open(path) as image:
            if image.format != "PNG" or image.size != (item["widthPx"], item["heightPx"]):
                raise ValueError(f"Invalid image dimensions/format: {relative}")
            image.verify()
    output_items = []
    for item in sorted(captures, key=lambda value: value["file"]):
        input_path = source / item["file"]
        relative = Path(item["locale"]) / f'{item["scene"]}.jpg'
        output_path = destination / relative
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(input_path) as image:
            image.convert("RGB").save(output_path, "JPEG", quality=90, subsampling=0,
                                      optimize=True, progressive=True)
        output_items.append({**item, "file": relative.as_posix(), "sha256": digest(output_path),
                             "bytes": output_path.stat().st_size})
    published = {**manifest, "export": "JPEG quality 90, 4:4:4; no crop, redraw, or composited device chrome",
                 "captures": output_items}
    (destination / "manifest.json").write_text(json.dumps(published, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(output_items)} screenshots; {sum(i['bytes'] for i in output_items):,} bytes.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Raw PNG capture directory with manifest.json")
    parser.add_argument("--output", type=Path, default=Path("docs/screenshots"))
    args = parser.parse_args()
    export(args.input, args.output)


if __name__ == "__main__":
    main()
