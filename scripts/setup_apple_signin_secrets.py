#!/usr/bin/env python3
"""Configure Firebase secrets for Sign in with Apple token revocation."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

FIREBASE_PROJECT = "useprocess-d4385"
DEFAULT_TEAM_ID = "F2CJGJ69XU"
DEFAULT_KEY_ID = "4R9S5HF8VU"
DEFAULT_P8 = Path.home() / "Downloads" / "AuthKey_4R9S5HF8VU.p8"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True)


def set_secret(name: str, value: str, project: str) -> None:
    proc = subprocess.run(
        ["firebase", "functions:secrets:set", name, "--project", project, "--force"],
        input=value,
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Failed to set {name}: {proc.stderr or proc.stdout}")
    print(f"✓ {name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=FIREBASE_PROJECT)
    parser.add_argument("--team-id", default=DEFAULT_TEAM_ID)
    parser.add_argument("--key-id", default=DEFAULT_KEY_ID)
    parser.add_argument("--private-key-path", type=Path, default=DEFAULT_P8)
    args = parser.parse_args()

    p8_path = args.private_key_path.expanduser()
    if not p8_path.is_file():
        print(f"Missing private key: {p8_path}", file=sys.stderr)
        return 1

    private_key = p8_path.read_text(encoding="utf-8").strip()
    if "BEGIN PRIVATE KEY" not in private_key:
        print("Invalid .p8 file", file=sys.stderr)
        return 1

    print(f"Setting Apple Sign In secrets on {args.project}…")
    set_secret("APPLE_SIGNIN_TEAM_ID", args.team_id, args.project)
    set_secret("APPLE_SIGNIN_KEY_ID", args.key_id, args.project)
    set_secret("APPLE_SIGNIN_PRIVATE_KEY", private_key, args.project)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
