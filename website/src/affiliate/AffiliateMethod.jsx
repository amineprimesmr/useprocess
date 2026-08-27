import { useCallback, useEffect, useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronDown, IconExternal, IconLink } from "./AffiliateIcons.jsx";
import { ClipperBonusLadder } from "./ClipperBonusLadder.jsx";
import { ViewBonusBoard, ViewBonusNote } from "./ViewBonusBoard.jsx";
import { navigateHash, readHashQuery } from "./affiliate-utils.js";
import { readMethodPace } from "./affiliate-onboarding-state.js";
import {
  FORMAT_SPECS,
  MANNY_TIKTOK_HANDLE,
  MANNY_TIKTOK_URL,
  START_SECTIONS,
  fillVars,
  paceFromHours,
  startSectionByQuery,
} from "./method-catalog.js";
import "./affiliate-method.css";

const METHOD_MODULE_KEY = "process.affiliate.method.module";

function copyPair(pair, vars) {
  if (!pair) return "";
  return fillVars(appCopy(pair.fr, pair.en), vars);
}

function copyText(fr, en, vars) {
  return fillVars(appCopy(fr, en), vars);
}

function readStoredModule() {
  try {
    return window.localStorage.getItem(METHOD_MODULE_KEY) || "";
  } catch {
    return "";
  }
}

function persistModule(id) {
  try {
    window.localStorage.setItem(METHOD_MODULE_KEY, id);
  } catch {
    /* private mode */
  }
}

function currentSectionFromHash() {
  const query = readHashQuery();
  if (query.m) return startSectionByQuery(query.m);
  const stored = readStoredModule();
  return stored ? startSectionByQuery(stored) : START_SECTIONS[0];
}

function SlideStrip({ slides }) {
  if (!slides?.length) return null;
  return (
    <ul className="af-md-slides">
      {slides.map((slide) => (
        <li key={slide.src}>
          <img src={slide.src} alt={appCopy(slide.fr, slide.en)} width={180} height={320} />
          <span>{appCopy(slide.fr, slide.en)}</span>
        </li>
      ))}
    </ul>
  );
}

function FormatCard({ spec, defaultOpen = false }) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <article className={`af-md-format${open ? " is-open" : ""}`}>
      <button type="button" className="af-md-format__head" onClick={() => setOpen((v) => !v)} aria-expanded={open}>
        <div>
          <strong>{appCopy(spec.name.fr, spec.name.en)}</strong>
          <span>{spec.canvas}</span>
        </div>
        <IconChevronDown />
      </button>
      {open ? (
        <div className="af-md-format__body">
          <p className="af-md-hook">“{appCopy(spec.hook.fr, spec.hook.en)}”</p>
          <p>{appCopy(spec.when.fr, spec.when.en)}</p>
          <SlideStrip slides={spec.slides} />
          <ol className="af-md-ol">
            {spec.structure.map((item) => (
              <li key={item.en}>{appCopy(item.fr, item.en)}</li>
            ))}
          </ol>
          <p className="af-md-caption">
            <span>{appCopy("Caption", "Caption")}</span>
            {appCopy(spec.caption.fr, spec.caption.en)}
          </p>
          <p className="af-md-fatal">{appCopy(spec.fatal.fr, spec.fatal.en)}</p>
        </div>
      ) : (
        <SlideStrip slides={spec.slides.slice(0, 3)} />
      )}
    </article>
  );
}

function MethodLinks({ items, vars }) {
  return (
    <ul className="af-md-links">
      {items.map((item) => {
        const href = item.hrefKey ? vars[item.hrefKey] : item.href;
        if (!href) return null;
        return (
          <li key={item.id}>
            <a href={href} target="_blank" rel="noopener noreferrer">
              {copyText(item.fr, item.en, vars)}
              <IconExternal />
            </a>
          </li>
        );
      })}
    </ul>
  );
}

export function MethodBlock({ block, vars, pace, onGoLinks, onGoFormats }) {
  if (block.type === "lead") {
    return <p className="af-md-lead">{copyText(block.fr, block.en, vars)}</p>;
  }

  if (block.type === "callout") {
    return <p className="af-md-callout">{copyText(block.fr, block.en, vars)}</p>;
  }

  if (block.type === "pace") {
    return (
      <p className="af-md-pace">
        {appCopy("Ton rythme :", "Your pace:")} <strong>{appCopy(pace.fr, pace.en)}</strong>
        {vars.accounts
          ? ` · ${appCopy(`${vars.accounts} compte(s)`, `${vars.accounts} account(s)`)}`
          : ""}
      </p>
    );
  }

  if (block.type === "links") {
    const list = <MethodLinks items={block.items} vars={vars} />;
    if (!block.title) return list;
    return (
      <section className="af-md-section">
        <h3>{copyPair(block.title, vars)}</h3>
        {list}
      </section>
    );
  }

  if (block.type === "section") {
    const paragraphs = copyText(block.fr, block.en, vars)
      .split(/\n\n+/)
      .map((part) => part.trim())
      .filter(Boolean);
    return (
      <section className="af-md-section">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        {paragraphs.map((part) => (
          <p key={part.slice(0, 48)}>{part}</p>
        ))}
      </section>
    );
  }

  if (block.type === "bullets") {
    return (
      <section className="af-md-section">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <ul className="af-md-ul">
          {block.items.map((item) => (
            <li key={item.en}>{copyPair(item, vars)}</li>
          ))}
        </ul>
      </section>
    );
  }

  if (block.type === "pay") {
    return (
      <section className="af-md-pay">
        <h3>{copyPair(block.title, vars)}</h3>
        <p className="af-md-pay__main">{copyText(block.fr, block.en, vars)}</p>
        {block.sub ? <p className="af-md-pay__sub">{copyText(block.sub.fr, block.sub.en, vars)}</p> : null}
      </section>
    );
  }

  if (block.type === "access") {
    const href = vars.linkUrl || `https://${vars.link}`;
    return (
      <section className="af-md-section">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <a className="af-md-access" href={href} target="_blank" rel="noopener noreferrer">
          {copyText(block.fr, block.en, vars)}
          <IconExternal />
        </a>
      </section>
    );
  }

  if (block.type === "ladder") {
    return (
      <section className="af-md-section">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <ClipperBonusLadder />
      </section>
    );
  }

  if (block.type === "bonus") {
    return (
      <div className="af-md-bonus">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <ViewBonusBoard
          variant="light"
          compact={Boolean(block.compact)}
          showEligibility={block.showEligibility !== false}
        />
        {block.hideNote ? null : <ViewBonusNote />}
      </div>
    );
  }

  if (block.type === "steps") {
    return (
      <section className="af-md-section">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <ol className="af-md-ol">
          {block.items.map((item) => (
            <li key={item.en}>{copyPair(item, vars)}</li>
          ))}
        </ol>
      </section>
    );
  }

  if (block.type === "dont") {
    return (
      <section className="af-md-section af-md-section--dont">
        {block.title ? <h3>{copyPair(block.title, vars)}</h3> : null}
        <ul className="af-md-ul">
          {block.items.map((item) => (
            <li key={item.en}>{copyPair(item, vars)}</li>
          ))}
        </ul>
      </section>
    );
  }

  if (block.type === "formats") {
    return (
      <div className="af-md-formats">
        <p className="af-md-ref">
          <a href={MANNY_TIKTOK_URL} target="_blank" rel="noopener noreferrer">
            {MANNY_TIKTOK_HANDLE}
            <IconExternal />
          </a>
        </p>
        {FORMAT_SPECS.map((spec) => (
          <FormatCard key={spec.id} spec={spec} />
        ))}
      </div>
    );
  }

  if (block.type === "shot") {
    const caption = copyText(block.fr, block.en, vars);
    return (
      <figure className={`af-md-shot${block.variant === "banner" ? " af-md-shot--banner" : ""}`}>
        <img src={block.src} alt={caption} />
        {block.hideCaption ? null : <figcaption>{caption}</figcaption>}
      </figure>
    );
  }

  if (block.type === "examples") {
    return (
      <ul className="af-md-examples">
        {block.items.map((item) => (
          <li key={item.format}>
            <img src={item.src} alt="" width={120} height={160} />
            <div>
              <strong>
                {appCopy("Format", "Format")} {item.format}
              </strong>
              <p className="af-md-hook">“{copyPair(item.hook, vars)}”</p>
              <p>{copyPair(item.why, vars)}</p>
            </div>
          </li>
        ))}
      </ul>
    );
  }

  if (block.type === "cta-links" && onGoLinks) {
    return (
      <button type="button" className="af-md-inline-link" onClick={onGoLinks}>
        <IconLink />
        {appCopy("Voir mon lien et mes stats", "See my link and stats")}
      </button>
    );
  }

  if (block.type === "cta-lab") {
    return (
      <button type="button" className="af-md-inline-link" onClick={() => navigateHash("slideshowlab")}>
        {appCopy("Ouvrir SlideshowLab", "Open SlideshowLab")}
      </button>
    );
  }

  if (block.type === "cta-formats" && onGoFormats) {
    return (
      <button type="button" className="af-md-inline-link" onClick={onGoFormats}>
        {appCopy("Ouvrir Format", "Open Format")}
      </button>
    );
  }

  return null;
}

export function AffiliateMethodPage({ linkUrl = "", primaryCode = "", onGoLinks, onGoFormats }) {
  const [section, setSection] = useState(() => currentSectionFromHash());
  const paceState = readMethodPace();
  const pace = paceFromHours(paceState.hoursPerDay);
  const vars = useMemo(
    () => ({
      link: linkUrl.replace(/^https:\/\//, "") || "useprocess.xyz/join/CODE",
      linkUrl,
      code: primaryCode || "CODE",
      posts: appCopy(pace.fr, pace.en),
      accounts: paceState.accountCount || "",
    }),
    [linkUrl, primaryCode, pace.fr, pace.en, paceState.accountCount]
  );

  const goSection = useCallback((next) => {
    setSection(next);
    persistModule(next.id);
    const hash = next.id === START_SECTIONS[0].id ? "methode" : `methode?m=${next.id}`;
    navigateHash(hash);
  }, []);

  useEffect(() => {
    const sync = () => setSection(currentSectionFromHash());
    window.addEventListener("hashchange", sync);
    return () => window.removeEventListener("hashchange", sync);
  }, []);

  useEffect(() => {
    persistModule(section.id);
    const query = readHashQuery();
    if (!query.m && section.id !== START_SECTIONS[0].id) {
      navigateHash(`methode?m=${section.id}`);
    }
  }, [section.id]);

  useEffect(() => {
    const active = document.querySelector(".af-md-menu__item.is-on");
    if (!active || typeof active.scrollIntoView !== "function") return;
    active.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" });
  }, [section.id]);

  return (
    <div className="af-md af-md-start">
      <nav className="af-md-menu" aria-label={appCopy("Démarrage", "Getting started")}>
        {START_SECTIONS.map((item) => (
          <button
            key={item.id}
            type="button"
            className={`af-md-menu__item${item.id === section.id ? " is-on" : ""}`}
            onClick={() => goSection(item)}
          >
            {copyPair(item.nav, vars)}
          </button>
        ))}
      </nav>

      <article className="af-md-page" key={section.id}>
        <h2>{copyPair(section.title, vars)}</h2>
        {section.blocks.map((block, i) => (
          <MethodBlock
            key={`${section.id}-${block.type}-${i}`}
            block={block}
            vars={vars}
            pace={pace}
            onGoLinks={onGoLinks}
            onGoFormats={onGoFormats}
          />
        ))}
      </article>
    </div>
  );
}
