import { useCallback, useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { appCopy } from "../features/app-copy.js";
import { affiliateApi, getAuthToken } from "../features/firebase-client.js";
import { IconCheck, IconChevronLeft, IconCopy, IconExternal, IconTikTok } from "./AffiliateIcons.jsx";
import {
  formatShortDate,
  navigateHash,
  readHashQuery,
  viewBonusUsdForViews,
} from "./affiliate-utils.js";
import {
  COPY_ACCOUNTS,
  LIBRARY_CAPTURED_AT,
  collectionCover,
  collectionTotals,
  collectionsByViews,
  formatCompactCount,
  libraryCollectionById,
  postsByViews,
} from "./format-library.js";
import { FORMAT_SPECS } from "./method-catalog.js";
import "./affiliate-formats.css";

function IconViews(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" {...props}>
      <path d="M2.5 12s3.5-7 9.5-7 9.5 7 9.5 7-3.5 7-9.5 7-9.5-7-9.5-7z" />
      <circle cx="12" cy="12" r="2.6" />
    </svg>
  );
}

function IconHeart(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" {...props}>
      <path d="M12 20s-7-4.4-9.2-8.2C1 8.8 2.6 5.5 6 5.2 8 5 9.8 6.2 12 8.4 14.2 6.2 16 5 18 5.2c3.4.3 5 3.6 3.2 6.6C19 15.6 12 20 12 20z" />
    </svg>
  );
}

function IconComment(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" {...props}>
      <path d="M5 16.5V7.8A2.8 2.8 0 0 1 7.8 5h8.4A2.8 2.8 0 0 1 19 7.8v5.2A2.8 2.8 0 0 1 16.2 16H9l-4 3.2z" />
    </svg>
  );
}

function IconShare(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" {...props}>
      <circle cx="18" cy="6" r="2.4" />
      <circle cx="6" cy="12" r="2.4" />
      <circle cx="18" cy="18" r="2.4" />
      <path d="M8.2 11.1l7.5-3.2M8.2 12.9l7.5 3.2" />
    </svg>
  );
}

function IconSave(props) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" {...props}>
      <path d="M7 4h10a1 1 0 0 1 1 1v16l-6-3.2L6 21V5a1 1 0 0 1 1-1z" />
    </svg>
  );
}

function processViewBonus(post) {
  if (!String(post?.url || "").includes("mannyprcs")) return 0;
  return viewBonusUsdForViews(post.views);
}

function currentCollectionFromHash(collections) {
  const id = readHashQuery().f;
  if (!id) return null;
  return collections.find((item) => item.id === id) || libraryCollectionById(id);
}

function toCollection(row) {
  if (!row) return null;
  return {
    ...row,
    specId: row.specId || row.spec?.id || "",
    name: row.name || { fr: "", en: "" },
    formula: row.formula || { fr: "", en: "" },
    posts: Array.isArray(row.posts) ? row.posts : [],
  };
}

function LibraryDialog({ title, children, onClose }) {
  return (
    <div className="af-lib-dialog" role="dialog" aria-modal="true">
      <button type="button" className="af-lib-dialog__scrim" aria-label={appCopy("Fermer", "Close")} onClick={onClose} />
      <div className="af-lib-dialog__card">
        <h3>{title}</h3>
        {children}
      </div>
    </div>
  );
}

function Stat({ icon: Icon, value, label }) {
  return (
    <div className="af-lib-stat">
      <Icon />
      <strong>{formatCompactCount(value)}</strong>
      <span>{label}</span>
    </div>
  );
}

function PostCard({ post, rank, featured = false, delay = 0, reduceMotion, onOpen }) {
  const bonus = processViewBonus(post);
  const hook = appCopy(post.hook?.fr || post.hook || "", post.hook?.en || post.hook || "");
  const subject = appCopy(post.subject?.fr || post.subject || "", post.subject?.en || post.subject || "");

  return (
    <motion.button
      type="button"
      className={`af-lib-card${featured ? " is-featured" : ""}`}
      onClick={() => onOpen(post)}
      initial={reduceMotion ? false : { opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.38, delay, ease: [0.22, 1, 0.36, 1] }}
      whileHover={reduceMotion ? undefined : { y: -4 }}
      whileTap={reduceMotion ? undefined : { scale: 0.985 }}
    >
      <div className="af-lib-card__media">
        <img src={post.cover} alt={hook} width={540} height={720} decoding="async" />
        <span className="af-lib-rank">#{String(rank).padStart(2, "0")}</span>
        {bonus > 0 ? <span className="af-lib-bonus">+${bonus}</span> : null}
        <div className="af-lib-card__views">
          <IconViews />
          {formatCompactCount(post.views)}
        </div>
      </div>
      <div className="af-lib-card__body">
        <p className="af-lib-card__subject">{subject}</p>
        <h3>{hook}</h3>
        {featured ? (
          <p className="af-lib-card__hero-views">
            {formatCompactCount(post.views)} {appCopy("vues", "views")}
          </p>
        ) : null}
        <ul className="af-lib-metrics">
          <li>
            <IconHeart />
            {formatCompactCount(post.likes)}
          </li>
          <li>
            <IconComment />
            {formatCompactCount(post.comments)}
          </li>
          <li>
            <IconShare />
            {formatCompactCount(post.shares)}
          </li>
          <li>
            <IconSave />
            {formatCompactCount(post.saves)}
          </li>
        </ul>
      </div>
    </motion.button>
  );
}

function PostModal({ post, rank, onClose }) {
  const reduceMotion = useReducedMotion();
  const bonus = processViewBonus(post);
  const hook = appCopy(post.hook?.fr || post.hook || "", post.hook?.en || post.hook || "");

  useEffect(() => {
    function onKey(event) {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

  return (
    <motion.div
      className="af-lib-modal"
      role="dialog"
      aria-modal="true"
      aria-label={hook}
      initial={reduceMotion ? false : { opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={reduceMotion ? undefined : { opacity: 0 }}
      onClick={onClose}
    >
      <motion.div
        className="af-lib-modal__panel"
        initial={reduceMotion ? false : { opacity: 0, y: 24, scale: 0.98 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={reduceMotion ? undefined : { opacity: 0, y: 16, scale: 0.98 }}
        transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }}
        onClick={(event) => event.stopPropagation()}
      >
        <button type="button" className="af-lib-modal__close" onClick={onClose} aria-label={appCopy("Fermer", "Close")}>
          ×
        </button>
        <div className="af-lib-modal__shot">
          <img src={post.cover} alt={hook} />
        </div>
        <div className="af-lib-modal__info">
          <p className="af-lib-kicker">
            #{String(rank).padStart(2, "0")} · {appCopy(post.subject.fr, post.subject.en)}
          </p>
          <h2>{hook}</h2>
          <p className="af-lib-caption">{post.caption}</p>
          <div className="af-lib-modal__stats">
            <Stat icon={IconViews} value={post.views} label={appCopy("Vues", "Views")} />
            <Stat icon={IconHeart} value={post.likes} label={appCopy("Likes", "Likes")} />
            <Stat icon={IconComment} value={post.comments} label={appCopy("Coms", "Comments")} />
            <Stat icon={IconShare} value={post.shares} label={appCopy("Partages", "Shares")} />
            <Stat icon={IconSave} value={post.saves} label={appCopy("Saves", "Saves")} />
          </div>
          <p className="af-lib-meta">
            {post.slides} {appCopy("slides", "slides")} · {formatShortDate(post.createdAt * 1000)}
            {bonus > 0 ? ` · $${bonus} ${appCopy("primes vues", "view bonus")}` : ""}
          </p>
          <a className="af-lib-open" href={post.url} target="_blank" rel="noopener noreferrer">
            {appCopy("Ouvrir sur TikTok", "Open on TikTok")}
            <IconExternal />
          </a>
        </div>
      </motion.div>
    </motion.div>
  );
}

function CopyHandleButton({ handle }) {
  const [copied, setCopied] = useState(false);
  const text = `@${handle}`;

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      /* ignore */
    }
  }

  return (
    <button type="button" className={`af-copy-btn${copied ? " is-copied" : ""}`} onClick={copy}>
      {copied ? <IconCheck /> : <IconCopy />}
      {copied ? appCopy("Copié", "Copied") : appCopy(`Copier ${text}`, `Copy ${text}`)}
    </button>
  );
}

function CopyAccountCard({ account }) {
  return (
    <article className="af-copy-card">
      <header className="af-copy-card__head">
        <img src={account.avatar} alt="" width={56} height={56} />
        <div>
          <p className="af-copy-card__name">{account.nickname}</p>
          <p className="af-copy-card__handle">@{account.handle}</p>
        </div>
        <p className="af-copy-card__stats">
          <strong>{formatCompactCount(account.followers)}</strong> {appCopy("abonnés", "followers")}
          <span>·</span>
          <strong>{formatCompactCount(account.likes)}</strong> {appCopy("likes", "likes")}
        </p>
      </header>
      <p className="af-copy-card__formula">{appCopy(account.formula.fr, account.formula.en)}</p>
      <div className="af-copy-mosaic">
        {account.posts.map((post) => (
          <a
            key={post.id}
            href={post.url}
            target="_blank"
            rel="noopener noreferrer"
            className="af-copy-mosaic__cell"
          >
            <img src={post.cover} alt={appCopy(post.hook.fr, post.hook.en)} />
            <span>{formatCompactCount(post.views)}</span>
          </a>
        ))}
      </div>
      <div className="af-copy-card__actions">
        <CopyHandleButton handle={account.handle} />
        <a className="af-copy-open" href={account.url} target="_blank" rel="noopener noreferrer">
          {appCopy("Ouvrir le compte", "Open account")}
          <IconExternal />
        </a>
      </div>
    </article>
  );
}

function CopyAccountsSection() {
  return (
    <section className="af-copy" aria-labelledby="af-copy-title">
      <div className="af-copy__intro">
        <p className="af-lib-kicker">{appCopy("Ensuite", "Next")}</p>
        <h3 id="af-copy-title">{appCopy("Comptes à copier", "Accounts to copy")}</h3>
        <p>
          {appCopy(
            "Ouvre le compte, copie la structure — pas les fichiers.",
            "Open the account, copy the structure — not the files."
          )}
        </p>
      </div>
      <div className="af-copy-grid">
        {COPY_ACCOUNTS.map((account) => (
          <CopyAccountCard key={account.handle} account={account} />
        ))}
      </div>
    </section>
  );
}

function formatCoverSrc(collection) {
  const live = collectionCover(collection);
  if (live) return live;
  return FORMAT_SPECS.find((item) => item.id === collection.specId)?.slides?.[0]?.src || "";
}

function FormatShelfCard({ collection, delay, reduceMotion, onOpen }) {
  const totals = collectionTotals(collection);
  const cover = formatCoverSrc(collection);
  const empty = totals.posts === 0;
  const soon = empty && collection.official !== false;
  const name = appCopy(collection.name.fr, collection.name.en);

  return (
    <motion.button
      type="button"
      className={`af-shelf-card${empty ? " is-empty" : ""}`}
      aria-label={name}
      onClick={() => onOpen(collection)}
      initial={reduceMotion ? false : { opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.36, delay, ease: [0.22, 1, 0.36, 1] }}
      whileHover={reduceMotion ? undefined : { y: -4 }}
      whileTap={reduceMotion ? undefined : { scale: 0.985 }}
    >
      {cover ? <img src={cover} alt="" width={540} height={720} decoding="async" /> : <span className="af-shelf-card__blank" />}
      {soon ? <span className="af-shelf-soon">{appCopy("Bientôt", "Soon")}</span> : empty ? <span className="af-shelf-soon">{appCopy("Nouveau", "New")}</span> : null}
      <div className="af-shelf-card__meta">
        <strong>{name}</strong>
        {empty ? null : <span>{formatCompactCount(totals.views)}</span>}
      </div>
    </motion.button>
  );
}

export function AffiliateFormatsPage({ user }) {
  const reduceMotion = useReducedMotion();
  const seedShelf = useMemo(() => collectionsByViews(), []);
  const [formats, setFormats] = useState(() => seedShelf.map(toCollection));
  const [specs, setSpecs] = useState(FORMAT_SPECS);
  const [collection, setCollection] = useState(() => currentCollectionFromHash(seedShelf));
  const [openId, setOpenId] = useState("");
  const [dialog, setDialog] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [tiktokUrl, setTiktokUrl] = useState("");
  const [tiktokFormat, setTiktokFormat] = useState("");
  const [nameFr, setNameFr] = useState("");
  const [nameEn, setNameEn] = useState("");
  const [formulaFr, setFormulaFr] = useState("");
  const [formulaEn, setFormulaEn] = useState("");
  const [specId, setSpecId] = useState("");

  const applyCatalog = useCallback((rows, nextSpecs) => {
    const next = (rows || []).map(toCollection);
    setFormats(next);
    if (nextSpecs?.length) setSpecs(nextSpecs);
    setCollection((cur) => {
      const id = cur?.id || readHashQuery().f;
      if (!id) return null;
      return next.find((item) => item.id === id) || null;
    });
  }, []);

  const load = useCallback(async () => {
    if (!user) return;
    try {
      const token = await getAuthToken(user);
      const data = await affiliateApi("affiliateLibrary", {
        token,
        body: { action: "list" },
        timeoutMs: 15000,
      });
      applyCatalog(data.formats, data.specs);
    } catch (err) {
      console.warn("[tiktoks]", err);
    }
  }, [user, applyCatalog]);

  useEffect(() => {
    void load();
  }, [load]);

  const ranked = useMemo(() => (collection ? postsByViews(collection.posts) : []), [collection]);
  const totals = useMemo(() => (collection ? collectionTotals(collection) : null), [collection]);
  const spec =
    (collection && (collection.spec || specs.find((item) => item.id === collection.specId))) ||
    (collection ? FORMAT_SPECS.find((item) => item.id === collection.specId) : null);
  const openPost = ranked.find((post) => post.id === openId);
  const openRank = openPost ? ranked.findIndex((post) => post.id === openPost.id) + 1 : 0;

  const openCollection = useCallback((next) => {
    setCollection(next);
    setOpenId("");
    navigateHash(`tiktoks?f=${next.id}`);
  }, []);

  const goLibrary = useCallback(() => {
    setCollection(null);
    setOpenId("");
    navigateHash("tiktoks");
  }, []);

  useEffect(() => {
    const sync = () => setCollection(currentCollectionFromHash(formats));
    window.addEventListener("hashchange", sync);
    return () => window.removeEventListener("hashchange", sync);
  }, [formats]);

  async function callLibrary(body) {
    if (!user) throw new Error("UNAUTHORIZED");
    const token = await getAuthToken(user);
    return affiliateApi("affiliateLibrary", { token, body, timeoutMs: 20000 });
  }

  async function onAddTikTok(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      const data = await callLibrary({
        action: "addTikTok",
        url: tiktokUrl,
        formatId: tiktokFormat || collection?.id,
      });
      applyCatalog(data.formats, data.specs);
      setTiktokUrl("");
      setDialog("");
    } catch (err) {
      setError(
        appCopy(
          "Impossible d’ajouter ce TikTok. Vérifie le lien public.",
          "Couldn't add that TikTok. Check the public link."
        )
      );
    } finally {
      setBusy(false);
    }
  }

  async function onCreateFormat(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      const data = await callLibrary({
        action: "createFormat",
        nameFr,
        nameEn: nameEn || nameFr,
        formulaFr,
        formulaEn: formulaEn || formulaFr,
        specId,
      });
      applyCatalog(data.formats, data.specs);
      setNameFr("");
      setNameEn("");
      setFormulaFr("");
      setFormulaEn("");
      setSpecId("");
      setDialog("");
      if (data.id) {
        const created = (data.formats || []).map(toCollection).find((item) => item.id === data.id);
        if (created) openCollection(created);
      }
    } catch (err) {
      setError(appCopy("Impossible de créer ce format.", "Couldn't create that format."));
    } finally {
      setBusy(false);
    }
  }

  const composer = (
    <div className="af-lib-actions">
      <button
        type="button"
        className="af-lib-add"
        onClick={() => {
          setError("");
          setTiktokFormat(collection?.id || formats[0]?.id || "");
          setDialog("tiktok");
        }}
      >
        {appCopy("Ajouter un TikTok", "Add a TikTok")}
      </button>
      <button
        type="button"
        className="af-lib-add is-ghost"
        onClick={() => {
          setError("");
          setDialog("format");
        }}
      >
        {appCopy("Nouveau format", "New format")}
      </button>
    </div>
  );

  const dialogs = (
    <>
      {dialog === "tiktok" ? (
        <LibraryDialog title={appCopy("Ajouter un TikTok", "Add a TikTok")} onClose={() => setDialog("")}>
          <form className="af-lib-form" onSubmit={onAddTikTok}>
            <label>
              {appCopy("Lien TikTok public", "Public TikTok link")}
              <input
                className="af-lib-input"
                value={tiktokUrl}
                onChange={(event) => setTiktokUrl(event.target.value)}
                placeholder="https://www.tiktok.com/@compte/photo/…"
                required
              />
            </label>
            <label>
              {appCopy("Format", "Format")}
              <select
                className="af-lib-input"
                value={tiktokFormat || collection?.id || ""}
                onChange={(event) => setTiktokFormat(event.target.value)}
                required
              >
                {formats.map((item) => (
                  <option key={item.id} value={item.id}>
                    {appCopy(item.name.fr, item.name.en)}
                  </option>
                ))}
              </select>
            </label>
            {error ? <p className="af-lib-form-error">{error}</p> : null}
            <div className="af-lib-form-actions">
              <button type="button" className="af-lib-add is-ghost" onClick={() => setDialog("")}>
                {appCopy("Annuler", "Cancel")}
              </button>
              <button type="submit" className="af-lib-add" disabled={busy}>
                {busy ? appCopy("Ajout…", "Adding…") : appCopy("Ajouter", "Add")}
              </button>
            </div>
          </form>
        </LibraryDialog>
      ) : null}
      {dialog === "format" ? (
        <LibraryDialog title={appCopy("Nouveau format", "New format")} onClose={() => setDialog("")}>
          <form className="af-lib-form" onSubmit={onCreateFormat}>
            <label>
              {appCopy("Nom (FR)", "Name (FR)")}
              <input className="af-lib-input" value={nameFr} onChange={(event) => setNameFr(event.target.value)} required />
            </label>
            <label>
              {appCopy("Nom (EN)", "Name (EN)")}
              <input className="af-lib-input" value={nameEn} onChange={(event) => setNameEn(event.target.value)} />
            </label>
            <label>
              {appCopy("Formule / hook (FR)", "Formula / hook (FR)")}
              <textarea className="af-lib-input" rows={2} value={formulaFr} onChange={(event) => setFormulaFr(event.target.value)} />
            </label>
            <label>
              {appCopy("Formule / hook (EN)", "Formula / hook (EN)")}
              <textarea className="af-lib-input" rows={2} value={formulaEn} onChange={(event) => setFormulaEn(event.target.value)} />
            </label>
            <label>
              {appCopy("Structure officielle (optionnel)", "Official structure (optional)")}
              <select className="af-lib-input" value={specId} onChange={(event) => setSpecId(event.target.value)}>
                <option value="">{appCopy("Aucune", "None")}</option>
                {specs.map((item) => (
                  <option key={item.id} value={item.id}>
                    {appCopy(item.name.fr, item.name.en)}
                  </option>
                ))}
              </select>
            </label>
            {error ? <p className="af-lib-form-error">{error}</p> : null}
            <div className="af-lib-form-actions">
              <button type="button" className="af-lib-add is-ghost" onClick={() => setDialog("")}>
                {appCopy("Annuler", "Cancel")}
              </button>
              <button type="submit" className="af-lib-add" disabled={busy}>
                {busy ? appCopy("Création…", "Creating…") : appCopy("Créer", "Create")}
              </button>
            </div>
          </form>
        </LibraryDialog>
      ) : null}
    </>
  );

  if (!collection) {
    return (
      <div className="af-lib">
        <header className="af-lib-head">
          <p className="af-lib-kicker">{appCopy("Bibliothèque", "Library")}</p>
          <h2>
            <IconTikTok />
            {appCopy("Tiktoks", "Tiktoks")}
          </h2>
          <p className="af-lib-lead">
            {appCopy(
              "Tous les formats Process, plus ceux que les clippers ajoutent. Colle un TikTok, crée un format — le MCP les voit tous.",
              "Every Process format, plus the ones clippers add. Paste a TikTok, create a format — MCP sees them all."
            )}
          </p>
        </header>
        {composer}
        <div className="af-shelf">
          {formats.map((item, index) => (
            <FormatShelfCard
              key={item.id}
              collection={item}
              delay={reduceMotion ? 0 : 0.04 + index * 0.05}
              reduceMotion={reduceMotion}
              onOpen={openCollection}
            />
          ))}
        </div>
        <CopyAccountsSection />
        {dialogs}
      </div>
    );
  }

  return (
    <div className="af-lib">
      <button type="button" className="af-lib-back" onClick={goLibrary}>
        <IconChevronLeft />
        {appCopy("Tous les Tiktoks", "All Tiktoks")}
      </button>

      <header className="af-lib-head">
        <h2>{appCopy(collection.name.fr, collection.name.en)}</h2>
        <p className="af-lib-lead">{appCopy(collection.formula.fr, collection.formula.en)}</p>
        {collection.official === false && collection.createdByName ? (
          <p className="af-lib-by">
            {appCopy("Ajouté par", "Added by")} {collection.createdByName}
          </p>
        ) : null}
      </header>
      {composer}

      {totals?.posts > 0 ? (
        <dl className="af-lib-stats">
          <div>
            <dt>{appCopy("Vues", "Views")}</dt>
            <dd>{formatCompactCount(totals.views)}</dd>
          </div>
          <div>
            <dt>{appCopy("Likes", "Likes")}</dt>
            <dd>{formatCompactCount(totals.likes)}</dd>
          </div>
          <div>
            <dt>{appCopy("Saves", "Saves")}</dt>
            <dd>{formatCompactCount(totals.saves)}</dd>
          </div>
        </dl>
      ) : null}

      {spec ? (
        <p className="af-lib-spec">
          {spec.canvas} · {appCopy(spec.when?.fr || spec.when, spec.when?.en || spec.when)}
        </p>
      ) : null}

      {ranked.length === 0 ? (
        <div className="af-lib-empty">
          <strong>{appCopy("Pas encore de TikToks dans ce format.", "No TikToks in this format yet.")}</strong>
          <p>
            {appCopy(
              "Colle un lien public — il arrive ici, et le MCP le voit tout de suite.",
              "Paste a public link — it lands here, and MCP sees it immediately."
            )}
          </p>
        </div>
      ) : (
        <div className="af-lib-grid">
          {ranked.map((post, index) => (
            <PostCard
              key={post.id}
              post={post}
              rank={index + 1}
              featured={false}
              delay={reduceMotion ? 0 : 0.04 + index * 0.05}
              reduceMotion={reduceMotion}
              onOpen={(item) => setOpenId(item.id)}
            />
          ))}
        </div>
      )}

      <p className="af-lib-foot">
        {appCopy(
          `Stats officielles capturées le ${formatShortDate(new Date(`${LIBRARY_CAPTURED_AT}T12:00:00Z`).getTime())}. Les ajouts clippers s’affichent en live.`,
          `Official stats captured ${formatShortDate(new Date(`${LIBRARY_CAPTURED_AT}T12:00:00Z`).getTime())}. Clipper additions show live.`
        )}
      </p>

      <AnimatePresence>
        {openPost ? <PostModal post={openPost} rank={openRank} onClose={() => setOpenId("")} /> : null}
      </AnimatePresence>
      {dialogs}
    </div>
  );
}
