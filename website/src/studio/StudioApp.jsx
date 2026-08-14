import { useEffect, useMemo, useState } from "react";
import {
  appCopy,
  getSiteLanguage,
  setSiteLanguage,
  subscribeSiteLanguage,
} from "../features/app-copy.js";
import "./studio.css";

const TERMINAL = new Set(["PUBLISH_COMPLETE", "SEND_TO_USER_INBOX", "FAILED"]);

function privacyLabel(level) {
  const map = {
    PUBLIC_TO_EVERYONE: appCopy("Tout le monde", "Everyone"),
    MUTUAL_FOLLOW_FRIENDS: appCopy("Amis", "Friends"),
    FOLLOWER_OF_CREATOR: appCopy("Abonnés", "Followers"),
    SELF_ONLY: appCopy("Moi uniquement", "Only me"),
  };
  return map[level] || level;
}

async function api(path, opts = {}) {
  const r = await fetch(path, {
    credentials: "include",
    headers: { Accept: "application/json", ...(opts.headers || {}) },
    ...opts,
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const err = new Error(data.error || `HTTP ${r.status}`);
    err.status = r.status;
    err.data = data;
    throw err;
  }
  return data;
}

export function StudioApp() {
  const [, setLangTick] = useState(0);
  const [loading, setLoading] = useState(true);
  const [creator, setCreator] = useState(null);
  const [carousels, setCarousels] = useState([]);
  const [baseUrl, setBaseUrl] = useState("https://useprocess.xyz/tiktok-media/carousels");
  const [selectedId, setSelectedId] = useState("");
  const [caption, setCaption] = useState("");
  const [privacy, setPrivacy] = useState("");
  const [commentsOff, setCommentsOff] = useState(true);
  const [commercial, setCommercial] = useState(false);
  const [yourBrand, setYourBrand] = useState(false);
  const [brandedContent, setBrandedContent] = useState(false);
  const [musicConsent, setMusicConsent] = useState(false);
  const [brandedConsent, setBrandedConsent] = useState(false);
  const [postMode, setPostMode] = useState("DIRECT_POST");
  const [busy, setBusy] = useState(false);
  const [statusText, setStatusText] = useState("");
  const [statusKind, setStatusKind] = useState("");
  const [banner, setBanner] = useState("");

  useEffect(() => subscribeSiteLanguage(() => setLangTick((n) => n + 1)), []);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("connected") === "1") {
      setBanner(appCopy("Compte TikTok connecté.", "TikTok account connected."));
    }
    const err = params.get("error");
    if (err) {
      setBanner(err);
      setStatusKind("err");
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const packs = await api("/api/tiktok/carousels");
        if (cancelled) return;
        setCarousels(packs.carousels || []);
        if (packs.base_url) setBaseUrl(packs.base_url.replace(/\/$/, ""));
        if (packs.carousels?.[0]) {
          setSelectedId(packs.carousels[0].id);
          setCaption(packs.carousels[0].caption || "");
        }
      } catch (e) {
        if (!cancelled) {
          setStatusText(String(e.message || e));
          setStatusKind("err");
        }
      }

      try {
        const me = await api("/api/tiktok/me");
        if (cancelled) return;
        setCreator(me.creator || null);
      } catch (e) {
        if (!cancelled && e.status !== 401) {
          setStatusText(String(e.message || e));
          setStatusKind("err");
        }
        if (!cancelled) setCreator(null);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const selected = useMemo(
    () => carousels.find((c) => c.id === selectedId) || null,
    [carousels, selectedId]
  );

  const slideUrls = useMemo(() => {
    if (!selected) return [];
    return (selected.slides || []).map((s) => `${baseUrl}/${selected.id}/${s}`);
  }, [selected, baseUrl]);

  const privacyOptions = creator?.privacy_level_options || [];

  const canPublish = Boolean(
    creator &&
      selected &&
      slideUrls.length &&
      musicConsent &&
      (postMode === "MEDIA_UPLOAD" || privacy) &&
      (!commercial || ((yourBrand || brandedContent) && !(yourBrand && brandedContent))) &&
      (!brandedContent || brandedConsent)
  );

  function onSelectPack(pack) {
    setSelectedId(pack.id);
    setCaption(pack.caption || "");
  }

  async function onLogout() {
    await api("/api/tiktok/logout", { method: "POST" });
    setCreator(null);
    setPrivacy("");
    setBanner("");
  }

  async function pollStatus(publishId) {
    for (let i = 0; i < 40; i++) {
      await new Promise((r) => setTimeout(r, 2000));
      const res = await api(`/api/tiktok/status?publish_id=${encodeURIComponent(publishId)}`);
      const st = res.data?.status || res.data?.publish_status || "PROCESSING";
      setStatusText(
        appCopy(`Statut : ${st}`, `Status: ${st}`) +
          (res.data?.fail_reason ? ` — ${res.data.fail_reason}` : "")
      );
      setStatusKind(st === "FAILED" ? "err" : TERMINAL.has(st) ? "ok" : "warn");
      if (TERMINAL.has(st)) return st;
    }
    setStatusKind("warn");
    setStatusText(appCopy("Toujours en cours… rafraîchis plus tard.", "Still processing… refresh later."));
    return "TIMEOUT";
  }

  async function onPublish() {
    if (!canPublish) return;
    setBusy(true);
    setStatusKind("warn");
    setStatusText(appCopy("Publication en cours…", "Publishing…"));
    try {
      const payload = {
        photo_images: slideUrls,
        title: caption,
        description: caption,
        privacy_level: privacy || undefined,
        disable_comment: commentsOff,
        brand_organic_toggle: commercial && yourBrand,
        brand_content_toggle: commercial && brandedContent,
        post_mode: postMode,
      };
      const res = await api("/api/tiktok/publish", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const publishId = res.publish_id;
      setStatusText(
        appCopy(`Envoyé — publish_id ${publishId}`, `Submitted — publish_id ${publishId}`)
      );
      await pollStatus(publishId);
    } catch (e) {
      setStatusKind("err");
      setStatusText(String(e.message || e));
    } finally {
      setBusy(false);
    }
  }

  const lang = getSiteLanguage();

  return (
    <div className="ps-studio">
      <div className="ps-wrap">
        <header className="ps-brand">
          <div className="ps-brand-mark">
            <img src="/assets/icone.png?v=20260808" alt="" width={40} height={40} />
            <div>
              <h1>Process Studio</h1>
              <p>{appCopy("Publier des carousels sur TikTok", "Publish carousels to TikTok")}</p>
            </div>
          </div>
          <div className="ps-lang" role="group" aria-label="Language">
            <button type="button" aria-pressed={lang === "fr"} onClick={() => setSiteLanguage("fr")}>
              FR
            </button>
            <button type="button" aria-pressed={lang === "en"} onClick={() => setSiteLanguage("en")}>
              EN
            </button>
          </div>
        </header>

        <section className="ps-hero">
          <h2>
            {appCopy(
              "Connecte TikTok, choisis un carousel, publie.",
              "Connect TikTok, pick a carousel, publish."
            )}
          </h2>
          <p>
            {appCopy(
              "Outil créateur Process — OAuth officiel, prévisualisation, confidentialité et disclosure commercial avant publication.",
              "Process creator tool — official OAuth, preview, privacy and commercial disclosure before publishing."
            )}
          </p>
        </section>

        {banner ? (
          <p className={`ps-status ${statusKind === "err" ? "err" : "ok"}`} role="status">
            {banner}
          </p>
        ) : null}

        <section className="ps-panel">
          <h3>{appCopy("1. Compte TikTok", "1. TikTok account")}</h3>
          {loading ? (
            <p className="ps-muted">{appCopy("Chargement…", "Loading…")}</p>
          ) : creator ? (
            <div className="ps-row">
              <span className="ps-user">
                @{creator.creator_username || creator.username || "creator"}
              </span>
              {creator.creator_nickname ? (
                <span className="ps-muted">{creator.creator_nickname}</span>
              ) : null}
              <button type="button" className="ps-btn ps-btn-ghost" onClick={onLogout}>
                {appCopy("Déconnecter", "Disconnect")}
              </button>
            </div>
          ) : (
            <div>
              <div className="ps-row">
                <a className="ps-btn ps-btn-primary" href="/api/tiktok/oauth/start">
                  {appCopy("Se connecter avec TikTok", "Connect with TikTok")}
                </a>
              </div>
              <p className="ps-muted" style={{ marginTop: 12 }}>
                {appCopy(
                  "Tant que l’app TikTok est en Sandbox, connecte-toi avec @process.debloat.app (seul compte autorisé). Déconnecte les autres comptes TikTok du navigateur avant.",
                  "While the TikTok app is in Sandbox, sign in as @process.debloat.app (only allowed account). Log out other TikTok accounts in the browser first."
                )}
              </p>
            </div>
          )}
        </section>

        <section className="ps-panel">
          <h3>{appCopy("2. Choisir un carousel", "2. Choose a carousel")}</h3>
          <div className="ps-packs">
            {carousels.map((pack) => {
              const cover = `${baseUrl}/${pack.id}/${pack.slides?.[0] || "slide_01.jpg"}`;
              const title = lang === "en" && pack.title_en ? pack.title_en : pack.title;
              return (
                <button
                  key={pack.id}
                  type="button"
                  className="ps-pack"
                  aria-pressed={selectedId === pack.id}
                  onClick={() => onSelectPack(pack)}
                >
                  <img src={cover} alt="" loading="lazy" />
                  <span>
                    <strong>{title}</strong>
                    <span className="ps-muted">
                      {(pack.slides || []).length} {appCopy("slides", "slides")}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
          {slideUrls.length ? (
            <>
              <p className="ps-label" style={{ marginTop: 14 }}>
                {appCopy("Aperçu", "Preview")}
              </p>
              <div className="ps-slides">
                {slideUrls.map((url) => (
                  <img key={url} src={url} alt="" loading="lazy" />
                ))}
              </div>
            </>
          ) : null}
        </section>

        <section className="ps-panel">
          <h3>{appCopy("3. Caption & options", "3. Caption & options")}</h3>
          <label className="ps-label" htmlFor="ps-caption">
            Caption
          </label>
          <textarea
            id="ps-caption"
            className="ps-textarea"
            value={caption}
            onChange={(e) => setCaption(e.target.value)}
            maxLength={2200}
          />

          <label className="ps-label" htmlFor="ps-mode" style={{ marginTop: 14 }}>
            {appCopy("Mode de publication", "Post mode")}
          </label>
          <select
            id="ps-mode"
            className="ps-select"
            value={postMode}
            onChange={(e) => setPostMode(e.target.value)}
          >
            <option value="DIRECT_POST">
              {appCopy("Publication directe", "Direct post")}
            </option>
            <option value="MEDIA_UPLOAD">
              {appCopy("Brouillon dans l’app TikTok (inbox)", "Draft in TikTok app (inbox)")}
            </option>
          </select>

          {postMode === "DIRECT_POST" ? (
            <>
              <label className="ps-label" htmlFor="ps-privacy" style={{ marginTop: 14 }}>
                {appCopy("Confidentialité (obligatoire)", "Privacy (required)")}
              </label>
              <select
                id="ps-privacy"
                className="ps-select"
                value={privacy}
                onChange={(e) => setPrivacy(e.target.value)}
              >
                <option value="">
                  {appCopy("Choisir…", "Choose…")}
                </option>
                {privacyOptions.map((level) => (
                  <option key={level} value={level}>
                    {privacyLabel(level)}
                  </option>
                ))}
              </select>
              {!privacyOptions.length && creator ? (
                <p className="ps-muted" style={{ marginTop: 8 }}>
                  {appCopy(
                    "Aucune option privacy renvoyée par TikTok — reconnecte-toi.",
                    "No privacy options from TikTok — reconnect."
                  )}
                </p>
              ) : null}
            </>
          ) : null}

          <label className="ps-toggle">
            <input
              type="checkbox"
              checked={commentsOff}
              onChange={(e) => setCommentsOff(e.target.checked)}
            />
            <span>{appCopy("Désactiver les commentaires", "Turn off comments")}</span>
          </label>

          <label className="ps-toggle">
            <input
              type="checkbox"
              checked={commercial}
              onChange={(e) => {
                const on = e.target.checked;
                setCommercial(on);
                if (!on) {
                  setYourBrand(false);
                  setBrandedContent(false);
                  setBrandedConsent(false);
                }
              }}
            />
            <span>
              {appCopy(
                "Contenu commercial / disclosure de marque",
                "Commercial content / brand disclosure"
              )}
            </span>
          </label>

          {commercial ? (
            <>
              <label className="ps-toggle">
                <input
                  type="checkbox"
                  checked={yourBrand}
                  onChange={(e) => {
                    setYourBrand(e.target.checked);
                    if (e.target.checked) setBrandedContent(false);
                  }}
                />
                <span>{appCopy("Your brand (contenu organique de marque)", "Your brand")}</span>
              </label>
              <label className="ps-toggle">
                <input
                  type="checkbox"
                  checked={brandedContent}
                  onChange={(e) => {
                    setBrandedContent(e.target.checked);
                    if (e.target.checked) setYourBrand(false);
                  }}
                />
                <span>{appCopy("Branded content (partenariat)", "Branded content")}</span>
              </label>
            </>
          ) : null}

          <label className="ps-toggle">
            <input
              type="checkbox"
              checked={musicConsent}
              onChange={(e) => setMusicConsent(e.target.checked)}
            />
            <span>
              {appCopy(
                "J’accepte la Music Usage Confirmation de TikTok.",
                "I agree to TikTok’s Music Usage Confirmation."
              )}
            </span>
          </label>

          {brandedContent ? (
            <label className="ps-toggle">
              <input
                type="checkbox"
                checked={brandedConsent}
                onChange={(e) => setBrandedConsent(e.target.checked)}
              />
              <span>
                {appCopy(
                  "J’accepte la Branded Content Policy de TikTok.",
                  "I agree to TikTok’s Branded Content Policy."
                )}
              </span>
            </label>
          ) : null}

          <p className="ps-consent">
            {appCopy(
              "En publiant, tu confirmes que ton contenu respecte les règles TikTok (musique, branded content, publicité).",
              "By publishing, you confirm your content follows TikTok rules (music, branded content, advertising)."
            )}{" "}
            <a href="https://www.tiktok.com/legal/page/global/music-usage-confirmation/en" target="_blank" rel="noreferrer">
              Music
            </a>
            {" · "}
            <a href="https://www.tiktok.com/legal/page/global/bc-policy/en" target="_blank" rel="noreferrer">
              Branded Content
            </a>
          </p>
        </section>

        <section className="ps-panel">
          <h3>{appCopy("4. Publier", "4. Publish")}</h3>
          <button
            type="button"
            className="ps-btn ps-btn-primary"
            disabled={!canPublish || busy}
            onClick={onPublish}
          >
            {busy
              ? appCopy("Publication…", "Publishing…")
              : appCopy("Publier sur TikTok", "Publish to TikTok")}
          </button>
          {statusText ? (
            <p className={`ps-status ${statusKind}`} style={{ marginTop: 12 }} role="status">
              {statusText}
            </p>
          ) : (
            <p className="ps-muted" style={{ marginTop: 12 }}>
              {appCopy(
                "Le bouton reste désactivé tant que la privacy / les consents ne sont pas complets.",
                "Publish stays disabled until privacy / consents are complete."
              )}
            </p>
          )}
        </section>
      </div>
    </div>
  );
}
