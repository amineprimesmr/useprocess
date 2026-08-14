import { ensureSession } from "./_lib/auth.js";
import { initPhotoPost, json } from "./_lib/tiktok.js";

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try {
        const raw = Buffer.concat(chunks).toString("utf8") || "{}";
        resolve(JSON.parse(raw));
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

export default async function handler(req, res) {
  try {
    if (req.method !== "POST") {
      return json(res, 405, { error: "method_not_allowed" });
    }
    const session = await ensureSession(req, res);
    if (!session) {
      return json(res, 401, { error: "not_authenticated" });
    }

    const body = await readBody(req);
    const {
      photo_images,
      title,
      description,
      privacy_level,
      disable_comment = true,
      brand_content_toggle = false,
      brand_organic_toggle = false,
      auto_add_music = true,
      post_mode = "DIRECT_POST",
    } = body;

    if (!Array.isArray(photo_images) || photo_images.length === 0) {
      return json(res, 400, { error: "photo_images_required" });
    }

    const mode = post_mode === "MEDIA_UPLOAD" ? "MEDIA_UPLOAD" : "DIRECT_POST";
    if (mode === "DIRECT_POST" && (!privacy_level || typeof privacy_level !== "string")) {
      return json(res, 400, { error: "privacy_level_required" });
    }
    if (brand_content_toggle && brand_organic_toggle) {
      return json(res, 400, { error: "cannot_enable_both_brand_toggles" });
    }

    const fullCaption = String(description || title || "");
    const shortTitle = String(title || fullCaption).slice(0, 90);

    const post_info = {
      title: shortTitle,
      description: fullCaption.slice(0, 2200),
    };

    if (mode === "DIRECT_POST") {
      post_info.privacy_level = privacy_level;
      post_info.disable_comment = Boolean(disable_comment);
      post_info.auto_add_music = Boolean(auto_add_music);
      post_info.brand_content_toggle = Boolean(brand_content_toggle);
      post_info.brand_organic_toggle = Boolean(brand_organic_toggle);
    }

    const payload = {
      post_info,
      source_info: {
        source: "PULL_FROM_URL",
        photo_cover_index: 0,
        photo_images: photo_images.slice(0, 35),
      },
      post_mode: mode,
      media_type: "PHOTO",
    };

    const data = await initPhotoPost(session.access_token, payload);
    return json(res, 200, {
      ok: true,
      publish_id: data.publish_id,
      data,
    });
  } catch (e) {
    return json(res, 400, { error: String(e.message || e) });
  }
}
