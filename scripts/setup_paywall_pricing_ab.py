#!/usr/bin/env python3
"""
Setup A/B paywall pricing dashboards.

Requires env vars (do NOT commit secrets):
  POSTHOG_PERSONAL_API_KEY  — phx_… with feature_flag:write + experiment:write
  REVENUECAT_SECRET_API_KEY — sk_… (optional, for offerings)
  ASC_*                     — not automated here (create SKUs in App Store Connect)

Usage:
  export POSTHOG_PERSONAL_API_KEY='phx_…'
  python3 scripts/setup_paywall_pricing_ab.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

POSTHOG_HOST = os.environ.get("POSTHOG_HOST", "https://eu.posthog.com")
PROJECT_ID = os.environ.get("POSTHOG_PROJECT_ID", "240558")
FLAG_KEY = "paywall-pricing-ab"


def request(method: str, path: str, token: str, body: dict | None = None) -> dict:
    url = f"{POSTHOG_HOST}/api/projects/{PROJECT_ID}{path}"
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
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        raise SystemExit(f"{method} {path} -> HTTP {e.code}\n{detail}") from e


def ensure_flag(token: str) -> dict:
    listing = request("GET", f"/feature_flags/?search={FLAG_KEY}", token)
    for flag in listing.get("results") or []:
        if flag.get("key") == FLAG_KEY:
            print(f"Flag exists id={flag['id']}")
            return flag

    payload = {
        "key": FLAG_KEY,
        "name": "Paywall pricing A/B",
        "active": True,
        "filters": {
            "groups": [{"properties": [], "rollout_percentage": 100}],
            "multivariate": {
                "variants": [
                    {
                        "key": "control",
                        "name": "A weekly 8.99 + annual 34.99",
                        "rollout_percentage": 50,
                    },
                    {
                        "key": "test",
                        "name": "B monthly 9.99 + annual 49.99",
                        "rollout_percentage": 50,
                    },
                ]
            },
        },
    }
    created = request("POST", "/feature_flags/", token, payload)
    print(f"Created flag id={created.get('id')} key={created.get('key')}")
    return created


def ensure_experiment(token: str, flag: dict) -> dict:
    listing = request("GET", "/experiments/?limit=50", token)
    for exp in listing.get("results") or []:
        if exp.get("feature_flag_key") == FLAG_KEY or exp.get("name") == "Paywall pricing A/B":
            print(f"Experiment exists id={exp['id']} start={exp.get('start_date')}")
            return exp

    # Create experiment linked to the multivariate flag.
    payload = {
        "name": "Paywall pricing A/B",
        "description": "A: 8.99€/week + 34.99€/year vs B: 9.99€/month + 49.99€/year",
        "feature_flag_key": FLAG_KEY,
        "parameters": {
            "feature_flag_variants": [
                {
                    "key": "control",
                    "name": "A weekly 8.99 + annual 34.99",
                    "rollout_percentage": 50,
                },
                {
                    "key": "test",
                    "name": "B monthly 9.99 + annual 49.99",
                    "rollout_percentage": 50,
                },
            ]
        },
        "metrics": [
            {
                "kind": "ExperimentMetric",
                "metric_type": "mean",
                "name": "purchase_completed",
                "source": {
                    "kind": "EventsNode",
                    "event": "purchase_completed",
                    "math": "total",
                },
            }
        ],
        "secondary_metrics": [
            {
                "kind": "ExperimentMetric",
                "metric_type": "mean",
                "name": "paywall_viewed",
                "source": {
                    "kind": "EventsNode",
                    "event": "paywall_viewed",
                    "math": "total",
                },
            },
            {
                "kind": "ExperimentMetric",
                "metric_type": "mean",
                "name": "paywall_cta_tapped",
                "source": {
                    "kind": "EventsNode",
                    "event": "paywall_cta_tapped",
                    "math": "total",
                },
            },
            {
                "kind": "ExperimentMetric",
                "metric_type": "mean",
                "name": "purchase_started",
                "source": {
                    "kind": "EventsNode",
                    "event": "purchase_started",
                    "math": "total",
                },
            },
        ],
    }
    created = request("POST", "/experiments/", token, payload)
    print(f"Created experiment id={created.get('id')}")
    return created


def launch_experiment(token: str, experiment: dict) -> dict:
    exp_id = experiment["id"]
    if experiment.get("start_date"):
        print("Experiment already launched")
        return experiment

    # Launch = set start_date via PATCH (PostHog UI equivalent of Launch)
    from datetime import datetime, timezone

    started = request(
        "PATCH",
        f"/experiments/{exp_id}/",
        token,
        {"start_date": datetime.now(timezone.utc).isoformat()},
    )
    print(f"Launched experiment start_date={started.get('start_date')}")
    return started


def main() -> None:
    token = os.environ.get("POSTHOG_PERSONAL_API_KEY", "").strip()
    if not token.startswith("phx_"):
        print(
            "Missing POSTHOG_PERSONAL_API_KEY (phx_…) with scopes:\n"
            "  feature_flag:write\n"
            "  experiment:write\n"
            "Create at: PostHog → Settings → Personal API keys",
            file=sys.stderr,
        )
        sys.exit(1)

    flag = ensure_flag(token)
    experiment = ensure_experiment(token, flag)
    launch_experiment(token, experiment)
    print("\nDone. Flag key:", FLAG_KEY)
    print(f"UI: {POSTHOG_HOST}/project/{PROJECT_ID}/experiments")


if __name__ == "__main__":
    main()
