import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { affiliateHttpStatus, db, getAffiliateForUid } from "./affiliateShared";
import {
  formatPayload,
  liveFormatFromDoc,
  livePostFromDoc,
  mergeCatalog,
  parseTikTokUrl,
  seedFormats,
  slugFormatId,
  type ClippingFormat,
  type ClippingPost,
} from "./affiliateLibraryShared";
import clippingSeed from "./clippingSeed.json";
import { setCors, verifyAppAttestation, verifyFirebaseUser } from "./referralShared";

const FORMATS = () => db().collection("clippingFormats");
const POSTS = () => db().collection("clippingPosts");

function seeded() {
  return seedFormats(clippingSeed as { FORMAT_LIBRARY?: any[]; FORMAT_SPECS?: any[] });
}

async function hydrateTikTok(url: string): Promise<{
  title: string;
  author: string;
  thumbnail: string;
}> {
  try {
    const response = await fetch(`https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`, {
      headers: { Accept: "application/json" },
    });
    if (!response.ok) return { title: "", author: "", thumbnail: "" };
    const data = (await response.json()) as Record<string, unknown>;
    return {
      title: String(data.title || "").slice(0, 240),
      author: String(data.author_name || "").slice(0, 80),
      thumbnail: String(data.thumbnail_url || "").slice(0, 500),
    };
  } catch {
    return { title: "", author: "", thumbnail: "" };
  }
}

export async function loadClippingCatalog() {
  const seed = seeded();
  const [formatSnap, postSnap] = await Promise.all([
    FORMATS().limit(80).get(),
    POSTS().limit(400).get(),
  ]);
  const liveFormats: ClippingFormat[] = formatSnap.docs.map((doc) =>
    liveFormatFromDoc(doc.id, doc.data() as Record<string, unknown>)
  );
  const livePosts: ClippingPost[] = postSnap.docs.map((doc) => {
    const data = doc.data() as Record<string, unknown>;
    return livePostFromDoc(doc.id, data, String(data.formatId || ""));
  });
  return mergeCatalog({
    seedFormats: seed.formats,
    seedSpecs: seed.specs,
    liveFormats,
    livePosts,
  });
}

export async function createClippingFormat(params: {
  affiliateId: string;
  displayName: string;
  nameFr: string;
  nameEn: string;
  formulaFr: string;
  formulaEn: string;
  specId?: string;
}) {
  const nameFr = params.nameFr.trim().slice(0, 80);
  const nameEn = (params.nameEn || params.nameFr).trim().slice(0, 80);
  if (nameFr.length < 2) throw new Error("INVALID_TEXT");
  const catalog = await loadClippingCatalog();
  let id = slugFormatId(nameEn || nameFr);
  if (catalog.formats.some((row) => row.id === id)) {
    id = `${id}-${params.affiliateId.slice(0, 6)}`;
  }
  const specId = String(params.specId || "").trim();
  const spec = catalog.specs.find((item) => item.id === specId);
  await FORMATS()
    .doc(id)
    .set({
      nameFr,
      nameEn,
      formulaFr: params.formulaFr.trim().slice(0, 240),
      formulaEn: (params.formulaEn || params.formulaFr).trim().slice(0, 240),
      specId: spec?.id || "",
      createdBy: params.affiliateId,
      createdByName: params.displayName.slice(0, 80),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  return id;
}

export async function addClippingTikTok(params: {
  affiliateId: string;
  displayName: string;
  url: string;
  formatId: string;
  hookFr?: string;
  hookEn?: string;
}) {
  const parsed = parseTikTokUrl(params.url);
  if (!parsed) throw new Error("INVALID_TEXT");
  const catalog = await loadClippingCatalog();
  const format = catalog.formats.find((row) => row.id === params.formatId);
  if (!format) throw new Error("NOT_FOUND");
  if (format.posts.some((post) => post.id === parsed.id || post.url === parsed.url)) {
    throw new Error("CODE_CONFLICT");
  }
  const meta = await hydrateTikTok(parsed.url);
  const hook = (params.hookFr || meta.title || parsed.handle || "TikTok").slice(0, 240);
  const hookEn = (params.hookEn || params.hookFr || meta.title || hook).slice(0, 240);
  const author = meta.author || (parsed.handle ? `@${parsed.handle}` : "TikTok");
  await POSTS()
    .doc(parsed.id)
    .set({
      formatId: format.id,
      url: parsed.url,
      cover: meta.thumbnail,
      hookFr: hook,
      hookEn,
      subject: author,
      author,
      caption: meta.title.slice(0, 500),
      views: 0,
      likes: 0,
      comments: 0,
      shares: 0,
      saves: 0,
      slides: 0,
      addedBy: params.affiliateId,
      addedByName: params.displayName.slice(0, 80),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAtMs: Date.now(),
    });
  return parsed.id;
}

export const affiliateLibrary = onRequest(
  {
    invoker: "public",
    cors: true,
    timeoutSeconds: 30,
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
      const affiliate = await getAffiliateForUid(uid);
      if (!affiliate) {
        res.status(404).json({ error: "AFFILIATE_NOT_LINKED" });
        return;
      }

      const action = String(req.body?.action || "list");
      const displayName = String(affiliate.displayName || "Clipper").slice(0, 80);

      if (action === "list") {
        const catalog = await loadClippingCatalog();
        res.status(200).json({
          ok: true,
          viewerAffiliateId: affiliate.affiliateId,
          specs: catalog.specs,
          formats: catalog.formats.map((row) => formatPayload(row, catalog.specs)),
        });
        return;
      }

      if (action === "createFormat") {
        const id = await createClippingFormat({
          affiliateId: affiliate.affiliateId,
          displayName,
          nameFr: String(req.body?.nameFr || req.body?.name_fr || ""),
          nameEn: String(req.body?.nameEn || req.body?.name_en || ""),
          formulaFr: String(req.body?.formulaFr || req.body?.formula_fr || ""),
          formulaEn: String(req.body?.formulaEn || req.body?.formula_en || ""),
          specId: String(req.body?.specId || req.body?.spec_id || ""),
        });
        const catalog = await loadClippingCatalog();
        res.status(200).json({
          ok: true,
          id,
          formats: catalog.formats.map((row) => formatPayload(row, catalog.specs)),
          specs: catalog.specs,
        });
        return;
      }

      if (action === "addTikTok") {
        const id = await addClippingTikTok({
          affiliateId: affiliate.affiliateId,
          displayName,
          url: String(req.body?.url || ""),
          formatId: String(req.body?.formatId || req.body?.format_id || ""),
          hookFr: String(req.body?.hookFr || req.body?.hook_fr || ""),
          hookEn: String(req.body?.hookEn || req.body?.hook_en || ""),
        });
        const catalog = await loadClippingCatalog();
        res.status(200).json({
          ok: true,
          id,
          formats: catalog.formats.map((row) => formatPayload(row, catalog.specs)),
          specs: catalog.specs,
        });
        return;
      }

      if (action === "deleteTikTok") {
        const id = String(req.body?.id || "").trim();
        if (!id) throw new Error("INVALID_TEXT");
        const ref = POSTS().doc(id);
        const snap = await ref.get();
        if (!snap.exists) throw new Error("NOT_FOUND");
        if (String(snap.data()?.addedBy || "") !== affiliate.affiliateId) {
          throw new Error("UNAUTHORIZED");
        }
        await ref.delete();
        const catalog = await loadClippingCatalog();
        res.status(200).json({
          ok: true,
          formats: catalog.formats.map((row) => formatPayload(row, catalog.specs)),
          specs: catalog.specs,
        });
        return;
      }

      res.status(400).json({ error: "INVALID_TEXT" });
    } catch (error: any) {
      const message = error?.message ?? "Unknown error";
      console.error("[affiliateLibrary]", message);
      res.status(affiliateHttpStatus(message)).json({ error: message });
    }
  }
);
