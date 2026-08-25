import { useCallback, useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { appCopy } from "../features/app-copy.js";
import { IconCheck, IconCopy, IconExternal } from "./AffiliateIcons.jsx";
import {
  formatShortDate,
  navigateHash,
  readHashQuery,
  viewBonusUsdForViews,
} from "./affiliate-utils.js";
import {
  COPY_ACCOUNTS,
  FORMAT_LIBRARY,
  LIBRARY_CAPTURED_AT,
  collectionTotals,
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

function currentCollectionFromHash() {
  return libraryCollectionById(readHashQuery().f);
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
  const hook = appCopy(post.hook.fr, post.hook.en);
  const subject = appCopy(post.subject.fr, post.subject.en);

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
  const hook = appCopy(post.hook.fr, post.hook.en);

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
        <p className="af-lib-kicker">{appCopy("Nouveau format", "New format")}</p>
        <h3 id="af-copy-title">{appCopy("Comptes à copier", "Accounts to copy")}</h3>
        <p>
          {appCopy(
            "Ce format arrache tout. Ouvre le compte, copie la structure — pas les fichiers.",
            "This format is crushing it. Open the account, copy the structure — not the files."
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

export function AffiliateFormatsPage() {
  const reduceMotion = useReducedMotion();
  const [collection, setCollection] = useState(() => currentCollectionFromHash());
  const [openId, setOpenId] = useState("");

  const ranked = useMemo(() => postsByViews(collection.posts), [collection]);
  const totals = useMemo(() => collectionTotals(collection), [collection]);
  const spec = FORMAT_SPECS.find((item) => item.id === collection.specId);
  const openPost = ranked.find((post) => post.id === openId);
  const openRank = openPost ? ranked.findIndex((post) => post.id === openPost.id) + 1 : 0;

  const selectCollection = useCallback((next) => {
    setCollection(next);
    setOpenId("");
    navigateHash(next.id === FORMAT_LIBRARY[0].id ? "formats" : `formats?f=${next.id}`);
  }, []);

  useEffect(() => {
    const sync = () => setCollection(currentCollectionFromHash());
    window.addEventListener("hashchange", sync);
    return () => window.removeEventListener("hashchange", sync);
  }, []);

  return (
    <div className="af-lib">
      <header className="af-lib-head">
        <p className="af-lib-kicker">{appCopy("Référence live", "Live reference")}</p>
        <h2>{appCopy("Bibliothèque de formats", "Format library")}</h2>
        <p className="af-lib-lead">
          {appCopy(
            "Les posts live, triés par vues. Tu copies la structure, pas les fichiers.",
            "Live posts, ranked by views. Copy the structure, not the files."
          )}
        </p>
      </header>

      <CopyAccountsSection />

      <nav className="af-lib-tabs" aria-label={appCopy("Formats", "Formats")}>
        {FORMAT_LIBRARY.map((item) => {
          const count = item.posts.length;
          const on = item.id === collection.id;
          return (
            <button
              key={item.id}
              type="button"
              className={`af-lib-tab${on ? " is-on" : ""}`}
              onClick={() => selectCollection(item)}
            >
              {appCopy(item.name.fr, item.name.en)}
              <span>{count}</span>
            </button>
          );
        })}
      </nav>

      <section className="af-lib-summary">
        <div>
          <h3>{appCopy(collection.name.fr, collection.name.en)}</h3>
          <p>{appCopy(collection.formula.fr, collection.formula.en)}</p>
        </div>
        {totals.posts > 0 ? (
          <dl>
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
            <div>
              <dt>{appCopy("Posts", "Posts")}</dt>
              <dd>{totals.posts}</dd>
            </div>
          </dl>
        ) : null}
      </section>

      {spec ? (
        <p className="af-lib-spec">
          {spec.canvas} · {appCopy(spec.when.fr, spec.when.en)}
        </p>
      ) : null}

      {ranked.length === 0 ? (
        <div className="af-lib-empty">
          <strong>{appCopy("Pas encore de posts dans ce format.", "No posts in this format yet.")}</strong>
          <p>
            {appCopy(
              "Envoie les liens TikTok — on les range ici, du plus vu au moins vu.",
              "Send the TikTok links — we'll file them here, most-viewed first."
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
              featured={index === 0}
              delay={reduceMotion ? 0 : 0.04 + index * 0.06}
              reduceMotion={reduceMotion}
              onOpen={(item) => setOpenId(item.id)}
            />
          ))}
        </div>
      )}

      <p className="af-lib-foot">
        {appCopy(
          `Stats capturées le ${formatShortDate(new Date(`${LIBRARY_CAPTURED_AT}T12:00:00Z`).getTime())}. Covers = slide 1 de chaque carousel.`,
          `Stats captured ${formatShortDate(new Date(`${LIBRARY_CAPTURED_AT}T12:00:00Z`).getTime())}. Covers = slide 1 of each carousel.`
        )}
      </p>

      <AnimatePresence>
        {openPost ? <PostModal post={openPost} rank={openRank} onClose={() => setOpenId("")} /> : null}
      </AnimatePresence>
    </div>
  );
}
