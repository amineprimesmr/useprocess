#!/usr/bin/env python3
"""Fetch Pinterest images into content/tiktok/raw/{folder}/.

Usage:
  python3 fetch_pinterest.py                  # all sources in pinterest_sources.yaml
  python3 fetch_pinterest.py --only meals     # only sources targeting folder 'meals'
  python3 fetch_pinterest.py --query "protein bowl" --folder meals --limit 20
  python3 fetch_pinterest.py --board "https://www.pinterest.com/user/board/" --folder misc

Requires: gallery-dl (pip install gallery-dl)
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw"
CONFIG = ROOT / "pinterest_sources.yaml"
GALLERY_DL = Path.home() / "Library/Python/3.9/bin/gallery-dl"

VALID_FOLDERS = {
    "before-after",
    "faces",
    "meals",
    "lifestyle",
    "screenshots-app",
    "proofs",
    "misc",
    "imran-normal",
    "imran-prime",
}


def find_gallery_dl() -> str:
    if GALLERY_DL.exists():
        return str(GALLERY_DL)
    which = shutil.which("gallery-dl")
    if which:
        return which
    # fallback module
    return f"{sys.executable} -m gallery_dl"


def slug(text: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", text.lower()).strip("-")
    return s[:60] or "pin"


def load_sources() -> list[dict]:
    if not CONFIG.exists():
        return []
    text = CONFIG.read_text(encoding="utf-8")
    if yaml is not None:
        data = yaml.safe_load(text) or {}
        return list(data.get("sources") or [])
    # minimal YAML-ish fallback (no PyYAML): only support simple keys we use
    raise SystemExit("Installe PyYAML: pip3 install --user pyyaml")


def run_gallery_dl(url: str, dest: Path, limit: int) -> int:
    dest.mkdir(parents=True, exist_ok=True)
    gdl = find_gallery_dl()
    cmd = gdl.split() if gdl.startswith(sys.executable) else [gdl]
    cmd += [
        "--dest",
        str(dest),
        "--filename",
        "{category}_{id}.{extension}",
        "--range",
        f"1-{limit}",
        "--no-mtime",
        url,
    ]
    print("→", " ".join(cmd))
    proc = subprocess.run(cmd, cwd=str(dest))
    return proc.returncode


def flatten_downloads(dest: Path, prefix: str) -> int:
    """gallery-dl nests folders; flatten images into dest with prefix."""
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    moved = 0
    for p in list(dest.rglob("*")):
        if not p.is_file() or p.suffix.lower() not in exts:
            continue
        if p.parent == dest and p.name.startswith(prefix):
            continue
        target = dest / f"{prefix}_{p.stem}{p.suffix.lower()}"
        n = 1
        while target.exists():
            target = dest / f"{prefix}_{p.stem}_{n}{p.suffix.lower()}"
            n += 1
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(p), str(target))
        moved += 1
    # cleanup empty dirs left by gallery-dl
    for d in sorted(dest.rglob("*"), reverse=True):
        if d.is_dir():
            try:
                d.rmdir()
            except OSError:
                pass
    return moved


def fetch_query(query: str, folder: str, limit: int, name: str | None = None) -> None:
    if folder not in VALID_FOLDERS:
        raise SystemExit(f"Dossier invalide: {folder}. Choisis parmi {sorted(VALID_FOLDERS)}")
    dest = RAW / folder
    url = f"https://www.pinterest.com/search/pins/?q={query.replace(' ', '%20')}"
    prefix = slug(name or query)
    code = run_gallery_dl(url, dest, limit)
    n = flatten_downloads(dest, prefix)
    print(f"✓ {folder}/ ← {n} images (query: {query}) [exit={code}]")


def fetch_board(board_url: str, folder: str, limit: int, name: str | None = None) -> None:
    if folder not in VALID_FOLDERS:
        raise SystemExit(f"Dossier invalide: {folder}")
    dest = RAW / folder
    prefix = slug(name or "board")
    code = run_gallery_dl(board_url, dest, limit)
    n = flatten_downloads(dest, prefix)
    print(f"✓ {folder}/ ← {n} images (board) [exit={code}]")


def main() -> None:
    ap = argparse.ArgumentParser(description="Fetch Pinterest images into raw/ folders")
    ap.add_argument("--only", help="Ne traiter que les sources dont folder == cette valeur")
    ap.add_argument("--query", help="Recherche one-shot")
    ap.add_argument("--board", help="URL board Pinterest one-shot")
    ap.add_argument("--folder", default="misc", help="Dossier cible pour --query/--board")
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.query:
        if args.dry_run:
            print(f"[dry] query={args.query} → raw/{args.folder}/ limit={args.limit}")
            return
        fetch_query(args.query, args.folder, args.limit)
        return

    if args.board:
        if args.dry_run:
            print(f"[dry] board={args.board} → raw/{args.folder}/ limit={args.limit}")
            return
        fetch_board(args.board, args.folder, args.limit)
        return

    sources = load_sources()
    if not sources:
        raise SystemExit(f"Aucune source dans {CONFIG}")

    for src in sources:
        folder = src.get("folder", "misc")
        if args.only and folder != args.only:
            continue
        limit = int(src.get("limit") or args.limit)
        name = src.get("name")
        if args.dry_run:
            print(f"[dry] {name}: {src.get('query') or src.get('board')} → raw/{folder}/ ({limit})")
            continue
        if src.get("board"):
            fetch_board(src["board"], folder, limit, name=name)
        elif src.get("query"):
            fetch_query(src["query"], folder, limit, name=name)
        else:
            print(f"skip {name}: pas de query/board")


if __name__ == "__main__":
    main()
