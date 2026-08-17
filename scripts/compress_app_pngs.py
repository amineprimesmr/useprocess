#!/usr/bin/env python3
"""Resize + recompress PNG assets in useprocess/Assets.xcassets."""

from __future__ import annotations

import json
import shutil
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "useprocess" / "Assets.xcassets"
BACKUP = ROOT / "content" / "app-media" / "source" / "Assets.xcassets"


def max_edge_for(path: Path) -> int:
    parts = set(path.parts)
    rel = path.relative_to(ASSETS).as_posix().lower()

    if "appicon.appiconset" in rel:
        return 1024
    if "/meals/" in rel or "/breakfast/" in rel:
        return 512
    if "/cardio/" in rel or "/posture/" in rel:
        return 640
    if "session_cardio" in rel:
        return 640
    if "/routines/" in rel or "training_see_all" in rel:
        return 720
    if "/brand/" in rel:
        return 640
    if "/ui/" in rel or "/notif" in rel:
        return 800
    if "/onboarding/" in rel:
        return 640
    if "/hydration/" in rel or "/reward/" in rel:
        return 512
    return 768


def png_dims(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as handle:
        if handle.read(8)[:4] != b"\x89PNG":
            return None
        handle.read(4)
        if handle.read(4) != b"IHDR":
            return None
        w, h = struct.unpack(">II", handle.read(8))
        return w, h


def resize_png(path: Path, max_edge: int) -> tuple[int, int]:
    before = path.stat().st_size
    dims = png_dims(path)
    if dims is None:
        return before, before

    width, height = dims
    longest = max(width, height)
    if longest <= max_edge and before <= 350_000:
        return before, before

    backup_path = BACKUP / path.relative_to(ASSETS)
    if not backup_path.exists():
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup_path)

    with Image.open(path) as image:
        image = image.convert("RGBA")
        if longest > max_edge:
            image.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)
        image.save(path, format="PNG", optimize=True, compress_level=9)

    after = path.stat().st_size
    return before, after


def main() -> int:
    if not ASSETS.is_dir():
        print(f"Missing assets catalog: {ASSETS}", file=sys.stderr)
        return 1

    total_before = 0
    total_after = 0
    touched = 0

    for png in sorted(ASSETS.rglob("*.png")):
        before, after = resize_png(png, max_edge_for(png))
        total_before += before
        total_after += after
        if after < before:
            touched += 1
            rel = png.relative_to(ASSETS)
            print(f"  {before / 1024:6.0f} KB -> {after / 1024:6.0f} KB  {rel}")

    print()
    print(f"PNG files touched: {touched}")
    print(f"Total: {total_before / 1024 / 1024:.1f} MB -> {total_after / 1024 / 1024:.1f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
