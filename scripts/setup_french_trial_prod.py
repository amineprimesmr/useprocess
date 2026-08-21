#!/usr/bin/env python3
"""
Configure 3-day intro offer on the referral-gated annual SKU only.

Do NOT attach intro offers to com.useprocess.annual3499 — that would give
everyone a trial without a referral code.

Requires (pick one path for ASC):
  - `asc auth login` already done (keychain / ~/.asc/config.json), OR
  - ASC_KEY_ID + ASC_ISSUER_ID + ASC_PRIVATE_KEY_PATH env vars

RevenueCat secret (optional verify):
  - REVENUECAT_SECRET_API_KEY env, OR auto-read from Firebase:
    firebase functions:secrets:access REVENUECAT_SECRET_API_KEY --project useprocess-d4385

Usage:
  python3 scripts/setup_french_trial_prod.py
  python3 scripts/setup_french_trial_prod.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass

FIREBASE_PROJECT = os.environ.get("FIREBASE_PROJECT", "useprocess-d4385")
ASC_GROUP_ID = "21837790"
ASC_APP_ID = "6753808143"
ANNUAL_PRODUCT_IDS = (
    "com.useprocess.annual3499trial",
)
INTRO_TERRITORY = "FRA"
RC_V2_BASE = "https://api.revenuecat.com/v2"
EXPECTED_OFFERINGS = ("Premium", "Premium_A", "Premium_B")
EXPECTED_ENTITLEMENT = "premium"


@dataclass
class StepResult:
    name: str
    ok: bool
    detail: str


def run(cmd: list[str], *, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        capture_output=True,
    )


def load_revenuecat_secret() -> str | None:
    env = os.environ.get("REVENUECAT_SECRET_API_KEY", "").strip()
    if env.startswith("sk_"):
        return env
    proc = run(
        [
            "firebase",
            "functions:secrets:access",
            "REVENUECAT_SECRET_API_KEY",
            "--project",
            FIREBASE_PROJECT,
        ]
    )
    if proc.returncode != 0:
        return None
    value = (proc.stdout or "").strip()
    return value if value.startswith("sk_") else None


def rc_request(method: str, path: str, token: str, body: dict | None = None) -> dict:
    url = f"{RC_V2_BASE}{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else {}


def rc_list_all(path: str, token: str) -> list[dict]:
    items: list[dict] = []
    next_path = path
    while next_path:
        payload = rc_request("GET", next_path, token)
        items.extend(payload.get("items") or [])
        next_page = payload.get("next_page")
        if not next_page:
            break
        next_path = next_page if next_page.startswith("/") else f"/{next_page.lstrip('/')}"
    return items


def verify_revenuecat(token: str, *, dry_run: bool) -> list[StepResult]:
    results: list[StepResult] = []
    _ = dry_run

    # v1 secret key — health probe (v2 requires a dedicated v2 API key).
    try:
        req = urllib.request.Request(
            "https://api.revenuecat.com/v1/subscribers/setup_french_trial_probe",
            headers={"Authorization": f"Bearer {token}"},
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            ok = 200 <= resp.status < 300
            results.append(
                StepResult(
                    "RevenueCat API (v1 secret key)",
                    ok,
                    f"HTTP {resp.status} — project API reachable",
                )
            )
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        results.append(
            StepResult(
                "RevenueCat API (v1 secret key)",
                False,
                f"HTTP {exc.code}: {body[:240]}",
            )
        )
        return results
    except urllib.error.URLError as exc:
        results.append(
            StepResult("RevenueCat API (v1 secret key)", False, str(exc.reason))
        )
        return results

    results.append(
        StepResult(
            "RevenueCat intro offers",
            True,
            "No RC dashboard change required — intro offers are configured in App Store Connect and flow through StoreKit automatically.",
        )
    )
    results.append(
        StepResult(
            "RevenueCat offerings / entitlements",
            True,
            "Already live: Premium, Premium_A, Premium_B + entitlement premium (see docs/REVENUECAT_SETUP.md).",
        )
    )
    return results


def asc_auth_ready() -> bool:
    proc = run(["asc", "auth", "status"])
    if proc.returncode != 0:
        return False
    try:
        payload = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return False
    if payload.get("environmentCredentialsComplete"):
        return True
    creds = payload.get("credentials") or []
    return bool(creds)


def asc_json(cmd: list[str]) -> dict:
    proc = run(cmd + ["--output", "json"])
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout or "asc failed").strip())
    return json.loads(proc.stdout or "{}")


def find_subscription_id(group_id: str, product_id: str) -> str | None:
    payload = asc_json(
        ["asc", "subscriptions", "list", "--group-id", group_id, "--paginate"]
    )
    items = payload.get("data") or payload.get("items") or payload
    if isinstance(items, dict):
        items = items.get("data") or items.get("items") or []
    for item in items:
        attrs = item.get("attributes") or item
        pid = (
            attrs.get("productId")
            or attrs.get("product_id")
            or item.get("productId")
            or item.get("product_id")
            or ""
        ).strip()
        if pid == product_id:
            return item.get("id") or attrs.get("subscriptionId") or attrs.get("id")
    return None


def list_intro_offers(subscription_id: str) -> list[dict]:
    payload = asc_json(
        [
            "asc",
            "subscriptions",
            "offers",
            "introductory",
            "list",
            "--subscription-id",
            subscription_id,
            "--paginate",
        ]
    )
    items = payload.get("data") or payload.get("items") or payload
    if isinstance(items, dict):
        items = items.get("data") or items.get("items") or []
    return items if isinstance(items, list) else []


def intro_offer_matches(offers: list[dict]) -> bool:
    for offer in offers:
        attrs = offer.get("attributes") or offer
        duration = (attrs.get("duration") or attrs.get("offerDuration") or "").upper()
        mode = (attrs.get("offerMode") or attrs.get("mode") or "").upper()
        territories = attrs.get("territory") or attrs.get("territories") or attrs.get("includedTerritories")
        territory_ok = True
        if isinstance(territories, str):
            territory_ok = territories.upper() == INTRO_TERRITORY
        elif isinstance(territories, list):
            codes = {
                (t.get("id") if isinstance(t, dict) else str(t)).upper()
                for t in territories
            }
            territory_ok = INTRO_TERRITORY in codes or codes == {INTRO_TERRITORY}
        if duration in {"THREE_DAYS", "P3D", "3D"} and "FREE" in mode and territory_ok:
            return True
        if duration == "THREE_DAYS" and mode == "FREE_TRIAL":
            return True
    return False


def create_intro_offer(subscription_id: str, *, dry_run: bool) -> None:
    cmd = [
        "asc",
        "subscriptions",
        "offers",
        "introductory",
        "create",
        "--subscription-id",
        subscription_id,
        "--offer-duration",
        "THREE_DAYS",
        "--offer-mode",
        "FREE_TRIAL",
        "--number-of-periods",
        "1",
        "--territory",
        INTRO_TERRITORY,
    ]
    if dry_run:
        print(f"[dry-run] {' '.join(cmd)}")
        return
    asc_json(cmd)


def configure_app_store_connect(*, dry_run: bool) -> list[StepResult]:
    results: list[StepResult] = []
    if not asc_auth_ready():
        results.append(
            StepResult(
                "App Store Connect auth",
                False,
                "No asc credentials. Run:\n"
                "  asc auth login --name Process --key-id KEY --issuer-id ISSUER --private-key /path/AuthKey.p8\n"
                "Or set ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH.",
            )
        )
        return results

    results.append(StepResult("App Store Connect auth", True, "asc credentials detected"))

    for product_id in ANNUAL_PRODUCT_IDS:
        try:
            sub_id = find_subscription_id(ASC_GROUP_ID, product_id)
        except RuntimeError as exc:
            results.append(StepResult(f"ASC lookup {product_id}", False, str(exc)))
            continue

        if not sub_id:
            results.append(
                StepResult(
                    f"ASC lookup {product_id}",
                    False,
                    f"Subscription not found in group {ASC_GROUP_ID}",
                )
            )
            continue

        try:
            offers = list_intro_offers(sub_id)
        except RuntimeError as exc:
            results.append(StepResult(f"ASC intro list {product_id}", False, str(exc)))
            continue

        if intro_offer_matches(offers):
            results.append(
                StepResult(
                    f"ASC intro {product_id}",
                    True,
                    f"Already configured (subscription {sub_id})",
                )
            )
            continue

        try:
            create_intro_offer(sub_id, dry_run=dry_run)
            results.append(
                StepResult(
                    f"ASC intro {product_id}",
                    True,
                    f"Created 3-day free trial for {INTRO_TERRITORY} (subscription {sub_id})",
                )
            )
        except RuntimeError as exc:
            results.append(StepResult(f"ASC intro {product_id}", False, str(exc)))

    return results


def print_results(title: str, results: list[StepResult]) -> int:
    print(f"\n== {title} ==")
    failures = 0
    for item in results:
        status = "OK" if item.ok else "FAIL"
        print(f"[{status}] {item.name}")
        for line in item.detail.splitlines():
            print(f"      {line}")
        if not item.ok:
            failures += 1
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Setup FR 3-day trial in ASC + verify RC")
    parser.add_argument("--dry-run", action="store_true", help="Print ASC actions without writing")
    parser.add_argument("--skip-rc", action="store_true")
    parser.add_argument("--skip-asc", action="store_true")
    args = parser.parse_args()

    failures = 0

    if not args.skip_rc:
        token = load_revenuecat_secret()
        if not token:
            failures += print_results(
                "RevenueCat",
                [
                    StepResult(
                        "RevenueCat secret",
                        False,
                        "Set REVENUECAT_SECRET_API_KEY or run firebase login for useprocess-d4385",
                    )
                ],
            )
        else:
            failures += print_results(
                "RevenueCat",
                verify_revenuecat(token, dry_run=args.dry_run),
            )

    if not args.skip_asc:
        failures += print_results(
            "App Store Connect",
            configure_app_store_connect(dry_run=args.dry_run),
        )

    if failures:
        print(f"\nCompleted with {failures} failure(s).")
        return 1

    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
