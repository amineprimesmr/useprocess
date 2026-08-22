import { NextResponse } from "next/server";
import { trackClick } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const dest = await trackClick(id);
  if (!dest) {
    return NextResponse.redirect(new URL("/", process.env.NEXT_PUBLIC_SITE_URL || "https://footgoat.lol"));
  }
  return NextResponse.redirect(dest, { status: 302 });
}
