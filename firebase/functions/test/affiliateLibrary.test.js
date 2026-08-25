const test = require("node:test");
const assert = require("node:assert/strict");
const {
  parseTikTokUrl,
  slugFormatId,
  seedFormats,
  mergeCatalog,
  MCP_TOOLS,
} = require("../lib/affiliateLibraryShared.js");

test("parseTikTokUrl accepts photo and video links", () => {
  const photo = parseTikTokUrl("https://www.tiktok.com/@mannyprcs/photo/7670070332337835297");
  assert.equal(photo.id, "7670070332337835297");
  assert.equal(photo.handle, "mannyprcs");
  const video = parseTikTokUrl("https://www.tiktok.com/@mannyprcs/video/1234567890?lang=en");
  assert.equal(video.id, "1234567890");
  assert.equal(parseTikTokUrl("https://example.com/nope"), null);
});

test("slugFormatId is stable and lowercase", () => {
  assert.equal(slugFormatId("Glow-up célébrité"), "glow-up-celebrite");
});

test("seedFormats exposes official specs and posts", () => {
  const seed = seedFormats({
    FORMAT_SPECS: [
      {
        id: "01",
        name: { fr: "Guide", en: "Guide" },
        canvas: "1080×1920",
        when: { fr: "Tous les jours", en: "Every day" },
        hook: { fr: "hook", en: "hook" },
        caption: { fr: "cap", en: "cap" },
        fatal: { fr: "non", en: "no" },
        slides: [{ src: "/assets/x.jpg", fr: "Hook", en: "Hook" }],
        structure: [{ fr: "1. Hook", en: "1. Hook" }],
      },
    ],
    FORMAT_LIBRARY: [
      {
        id: "glowup",
        specId: "02",
        name: { fr: "Glow", en: "Glow" },
        formula: { fr: "Hook glow", en: "Glow hook" },
        posts: [{ id: "1", url: "https://www.tiktok.com/@x/photo/1", views: 10, likes: 2 }],
      },
    ],
  });
  assert.equal(seed.specs[0].slides[0].src.startsWith("https://useprocess.xyz/"), true);
  assert.equal(seed.formats[0].posts[0].official, true);
});

test("mergeCatalog appends clipper TikToks onto official formats", () => {
  const seed = seedFormats({
    FORMAT_SPECS: [],
    FORMAT_LIBRARY: [
      {
        id: "glowup",
        specId: "02",
        name: { fr: "Glow", en: "Glow" },
        formula: { fr: "x", en: "x" },
        posts: [{ id: "seed", url: "https://tiktok.com/seed", views: 5 }],
      },
    ],
  });
  const merged = mergeCatalog({
    seedFormats: seed.formats,
    seedSpecs: seed.specs,
    liveFormats: [
      {
        id: "custom",
        specId: "",
        name: { fr: "Perso", en: "Custom" },
        formula: { fr: "", en: "" },
        official: false,
        createdByName: "Alex",
        posts: [],
      },
    ],
    livePosts: [
      {
        id: "live1",
        formatId: "glowup",
        url: "https://www.tiktok.com/@a/photo/9",
        cover: "",
        hook: { fr: "h", en: "h" },
        subject: { fr: "@a", en: "@a" },
        caption: "",
        createdAt: 1,
        slides: 0,
        views: 99,
        likes: 0,
        comments: 0,
        shares: 0,
        saves: 0,
        official: false,
        addedByName: "Alex",
      },
    ],
  });
  const glow = merged.formats.find((row) => row.id === "glowup");
  assert.equal(glow.posts.length, 2);
  assert.equal(glow.posts[0].id, "live1");
  assert.equal(merged.formats.some((row) => row.id === "custom"), true);
});

test("MCP tool list covers every format surface", () => {
  const names = MCP_TOOLS.map((tool) => tool.name);
  for (const required of ["list_formats", "get_format", "list_tiktoks", "create_format", "add_tiktok"]) {
    assert.equal(names.includes(required), true);
  }
});
