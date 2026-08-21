import { NextResponse } from "next/server";
import { normalizeTarget } from "@/lib/keys";
import { resolveMeta } from "@/lib/meta";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = (await request.json().catch(() => ({}))) as { url?: string };
  const target = normalizeTarget(body.url ?? "");
  if (!target) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }
  const meta = await resolveMeta(target);
  return NextResponse.json({ ...meta, url: target.url, key: target.key });
}
