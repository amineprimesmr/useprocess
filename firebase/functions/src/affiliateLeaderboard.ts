import { onRequest } from "firebase-functions/v2/https";
import { affiliateHttpStatus, db, resolveAffiliateForAuthUser } from "./affiliateShared";
import {
  ClipperSort,
  normalizeClipperSort,
  rankClippers,
  toPublicClipper,
} from "./affiliateLeaderboardShared";
import { setCors, verifyAppAttestation, verifyFirebaseUser } from "./referralShared";

const LEADERBOARD_LIMIT = 400;

// Query-side counterpart to clipperMetric() in affiliateLeaderboardShared — without this,
// the top-400 `limit()` returns an arbitrary (document-id-ordered) slice once there are
// more than 400 active clippers, not the actual top performers for the requested sort.
function clipperSortField(sort: ClipperSort): string {
  switch (sort) {
    case "sales":
      return "stats.paidCount";
    case "trials":
      return "stats.trialCount";
    case "installs":
      return "stats.referredCount";
    case "visits":
      return "stats.linkViews";
    case "paywalls":
      return "stats.paywallCount";
    default:
      return "stats.lifetimeCents";
  }
}

export const affiliateLeaderboard = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 20,
    memory: "256MiB",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(req);
      await verifyAppAttestation(req);

      const affiliate = await resolveAffiliateForAuthUser(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const sort = normalizeClipperSort(req.body?.sort);
      const snap = await db()
        .collection("affiliates")
        .where("status", "==", "active")
        .orderBy(clipperSortField(sort), "desc")
        .limit(LEADERBOARD_LIMIT)
        .get();

      const rows = snap.docs.map((doc) => {
        const data = doc.data() as Record<string, unknown>;
        return toPublicClipper({
          affiliateId: doc.id,
          viewerAffiliateId: affiliate.affiliateId,
          displayName: data.displayName,
          primaryCode: data.primaryCode,
          codes: data.codes,
          stats: data.stats,
        });
      });

      if (affiliate.status === "active" && !rows.some((row) => row.isYou)) {
        rows.push(
          toPublicClipper({
            affiliateId: affiliate.affiliateId,
            viewerAffiliateId: affiliate.affiliateId,
            displayName: affiliate.displayName,
            primaryCode: affiliate.primaryCode,
            codes: affiliate.codes,
            stats: affiliate.stats,
          })
        );
      }

      const clippers = rankClippers(rows, sort);
      const you = clippers.find((row) => row.isYou) || null;

      res.status(200).json({
        ok: true,
        sort,
        count: clippers.length,
        viewerStatus: affiliate.status,
        you,
        clippers,
      });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateLeaderboard]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);
