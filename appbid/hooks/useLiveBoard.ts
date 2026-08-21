"use client";

import type { BoardPayload } from "@/lib/types";
import { useCallback, useEffect, useRef, useState } from "react";

const POLL_MS = 2000;
const POLL_HIDDEN_MS = 6000;

type BoardDelta = BoardPayload | { unchanged: true; revision: number; online: number; visitors: number };

function mergeBoard(prev: BoardPayload, delta: BoardDelta): BoardPayload {
  if (!("unchanged" in delta)) return delta;
  return {
    ...prev,
    revision: delta.revision,
    online: delta.online,
    visitors: delta.visitors,
  };
}

export function useLiveBoard(initial: BoardPayload) {
  const [board, setBoard] = useState(initial);
  const revisionRef = useRef(initial.revision);
  const abortRef = useRef<AbortController | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const refresh = useCallback(async (vid: string) => {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    const params = new URLSearchParams({ vid, rev: String(revisionRef.current) });

    try {
      const res = await fetch(`/api/board?${params}`, {
        cache: "no-store",
        signal: controller.signal,
      });
      if (!res.ok || controller.signal.aborted) return;
      const data = (await res.json()) as BoardDelta;
      if ("unchanged" in data) {
        setBoard((prev) => mergeBoard(prev, data));
        revisionRef.current = data.revision;
        return;
      }
      revisionRef.current = data.revision;
      setBoard(data);
    } catch {
      /* ignore abort / transient network */
    }
  }, []);

  useEffect(() => {
    const vid = (() => {
      const key = "appmog.vid";
      let id = localStorage.getItem(key);
      if (!id) {
        id = crypto.randomUUID();
        localStorage.setItem(key, id);
      }
      return id;
    })();

    const schedule = (ms: number) => {
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(tick, ms);
    };

    const tick = async () => {
      if (document.hidden) {
        schedule(POLL_HIDDEN_MS);
        return;
      }
      await refresh(vid);
      schedule(POLL_MS);
    };

    const onWake = () => {
      if (document.hidden) return;
      void refresh(vid);
      schedule(POLL_MS);
    };

    tick();
    document.addEventListener("visibilitychange", onWake);
    window.addEventListener("focus", onWake);
    window.addEventListener("pageshow", onWake);

    fetch("/api/presence", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: vid }),
    }).catch(() => {});

    const heartbeat = window.setInterval(() => {
      if (document.hidden) return;
      fetch("/api/presence", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ id: vid }),
      }).catch(() => {});
    }, 20000);

    return () => {
      abortRef.current?.abort();
      if (timerRef.current) clearTimeout(timerRef.current);
      window.clearInterval(heartbeat);
      document.removeEventListener("visibilitychange", onWake);
      window.removeEventListener("focus", onWake);
      window.removeEventListener("pageshow", onWake);
    };
  }, [refresh]);

  return board;
}
