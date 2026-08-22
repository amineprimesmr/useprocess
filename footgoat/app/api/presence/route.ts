import { NextResponse } from "next/server";
import { pingPresence } from "@/lib/presence";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = (await request.json().catch(() => ({}))) as { id?: string };
  const id = (body.id || "").slice(0, 80) || "anon";
  const online = await pingPresence(id);
  return NextResponse.json({ online });
}
