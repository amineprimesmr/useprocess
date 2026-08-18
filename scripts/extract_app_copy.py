#!/usr/bin/env python3
"""Extract AppCopy / OnboardingCopy / ProcessSharedLanguage / appCopy string pairs."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SWIFT_CALL = re.compile(
    r"""(?:AppCopy|OnboardingCopy|ProcessSharedLanguage)\.(?:t|tSync)\(\s*"((?:\\.|[^"\\])*)"\s*,\s*en:\s*"((?:\\.|[^"\\])*)"\s*""",
    re.MULTILINE,
)
# Multiline / concatenated Swift strings are rare; also catch t("fr", en: "en")
SWIFT_CALL_NL = re.compile(
    r"""(?:AppCopy|OnboardingCopy|ProcessSharedLanguage)\.(?:t|tSync)\(\s*"((?:\\.|[^"\\])*)"\s*,\s*en:\s*"((?:\\.|[^"\\])*)"\s*\)""",
    re.MULTILINE,
)

JS_CALL = re.compile(
    r"""appCopy\(\s*(['"])((?:\\.|[^\\])*?)\1\s*,\s*(['"])((?:\\.|[^\\])*?)\3""",
    re.MULTILINE | re.DOTALL,
)

INTERP = re.compile(r"\\\([^)]*\)")


def unescape_swift(s: str) -> str:
    return (
        s.replace(r"\\", "\\")
        .replace(r"\"", '"')
        .replace(r"\n", "\n")
        .replace(r"\t", "\t")
    )


def unescape_js(s: str) -> str:
    return bytes(s, "utf-8").decode("unicode_escape") if "\\" in s else s


def collect_swift() -> list[dict]:
    rows = []
    for path in list((ROOT / "useprocess").rglob("*.swift")) + list((ROOT / "Shared").rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for m in SWIFT_CALL.finditer(text):
            fr, en = unescape_swift(m.group(1)), unescape_swift(m.group(2))
            rows.append(
                {
                    "fr": fr,
                    "en": en,
                    "file": str(path.relative_to(ROOT)),
                    "interpolated": bool(INTERP.search(m.group(1)) or INTERP.search(m.group(2))),
                    "en_raw": m.group(2),
                    "fr_raw": m.group(1),
                }
            )
    return rows


def collect_js() -> list[dict]:
    rows = []
    website = ROOT / "website"
    for path in list(website.rglob("*.js")) + list(website.rglob("*.jsx")):
        if "node_modules" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for m in JS_CALL.finditer(text):
            fr, en = m.group(2), m.group(4)
            rows.append(
                {
                    "fr": fr,
                    "en": en,
                    "file": str(path.relative_to(ROOT)),
                    "interpolated": "${" in fr or "${" in en or "\\\(" in fr,
                    "en_raw": en,
                    "fr_raw": fr,
                }
            )
    return rows


def unique_by_en(rows: list[dict]) -> dict[str, dict]:
    uniq: dict[str, dict] = {}
    for row in rows:
        key = row["en"]
        if key not in uniq:
            uniq[key] = row
    return uniq


def main() -> None:
    swift = collect_swift()
    js = collect_js()
    all_rows = swift + js
    uniq = unique_by_en(all_rows)
    static = {k: v for k, v in uniq.items() if not v["interpolated"]}
    interp = {k: v for k, v in uniq.items() if v["interpolated"]}
    out = ROOT / "scripts" / "_extracted_copy.json"
    out.write_text(
        json.dumps(
            {
                "swift_calls": len(swift),
                "js_calls": len(js),
                "unique_en": len(uniq),
                "unique_static": len(static),
                "unique_interpolated": len(interp),
                "static": [
                    {"en": v["en"], "fr": v["fr"]}
                    for v in sorted(static.values(), key=lambda r: r["en"].lower())
                ],
                "interpolated": [
                    {"en": v["en"], "fr": v["fr"], "en_raw": v["en_raw"], "fr_raw": v["fr_raw"]}
                    for v in sorted(interp.values(), key=lambda r: r["en_raw"].lower())
                ],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"swift_calls={len(swift)} js_calls={len(js)}")
    print(f"unique_en={len(uniq)} static={len(static)} interpolated={len(interp)}")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
