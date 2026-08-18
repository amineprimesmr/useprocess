#!/usr/bin/env python3
"""Audit localization coverage vs Shared/copy-*.json catalogs."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGS = ["ja", "de", "ko", "es", "pt-BR"]
CALL = re.compile(
    r'(?:AppCopy|OnboardingCopy|ProcessSharedLanguage)\.(?:t|tSync)\(\s*"((?:\\.|[^"\\])*)"\s*,\s*en:\s*"((?:\\.|[^"\\])*)"',
)
JS_CALL = re.compile(
    r"""appCopy\(\s*(['"])((?:\\.|[^\\])*?)\1\s*,\s*(['"])((?:\\.|[^\\])*?)\3""",
    re.DOTALL,
)
INTERP = re.compile(r"\\\([^)]*\)")
MAP_PAIR = re.compile(r'"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"')
MAP_FILES = [
    ROOT / "useprocess/WelcomePlan/ProcessLocalizedMealContentCatalog.swift",
    ROOT / "useprocess/WelcomePlan/ProcessLocalizedMealNames.swift",
    ROOT / "useprocess/WelcomePlan/ProcessLocalizedBreakfastBuilderContent.swift",
    ROOT / "useprocess/WelcomePlan/Food/ProcessLocalizedDebloatFoodContent.swift",
    ROOT / "useprocess/Sport/Onboarding/ProfileChat/OnboardingSportCatalog.swift",
]


def unescape_swift(s: str) -> str:
    return s.replace(r"\"", '"').replace(r"\n", "\n").replace(r"\t", "\t")


def load_cats() -> dict:
    return {
        lang: json.loads((ROOT / "Shared" / f"copy-{lang}.json").read_text(encoding="utf-8"))
        for lang in LANGS
    }


def collect_swift():
    static, interp = set(), set()
    files = (
        list((ROOT / "useprocess").rglob("*.swift"))
        + list((ROOT / "Shared").rglob("*.swift"))
        + list((ROOT / "ProcessWidgets").rglob("*.swift"))
    )
    n = 0
    for path in files:
        text = path.read_text(encoding="utf-8")
        for m in CALL.finditer(text):
            n += 1
            en = unescape_swift(m.group(2))
            if INTERP.search(m.group(1)) or INTERP.search(m.group(2)):
                interp.add(m.group(2))
            else:
                static.add(en)
    return n, static, interp


def collect_js():
    ens = set()
    for path in list((ROOT / "website").rglob("*.js")) + list((ROOT / "website").rglob("*.jsx")):
        if "node_modules" in path.parts or "i18n" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for m in JS_CALL.finditer(text):
            ens.add(m.group(4))
    return ens


def to_regex(en_raw: str) -> str:
    pieces = INTERP.split(en_raw)
    escaped = [re.escape(p) for p in pieces]
    return "^" + "(.+?)".join(escaped) + "$"


def main() -> int:
    cats = load_cats()
    n_calls, static, interp = collect_swift()
    js_en = collect_js()
    ja = cats["ja"]
    miss_static = [e for e in sorted(static) if e not in ja["exact"]]
    miss_interp = [raw for raw in sorted(interp) if not any(t["re"] == to_regex(raw) for t in ja["templates"])]
    miss_js = [e for e in sorted(js_en) if "${" not in e and e not in ja["exact"]]

    print(f"swift_calls={n_calls} unique_static={len(static)} unique_interp={len(interp)}")
    print(f"catalog exact={len(ja['exact'])} templates={len(ja['templates'])}")
    print(f"missing_static={len(miss_static)} missing_interp_templates={len(miss_interp)}")
    print(f"website unique_en={len(js_en)} missing={len(miss_js)}")
    for lang in LANGS[1:]:
        a, b = set(ja["exact"]), set(cats[lang]["exact"])
        print(f"parity ja vs {lang}: missing={len(a - b)} extra={len(b - a)}")
        if len(ja["templates"]) != len(cats[lang]["templates"]):
            print(f"  template count mismatch {len(ja['templates'])} vs {len(cats[lang]['templates'])}")

    failed = bool(miss_static or miss_interp or miss_js)
    if miss_static:
        print("MISSING STATIC:")
        for e in miss_static[:30]:
            print(f"  {e!r}")
    if miss_interp:
        print("MISSING INTERP:")
        for e in miss_interp[:20]:
            print(f"  {e!r}")
    if miss_js:
        print("MISSING JS:")
        for e in miss_js[:20]:
            print(f"  {e!r}")
    print("PASS" if not failed else "FAIL")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
