#!/usr/bin/env python3
"""TikTok scraper (no login) via public embed endpoints.

- profile(handle)     -> followers / likes / videoCount  (page rehydration JSON)
- creator(handle)     -> 10 most recent posts (id, desc, playCount, cover)
- post(id)            -> full stats: playCount, diggCount, shareCount, commentCount,
                         createTime, caption+hashtags, slide count, covers
"""
from __future__ import annotations
import json, re, sys, time, urllib.request, urllib.error, pathlib, random

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
HERE = pathlib.Path(__file__).resolve().parent
CACHE = HERE / "cache"
CACHE.mkdir(exist_ok=True)


def get(url: str, key: str, ttl: int = 86400) -> str:
    f = CACHE / (re.sub(r"[^a-zA-Z0-9_.-]", "_", key)[:120] + ".html")
    if f.exists() and time.time() - f.stat().st_mtime < ttl:
        return f.read_text(errors="ignore")
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept-Language": "en-US,en;q=0.9",
        "Accept": "text/html,application/xhtml+xml",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read().decode("utf-8", "ignore")
    except Exception as e:  # noqa: BLE001
        body = ""
        print(f"  ! fetch fail {key}: {e}", file=sys.stderr)
    f.write_text(body)
    time.sleep(random.uniform(0.6, 1.4))
    return body


def _json_block(html: str, marker: str):
    m = re.search(rf'id="{marker}" type="application/json">(.*?)</script>', html, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


def profile(handle: str) -> dict | None:
    html = get(f"https://www.tiktok.com/@{handle}", f"prof_{handle}")
    d = _json_block(html, "__UNIVERSAL_DATA_FOR_REHYDRATION__")
    if not d:
        return None
    ui = d.get("__DEFAULT_SCOPE__", {}).get("webapp.user-detail", {}).get("userInfo")
    if not ui:
        return None
    u, s = ui.get("user", {}), ui.get("stats", {})
    return {
        "handle": u.get("uniqueId", handle),
        "nickname": u.get("nickname", ""),
        "bio": u.get("signature", ""),
        "secUid": u.get("secUid", ""),
        "followers": s.get("followerCount", 0),
        "likes": s.get("heartCount", 0),
        "videoCount": s.get("videoCount", 0),
        "avatar": u.get("avatarLarger", ""),
    }


def creator(handle: str) -> list[dict]:
    html = get(f"https://www.tiktok.com/embed/@{handle}", f"emb_{handle}")
    d = _json_block(html, "__FRONTITY_CONNECT_STATE__")
    if not d:
        return []
    src = d.get("source", {}).get("data", {})
    page = src.get(f"/embed/@{handle}") or next(
        (v for k, v in src.items() if k.startswith("/embed/@")), {})
    return page.get("videoList") or []


def post(pid: str) -> dict | None:
    html = get(f"https://www.tiktok.com/embed/v2/{pid}", f"post_{pid}")
    d = _json_block(html, "__FRONTITY_CONNECT_STATE__")
    if not d:
        return None
    src = d.get("source", {}).get("data", {})
    page = src.get(f"/embed/v2/{pid}") or next(
        (v for k, v in src.items() if isinstance(v, dict) and "videoData" in v), {})
    vd = page.get("videoData") or {}
    it, au = vd.get("itemInfos") or {}, vd.get("authorInfos") or {}
    if not it:
        return None
    covers = it.get("coversOrigin") or it.get("covers") or []
    text = it.get("text", "")
    is_photo = "photomode" in (covers[0] if covers else "")
    return {
        "id": it.get("id", pid),
        "handle": au.get("uniqueId", ""),
        "url": f"https://www.tiktok.com/@{au.get('uniqueId','')}/{'photo' if is_photo else 'video'}/{it.get('id',pid)}",
        "caption": text,
        "hashtags": re.findall(r"#(\w+)", text),
        "hook": re.sub(r"#\w+", "", text).strip(),
        "createTime": int(it.get("createTime") or 0),
        "views": it.get("playCount", 0),
        "likes": it.get("diggCount", 0),
        "comments": it.get("commentCount", 0),
        "shares": it.get("shareCount", 0),
        "isPhoto": is_photo,
        "cover": covers[0] if covers else "",
        "country": it.get("locationCreated", ""),
    }


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="Scrape TikTok sans login (endpoints embed).")
    ap.add_argument("handles", nargs="*", help="comptes a lire (@ optionnel)")
    ap.add_argument("--post", help="scrape un post par son id")
    a = ap.parse_args()

    if a.post:
        print(json.dumps(post(a.post), ensure_ascii=False, indent=1))
    for h in a.handles:
        h = h.lstrip("@")
        p = profile(h) or {}
        print(f"\n@{h}  followers={p.get('followers', '?')}  posts={p.get('videoCount', '?')}")
        for v in creator(h):
            print(f"  {v.get('playCount', 0):>9,}  {v.get('desc', '')[:80]}")
