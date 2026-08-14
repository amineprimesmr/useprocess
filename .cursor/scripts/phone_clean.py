#!/usr/bin/env python3
"""Strip AI provenance metadata from images (C2PA, IPTC, XMP, EXIF, PNG tEXt).

Local replacement for: Gemini Omni → Discord → phone screenshot.

TikTok / Instagram / LinkedIn auto-labels mostly read file metadata at upload
(C2PA Content Credentials, IPTC digitalSourceType). Those live in the container,
not in the pixels. This script removes them losslessly.

It does not claim to erase Google SynthID (a pixel watermark). That is a
different layer from the metadata TikTok documents as its upload auto-label.

Usage:
  python3 phone_clean.py FILE.png
  python3 phone_clean.py DIR --recursive
  python3 phone_clean.py DIR --check
"""
from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

PNG_SIG = b"\x89PNG\r\n\x1a\n"
JPEG_SIG = b"\xff\xd8"

# Pixel / color chunks only. Everything else (caBX C2PA, tEXt, eXIf, iTXt…) drops.
PNG_KEEP = {
    b"IHDR",
    b"PLTE",
    b"IDAT",
    b"IEND",
    b"tRNS",
    b"gAMA",
    b"cHRM",
    b"sRGB",
    b"iCCP",
    b"cICP",
    b"sBIT",
    b"bKGD",
    b"pHYs",
}

AI_MARKERS = (
    b"c2pa",
    b"C2PA",
    b"caBX",
    b"jumb",
    b"JUMBF",
    b"trainedAlgorithmic",
    b"digitalSourceType",
    b"hf-job-id",
    b"gpt-image",
    b"OpenAI Media",
    b"Content Credentials",
    b"SynthID",
)

IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}


def markers_in(data: bytes) -> list[str]:
    hits = []
    for m in AI_MARKERS:
        if m in data:
            hits.append(m.decode("latin1"))
    return hits


def strip_png(data: bytes) -> tuple[bytes, list[str]]:
    if data[:8] != PNG_SIG:
        raise ValueError("not a PNG")
    out = bytearray(PNG_SIG)
    dropped: list[str] = []
    i = 8
    saw_iend = False
    while i + 12 <= len(data):
        length = struct.unpack(">I", data[i : i + 4])[0]
        ctype = data[i + 4 : i + 8]
        end = i + 12 + length
        if end > len(data):
            raise ValueError("truncated PNG chunk")
        chunk = data[i:end]
        i = end
        if ctype in PNG_KEEP:
            out.extend(chunk)
        else:
            dropped.append(ctype.decode("latin1", "replace"))
        if ctype == b"IEND":
            saw_iend = True
            break
    if not saw_iend:
        raise ValueError("PNG missing IEND")
    return bytes(out), dropped


def strip_jpeg(data: bytes) -> tuple[bytes, list[str]]:
    if data[:2] != JPEG_SIG:
        raise ValueError("not a JPEG")
    out = bytearray(JPEG_SIG)
    dropped: list[str] = []
    i = 2
    n = len(data)
    while i < n:
        if data[i] != 0xFF:
            out.extend(data[i:])
            break
        while i < n and data[i] == 0xFF:
            i += 1
        if i >= n:
            break
        marker = data[i]
        i += 1
        if marker == 0xD9:  # EOI
            out.extend(b"\xff\xd9")
            break
        if marker == 0xDA:  # SOS — remainder is entropy-coded image
            out.extend(b"\xff\xda")
            out.extend(data[i:])
            break
        if marker in (0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7):
            out.extend(bytes((0xFF, marker)))
            continue
        if i + 2 > n:
            raise ValueError("truncated JPEG marker")
        length = struct.unpack(">H", data[i : i + 2])[0]
        if length < 2 or i + length > n:
            raise ValueError("bad JPEG marker length")
        payload = data[i : i + length]
        i += length
        # Drop APP0–APP15 (EXIF/XMP/IPTC/ICC/C2PA JUMBF) and COM
        if 0xE0 <= marker <= 0xEF or marker == 0xFE:
            dropped.append(f"APP{marker - 0xE0}" if marker <= 0xEF else "COM")
            continue
        out.extend(bytes((0xFF, marker)))
        out.extend(payload)
    return bytes(out), dropped


def ffmpeg_rebuild(src: Path, dst: Path) -> None:
    ext = src.suffix.lower()
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-map_metadata", "-1"]
    if ext in {".jpg", ".jpeg"}:
        cmd += ["-q:v", "2", str(dst)]
    elif ext == ".webp":
        cmd += ["-c:v", "libwebp", "-lossless", "1", str(dst)]
    else:
        cmd += ["-c:v", "png", "-compression_level", "4", str(dst)]
    subprocess.run(cmd, check=True)


def process_file(path: Path, *, check_only: bool = False) -> dict:
    raw = path.read_bytes()
    if len(raw) > 2_000_000:
        before = markers_in(raw[:131072]) + markers_in(raw[-65536:])
        before = list(dict.fromkeys(before))
    else:
        before = markers_in(raw)

    ext = path.suffix.lower()
    result = {
        "path": str(path),
        "before": before,
        "dropped": [],
        "changed": False,
        "method": "none",
        "after": [],
    }

    if check_only:
        return result

    tmp_fd, tmp_name = tempfile.mkstemp(suffix=ext or ".img", dir=str(path.parent))
    os.close(tmp_fd)
    tmp = Path(tmp_name)
    try:
        if ext == ".png" and raw[:8] == PNG_SIG:
            cleaned, dropped = strip_png(raw)
            tmp.write_bytes(cleaned)
            result["dropped"] = dropped
            result["method"] = "png-chunks"
        elif ext in {".jpg", ".jpeg"} and raw[:2] == JPEG_SIG:
            cleaned, dropped = strip_jpeg(raw)
            tmp.write_bytes(cleaned)
            result["dropped"] = dropped
            result["method"] = "jpeg-app"
        else:
            ffmpeg_rebuild(path, tmp)
            result["method"] = "ffmpeg"
            result["dropped"] = ["container-rebuild"]

        new = tmp.read_bytes()
        after_head = markers_in(new[:131072])
        if after_head:
            ffmpeg_rebuild(tmp, tmp)
            new = tmp.read_bytes()
            result["method"] += "+ffmpeg"
            after_head = markers_in(new[:131072])

        if new != raw:
            os.replace(tmp, path)
            result["changed"] = True
        else:
            tmp.unlink(missing_ok=True)
        result["after"] = after_head
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    return result


def iter_images(target: Path, *, recursive: bool) -> list[Path]:
    if target.is_file():
        return [target]
    globber = target.rglob if recursive else target.glob
    out = []
    for p in globber("*"):
        if p.is_file() and p.suffix.lower() in IMAGE_EXT and p.name != ".DS_Store":
            out.append(p)
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="Strip AI provenance metadata from images")
    ap.add_argument("paths", nargs="+", type=Path)
    ap.add_argument("--recursive", "-r", action="store_true")
    ap.add_argument("--check", action="store_true", help="report only, do not write")
    args = ap.parse_args()

    files: list[Path] = []
    for p in args.paths:
        if not p.exists():
            print(f"missing: {p}", file=sys.stderr)
            return 1
        files.extend(iter_images(p, recursive=args.recursive or p.is_file()))

    scanned = dirty = changed = leftover = 0
    for f in files:
        scanned += 1
        info = process_file(f, check_only=args.check)
        if info["before"]:
            dirty += 1
            flag = "CHECK" if args.check else ("CLEANED" if info.get("changed") else "SKIP")
            print(f"{flag}  {f.name}  markers={info['before']}  drop={info.get('dropped')}")
        if info.get("changed"):
            changed += 1
        if info.get("after"):
            leftover += 1
            print(f"LEFTOVER  {f}  {info['after']}", file=sys.stderr)

    print(
        f"\nscanned={scanned}  had_ai_meta={dirty}  "
        f"rewritten={changed}  leftover={leftover}  check={args.check}"
    )
    return 1 if leftover else 0


if __name__ == "__main__":
    raise SystemExit(main())
