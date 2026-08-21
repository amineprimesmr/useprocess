import { NextResponse } from "next/server";
import { getBoard, registerUniqueVisitor } from "@/lib/db";
import { pingPresence } from "@/lib/presence";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const visitor = url.searchParams.get("vid");
  const sinceRevision = Number(url.searchParams.get("rev") ?? "0");

  if (visitor) {
    await pingPresence(visitor);
    await registerUniqueVisitor(visitor);
  }

  const board = await getBoard();

  if (sinceRevision > 0 && sinceRevision === board.revision) {
    return NextResponse.json(
      { unchanged: true, revision: board.revision, online: board.online, visitors: board.visitors },
      { headers: { "cache-control": "no-store, max-age=0" } },
    );
  }

  return NextResponse.json(board, {
    headers: { "cache-control": "no-store, max-age=0" },
  });
}
