import { useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconCheck, IconCopy, IconExternal } from "./AffiliateIcons.jsx";
import { US_AFTER, US_AGENT_PROMPT, US_BEFORE, US_LINKS } from "./us-guide.js";
import "./affiliate-us.css";

function UsFlag() {
  return (
    <svg className="af-us-flag" viewBox="0 0 60 32" aria-hidden="true">
      <rect width="60" height="32" fill="#b31942" />
      <rect y="2.46" width="60" height="2.46" fill="#fff" />
      <rect y="7.38" width="60" height="2.46" fill="#fff" />
      <rect y="12.31" width="60" height="2.46" fill="#fff" />
      <rect y="17.23" width="60" height="2.46" fill="#fff" />
      <rect y="22.15" width="60" height="2.46" fill="#fff" />
      <rect y="27.08" width="60" height="2.46" fill="#fff" />
      <rect width="24" height="17.23" fill="#0a3161" />
    </svg>
  );
}

function CopyPrompt({ value }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      /* ignore */
    }
  }

  return (
    <div className="af-us-prompt">
      <div className="af-us-prompt__bar">
        <span>{appCopy("Prompt Cursor / Claude Code", "Cursor / Claude Code prompt")}</span>
        <button type="button" onClick={copy}>
          {copied ? <IconCheck /> : <IconCopy />}
          {copied ? appCopy("Copié", "Copied") : appCopy("Copier le prompt", "Copy prompt")}
        </button>
      </div>
      <pre>{value}</pre>
    </div>
  );
}

function Ext({ href, children }) {
  return (
    <a className="af-us-link" href={href} target="_blank" rel="noopener noreferrer">
      {children}
      <IconExternal />
    </a>
  );
}

export function AffiliateUsPage() {
  const prompt = appCopy(US_AGENT_PROMPT.fr, US_AGENT_PROMPT.en);

  return (
    <div className="af-us">
      <header className="af-us-hero">
        <UsFlag />
        <h2>{appCopy("Poster aux États-Unis", "Post in the United States")}</h2>
        <p>
          {appCopy(
            "TikTok lit la langue, la région, le fuseau, le GPS et l'IP. Un leak FR brûle le compte. Toi tu prépares le téléphone. Cursor fait le serveur.",
            "TikTok reads language, region, timezone, GPS, and IP. One FR leak burns the account. You prep the phone. Cursor builds the server."
          )}
        </p>
      </header>

      <p className="af-us-gold">
        {appCopy(
          "Règle d'or : VPN Outline ON avant d'ouvrir TikTok. Une seule ouverture sans VPN peut shadow-ban le compte.",
          "Golden rule: Outline VPN ON before opening TikTok. One open without VPN can shadow-ban the account."
        )}
      </p>

      <section className="af-us-block">
        <p className="af-us-kicker">{appCopy("Étape 1 — toi, avant Cursor", "Step 1 — you, before Cursor")}</p>
        <h3>{appCopy("Fais ça à la main. L'IA ne peut pas.", "Do this yourself. The AI cannot.")}</h3>
        <p>
          {appCopy(
            "Tant que cette liste n'est pas verte, n'envoie pas le prompt. Cursor ne reset pas un iPhone et ne crée pas ton Apple ID.",
            "Until this list is done, don't send the prompt. Cursor can't factory-reset an iPhone or create your Apple ID."
          )}
        </p>
        <ol className="af-us-list">
          {US_BEFORE.map((item) => (
            <li key={item.en}>{appCopy(item.fr, item.en)}</li>
          ))}
        </ol>
        <div className="af-us-links">
          <Ext href={US_LINKS.hetzner}>hetzner.com/cloud</Ext>
          <Ext href={US_LINKS.hetznerConsole}>{appCopy("Console + token API", "Console + API token")}</Ext>
          <Ext href={US_LINKS.appleId}>appleid.apple.com</Ext>
        </div>
      </section>

      <section className="af-us-block">
        <p className="af-us-kicker">{appCopy("Étape 2 — Cursor / Claude Code", "Step 2 — Cursor / Claude Code")}</p>
        <h3>{appCopy("Colle ce prompt. Il fait le serveur.", "Paste this prompt. It builds the server.")}</h3>
        <p>
          {appCopy(
            "Ouvre Cursor (ou Claude Code) sur le Mac / PC. Nouveau chat. Colle le prompt. Donne le token Hetzner si on te le demande. À la fin tu récupères un JSON Outline.",
            "Open Cursor (or Claude Code) on the Mac / PC. New chat. Paste the prompt. Give the Hetzner token if asked. At the end you get an Outline JSON."
          )}
        </p>
        <CopyPrompt value={prompt} />
      </section>

      <section className="af-us-block">
        <p className="af-us-kicker">{appCopy("Étape 3 — après le JSON", "Step 3 — after the JSON")}</p>
        <h3>{appCopy("VPN sur le téléphone, puis TikTok.", "VPN on the phone, then TikTok.")}</h3>
        <ol className="af-us-list">
          {US_AFTER.map((item) => (
            <li key={item.en}>{appCopy(item.fr, item.en)}</li>
          ))}
        </ol>
        <div className="af-us-links">
          <Ext href={US_LINKS.outlineGetStarted}>Outline Manager</Ext>
          <Ext href={US_LINKS.outlineIos}>Outline iOS</Ext>
          <Ext href={US_LINKS.outlineAndroid}>Outline Android</Ext>
          <Ext href={US_LINKS.ipCheck}>whatismyipaddress.com</Ext>
          <Ext href={US_LINKS.textnow}>TextNow</Ext>
        </div>
        <p className="af-us-warn">
          {appCopy(
            "Si l'IP n'est pas USA, n'ouvre pas TikTok. Corrige d'abord. Un leak FR suffit.",
            "If the IP isn't USA, don't open TikTok. Fix it first. One FR leak is enough."
          )}
        </p>
      </section>
    </div>
  );
}
