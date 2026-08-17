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
  const [user, setUser] = useState(null);
  const [accounts, setAccounts] = useState([]);
  const [videos, setVideos] = useState([]);
  const [videoTotals, setVideoTotals] = useState(null);
  const [sandbox, setSandbox] = useState(false);
  const [carousels, setCarousels] = useState([]);
  const [baseUrl, setBaseUrl] = useState("https://useprocess.xyz/tiktok-media/carousels");
  const [selectedId, setSelectedId] = useState("");
  const [caption, setCaption] = useState("");
  const [privacy, setPrivacy] = useState("");
  const [commentsOff, setCommentsOff] = useState(true);
  const [duetOff, setDuetOff] = useState(true);
  const [stitchOff, setStitchOff] = useState(true);
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
      const oauthErrors = {
        state_mismatch: appCopy(
          "Session OAuth expirée — réessaie de connecter TikTok.",
          "OAuth session expired — try connecting TikTok again."
        ),
        invalid_state: appCopy(
          "État OAuth invalide — réessaie de connecter TikTok.",
          "Invalid OAuth state — try connecting TikTok again."
        ),
        missing_code: appCopy(
          "Connexion TikTok incomplète — réessaie.",
          "Incomplete TikTok connection — try again."
        ),
        access_denied: appCopy("Connexion TikTok annulée.", "TikTok connection canceled."),
        token_failed: appCopy("Échec de connexion TikTok — réessaie.", "TikTok connection failed — try again."),
      };
      setBanner(oauthErrors[err] || err);
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
        setUser(me.user || null);
        setAccounts(me.accounts || []);
        setSandbox(Boolean(me.sandbox));
        if (me.creator?.comment_disabled) setCommentsOff(true);
        if (me.creator?.duet_disabled) setDuetOff(true);
        if (me.creator?.stitch_disabled) setStitchOff(true);
        try {
          const vids = await api("/api/tiktok/videos?max_count=10");
          if (!cancelled) {
            setVideos(vids.videos || []);
            setVideoTotals(vids.page_totals || null);
          }
        } catch {
          if (!cancelled) {
            setVideos([]);
            setVideoTotals(null);
          }
        }
      } catch (e) {
        if (!cancelled && e.status !== 401) {
          setStatusText(String(e.message || e));
          setStatusKind("err");
        }
        if (!cancelled) {
          setCreator(null);
          setUser(null);
          setAccounts([]);
          setVideos([]);
        }
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
    setUser(null);
    setAccounts([]);
    setVideos([]);
    setVideoTotals(null);
    setPrivacy("");
    setBanner("");
  }

  async function onSwitchAccount(openId) {
    setBusy(true);
    try {
      await api("/api/tiktok/accounts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "switch", open_id: openId }),
      });
      window.location.href = "/studio?switched=1";
    } catch (e) {
      setStatusKind("err");
      setStatusText(String(e.message || e));
    } finally {
      setBusy(false);
    }
  }

  async function onRemoveAccount(openId) {
    setBusy(true);
    try {
      const res = await api("/api/tiktok/accounts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "remove", open_id: openId }),
      });
      if (!(res.accounts || []).length) {
        setCreator(null);
        setUser(null);
        setAccounts([]);
        setVideos([]);
        return;
      }
      window.location.href = "/studio?removed=1";
    } catch (e) {
      setStatusKind("err");
      setStatusText(String(e.message || e));
    } finally {
      setBusy(false);
    }
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
        disable_duet: duetOff,
        disable_stitch: stitchOff,
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
          <h3>{appCopy("1. Compte(s) TikTok", "1. TikTok account(s)")}</h3>
          {loading ? (
            <p className="ps-muted">{appCopy("Chargement…", "Loading…")}</p>
          ) : creator || user ? (
            <div>
              <div className="ps-row">
                {user?.avatar_url ? (
                  <img
                    src={user.avatar_url}
                    alt=""
                    width={36}
                    height={36}
                    style={{ borderRadius: 999, objectFit: "cover" }}
                  />
                ) : null}
                <span className="ps-user">
                  @{user?.username || creator?.creator_username || "creator"}
                </span>
                {user?.display_name || creator?.creator_nickname ? (
                  <span className="ps-muted">{user?.display_name || creator?.creator_nickname}</span>
                ) : null}
                <a className="ps-btn ps-btn-ghost" href="/api/tiktok/oauth/start?add=1">
                  {appCopy("Ajouter un compte", "Add account")}
                </a>
                <button type="button" className="ps-btn ps-btn-ghost" onClick={onLogout}>
                  {appCopy("Tout déconnecter", "Disconnect all")}
                </button>
              </div>
              {user && (user.follower_count != null || user.likes_count != null) ? (
                <p className="ps-muted" style={{ marginTop: 10 }}>
                  {appCopy("Stats", "Stats")}:{" "}
                  {(user.follower_count ?? "—").toLocaleString?.() || user.follower_count}{" "}
                  {appCopy("abonnés", "followers")} ·{" "}
                  {(user.likes_count ?? "—").toLocaleString?.() || user.likes_count} likes ·{" "}
                  {(user.video_count ?? "—").toLocaleString?.() || user.video_count}{" "}
                  {appCopy("vidéos", "videos")}
                </p>
              ) : null}
              {accounts.length > 1 ? (
                <div style={{ marginTop: 12, display: "grid", gap: 8 }}>
                  {accounts.map((a) => (
                    <div key={a.open_id} className="ps-row">
                      <span className={a.active ? "ps-user" : "ps-muted"}>
                        @{a.username || a.open_id.slice(0, 8)}
                        {a.active ? ` · ${appCopy("actif", "active")}` : ""}
                      </span>
                      {!a.active ? (
                        <button
                          type="button"
                          className="ps-btn ps-btn-ghost"
                          disabled={busy}
                          onClick={() => onSwitchAccount(a.open_id)}
                        >
                          {appCopy("Activer", "Switch")}
                        </button>
                      ) : null}
                      <button
                        type="button"
                        className="ps-btn ps-btn-ghost"
                        disabled={busy}
                        onClick={() => onRemoveAccount(a.open_id)}
                      >
                        {appCopy("Retirer", "Remove")}
                      </button>
                    </div>
                  ))}
                </div>
              ) : null}
              <p className="ps-muted" style={{ marginTop: 12 }}>
                <a href="/confidentialite#tiktok-studio">{appCopy("Confidentialité TikTok", "TikTok privacy")}</a>
                {" · "}
                <a href="/cgu">{appCopy("CGU", "Terms")}</a>
                {" · "}
                <a href="/support">Support</a>
              </p>
            </div>
          ) : (
            <div>
              <div className="ps-row">
                <a className="ps-btn ps-btn-primary" href="/api/tiktok/oauth/start">
                  {appCopy("Se connecter avec TikTok", "Connect with TikTok")}
                </a>
              </div>
              <p className="ps-muted" style={{ marginTop: 12 }}>
                {sandbox
                  ? appCopy(
                      "Sandbox TikTok : utilise @process.debloat.app. Déconnecte les autres comptes TikTok du navigateur avant.",
                      "TikTok Sandbox: use @process.debloat.app. Log out other TikTok accounts in the browser first."
                    )
                  : appCopy(
                      "OAuth officiel TikTok sur useprocess.xyz — multi-comptes supporté après connexion.",
                      "Official TikTok OAuth on useprocess.xyz — multi-account supported after connect."
                    )}
              </p>
            </div>
          )}
        </section>

        {creator || user ? (
          <section className="ps-panel">
            <h3>{appCopy("1b. Analytics (posts récents)", "1b. Analytics (recent posts)")}</h3>
            {videos.length ? (
              <>
                {videoTotals ? (
                  <p className="ps-muted">
                    {appCopy("Page", "Page")}: {videoTotals.views} {appCopy("vues", "views")} ·{" "}
                    {videoTotals.likes} likes · {videoTotals.comments}{" "}
                    {appCopy("commentaires", "comments")} · {videoTotals.shares}{" "}
                    {appCopy("partages", "shares")}
                  </p>
                ) : null}
                <div className="ps-packs" style={{ marginTop: 10 }}>
                  {videos.slice(0, 6).map((v) => (
                    <div key={v.id} className="ps-pack" style={{ cursor: "default" }}>
                      {v.cover_image_url ? (
                        <img src={v.cover_image_url} alt="" loading="lazy" />
                      ) : null}
                      <span>
                        <strong>{(v.title || v.video_description || v.id).slice(0, 48)}</strong>
                        <span className="ps-muted">
                          {v.view_count ?? 0} views · {v.like_count ?? 0} likes
                        </span>
                      </span>
                    </div>
                  ))}
                </div>
              </>
            ) : (
              <p className="ps-muted">
                {appCopy(
                  "Reconnecte avec les scopes video.list / stats pour voir les perfs (après review).",
                  "Reconnect with video.list / stats scopes to see performance (after review)."
                )}
              </p>
            )}
          </section>
        ) : null}

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
              disabled={Boolean(creator?.comment_disabled)}
            />
            <span>{appCopy("Désactiver les commentaires", "Turn off comments")}</span>
          </label>

          <label className="ps-toggle">
            <input
              type="checkbox"
              checked={duetOff}
              onChange={(e) => setDuetOff(e.target.checked)}
              disabled={Boolean(creator?.duet_disabled)}
            />
            <span>{appCopy("Désactiver Duet", "Turn off Duet")}</span>
          </label>

          <label className="ps-toggle">
            <input
              type="checkbox"
              checked={stitchOff}
              onChange={(e) => setStitchOff(e.target.checked)}
              disabled={Boolean(creator?.stitch_disabled)}
            />
            <span>{appCopy("Désactiver Stitch", "Turn off Stitch")}</span>
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
