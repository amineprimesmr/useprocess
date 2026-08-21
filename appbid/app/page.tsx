import { HomeClient } from "@/components/HomeClient";
import { getBoard } from "@/lib/db";

export const dynamic = "force-dynamic";

export default async function Page() {
  const board = await getBoard();
  return <HomeClient initial={board} />;
}
