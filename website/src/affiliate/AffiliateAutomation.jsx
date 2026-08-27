import { useEffect, useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { SuccessActionButton, playConfirm } from "./action-feedback.jsx";
import "./affiliate-automation.css";

const LOGO = "/assets/affiliate/scrollshow-logo.png";
const CLIENTS = [
  { id: "claude", label: "Claude", logo: "/assets/affiliate/ai/claude.png", bg: "#d97e5b" },
  { id: "claude-code", label: "Claude Code", logo: "/assets/affiliate/ai/claude-code.png", bg: "#000" },
  { id: "cursor", label: "Cursor", logo: "/assets/affiliate/ai/cursor.png", bg: "#000" },
  { id: "codex", label: "Codex", logo: "/assets/affiliate/ai/codex.png", bg: "#fff" },
];

const PLATFORMS = [
  { id: "tiktok", name: "TikTok", live: true },
  { id: "instagram", name: "Instagram", live: false },
  { id: "facebook", name: "Facebook", live: false },
  { id: "x", name: "X", live: false },
];

const TABS = [
  { id: "calendrier", fr: "Calendrier", en: "Calendar" },
  { id: "connexions", fr: "Connexions", en: "Connect" },
  { id: "mcp", fr: "MCP", en: "MCP" },
];

const DOW_FR = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];
const DOW_EN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function CopyIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
      <rect x="9" y="9" width="11" height="11" rx="2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M5 15V7a2 2 0 0 1 2-2h8" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M5 12.5 9.5 17 19 7.5" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ExternalIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M14 5h5v5M19 5 10 14" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M17 13v5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h5" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

function ymd(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function previewPosts() {
  const today = new Date();
  const at = (offset) => {
    const date = new Date(today);
    date.setDate(date.getDate() + offset);
    return ymd(date);
  };
  return [
    { id: "soon-1", date: at(0), caption: "Guide 72h — avant / après", status: "scheduled" },
    { id: "soon-2", date: at(1), caption: "Glow-up · 7 jours", status: "scheduled" },
    { id: "soon-3", date: at(2), caption: "Foods qui bloat", status: "scheduled" },
    { id: "soon-4", date: at(4), caption: "Scan visage Process", status: "draft" },
  ];
}

function fmt(n) {
  return Number(n || 0).toLocaleString();
}

function emptyStudio(dashboard) {
  const accounts = dashboard?.tiktok?.accounts || [];
  return {
    apiReady: Boolean(dashboard?.tiktok?.apiReady),
    accounts,
    totals: dashboard?.tiktok?.totals || {
      accounts: accounts.length,
      connected: accounts.filter((row) => row.connected).length,
      followers: 0,
      likes: 0,
      videoCount: 0,
      views: 0,
      comments: 0,
      shares: 0,
    },
    posts: [],
    keys: [],
  };
}

function CopyField({ value, copied, onCopy }) {
  return (
    <div className="ss-mcp-copy">
      <div className="ss-mcp-copy__row">
        <input readOnly value={value} onFocus={(event) => event.currentTarget.select()} />
        <button type="button" className={copied ? "is-copied" : ""} onClick={onCopy} aria-label={appCopy("Copier", "Copy")}>
          {copied ? <CheckIcon /> : <CopyIcon />}
        </button>
      </div>
    </div>
  );
}

function ApiBanner({ apiReady, onConnect }) {
  if (apiReady) return null;
  return (
    <div className="ss-api-banner">
      <div>
        <strong>{appCopy("API TikTok en revue", "TikTok API in review")}</strong>
        <p>
          {appCopy(
            "Tout est déjà branché à 100 % : connexions, calendrier, clés MCP. Dès que TikTok valide l'app, Connecter ouvre le vrai Login Kit.",
            "Everything is already wired: connections, calendar, MCP keys. When TikTok approves the app, Connect opens the real Login Kit."
          )}
        </p>
      </div>
      {onConnect ? (
        <button type="button" className="ss-btn-purple" onClick={onConnect}>
          {appCopy("Connecter TikTok", "Connect TikTok")}
        </button>
      ) : null}
    </div>
  );
}

function CalendarPane({ posts, onCreate, onOpen }) {
  const [cursor, setCursor] = useState(() => new Date());
  const [mode, setMode] = useState("month");
  const english = appCopy("fr", "en") === "en";
  const locale = english ? "en-US" : "fr-FR";
  const dow = english ? DOW_EN : DOW_FR;
  const start = new Date(cursor.getFullYear(), cursor.getMonth(), 1);
  const pad = (start.getDay() + 6) % 7;
  start.setDate(start.getDate() - pad);
  const cells = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    return { date, key: ymd(date), inMonth: date.getMonth() === cursor.getMonth() };
  });
  const today = ymd(new Date());
  const label = cursor.toLocaleDateString(locale, { month: "long", year: "numeric" });
  const visible = posts.filter((post) => post.inCalendar !== false);

  return (
    <div className="ss-cal">
      <div className="ss-cal-bar">
        <div className="ss-cal-nav">
          <button type="button" className="ss-btn-ghost" onClick={() => setCursor((d) => new Date(d.getFullYear(), d.getMonth() - 1, 1))}>
            ‹
          </button>
          <strong>{label}</strong>
          <button type="button" className="ss-btn-ghost" onClick={() => setCursor((d) => new Date(d.getFullYear(), d.getMonth() + 1, 1))}>
            ›
          </button>
          <button type="button" className="ss-btn-ghost" onClick={() => setCursor(new Date())}>
            {appCopy("Aujourd'hui", "Today")}
          </button>
        </div>
        <div className="ss-seg">
          {["day", "week", "month"].map((id) => (
            <button key={id} type="button" className={mode === id ? "is-on" : ""} onClick={() => setMode(id)}>
              {id === "day" ? appCopy("Jour", "Day") : id === "week" ? appCopy("Semaine", "Week") : appCopy("Mois", "Month")}
            </button>
          ))}
        </div>
        <button type="button" className="ss-btn-purple" onClick={onCreate}>
          {appCopy("Nouveau post", "New post")}
        </button>
      </div>
      {mode === "month" ? (
        <div className="ss-grid">
          {dow.map((day) => (
            <div key={day} className="ss-dow">
              {day}
            </div>
          ))}
          {cells.map((cell) => (
            <div
              key={cell.key}
              className={`ss-day ${cell.inMonth ? "" : "is-out"} ${cell.key === today ? "is-today" : ""}`}
              onDoubleClick={onCreate}
            >
              <div className="ss-day__n">{cell.date.getDate()}</div>
              {visible
                .filter((post) => post.date === cell.key)
                .slice(0, 3)
                .map((post) => (
                  <button key={post.id} type="button" className="ss-post" onClick={() => onOpen(post)}>
                    <span className="ss-post__bar" />
                    <p>
                      {post.status === "draft" ? "Draft · " : ""}
                      {post.caption}
                    </p>
                  </button>
                ))}
            </div>
          ))}
        </div>
      ) : (
        <div className="ss-week">
          {(mode === "day" ? cells.filter((cell) => cell.key === today) : cells.slice(0, 7)).map((cell) => (
            <div key={cell.key} className="ss-week-col">
              <strong>{cell.date.toLocaleDateString(locale, { weekday: "short", day: "numeric" })}</strong>
              {visible
                .filter((post) => post.date === cell.key)
                .map((post) => (
                  <button key={post.id} type="button" className="ss-post" onClick={() => onOpen(post)}>
                    <span className="ss-post__bar" />
                    <p>{post.caption}</p>
                  </button>
                ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ConnectionsPane({ studio, busy, onConnect, onDisconnect }) {
  const live = studio.accounts.filter((row) => row.connected);
  return (
    <div className="ss-connect">
      <div className="ss-page-intro">
        <div>
          <p>
            {appCopy(
              "Branche TikTok (Direct Post). Instagram, Facebook et X suivent.",
              "Connect TikTok (Direct Post). Instagram, Facebook and X come next."
            )}
          </p>
          <p className="ss-muted">
            {live.length
              ? appCopy(`${live.length} compte${live.length > 1 ? "s" : ""} connecté${live.length > 1 ? "s" : ""}.`, `${live.length} account${live.length > 1 ? "s" : ""} connected.`)
              : appCopy("Aucun compte connecté pour l'instant.", "No account connected yet.")}
          </p>
        </div>
      </div>
      <div className="ss-network-grid">
        {PLATFORMS.map((platform) => {
          const accounts = studio.accounts.filter((row) => (row.platform || "tiktok") === platform.id);
          const connected = accounts.some((row) => row.connected);
          return (
            <article key={platform.id} className="ss-network-card">
              <header>
                <strong>{platform.name}</strong>
                <span className={`ss-badge ${connected ? "is-ready" : platform.live ? "is-review" : "is-wait"}`}>
                  {connected
                    ? appCopy("Connecté", "Connected")
                    : platform.live
                      ? studio.apiReady
                        ? appCopy("Prêt", "Ready")
                        : appCopy("En revue", "In review")
                      : appCopy("Bientôt", "Soon")}
                </span>
              </header>
              <p>
                {platform.live
                  ? appCopy("Compte de publication Direct Post pour tes carrousels photo.", "Direct Post publishing account for photo carousels.")
                  : appCopy("On branche cette plateforme ensuite. TikTok d'abord.", "This platform comes next. TikTok first.")}
              </p>
              {accounts.length ? (
                <ul className="ss-connect-accounts">
                  {accounts.map((channel) => (
                    <li key={channel.id}>
                      <span className="ss-avatar">{(channel.handle || channel.name || "T").slice(0, 1).toUpperCase()}</span>
                      <span>
                        <b>@{channel.handle || channel.name}</b>
                        <span>
                          {channel.followers
                            ? `${fmt(channel.followers)} ${appCopy("abonnés", "followers")}`
                            : channel.connected
                              ? appCopy("Connecté", "Connected")
                              : appCopy("En attente API", "Waiting for API")}
                        </span>
                      </span>
                      {platform.live ? (
                        <button type="button" className="ss-btn-ghost" disabled={busy === channel.id} onClick={() => onDisconnect(channel.id)}>
                          {appCopy("Déconnecter", "Disconnect")}
                        </button>
                      ) : null}
                    </li>
                  ))}
                </ul>
              ) : null}
              {platform.live ? (
                <button type="button" className="ss-btn-purple" disabled={Boolean(busy)} onClick={onConnect}>
                  {connected ? appCopy("Ajouter un compte", "Add an account") : appCopy("Connecter", "Connect")}
                </button>
              ) : (
                <button type="button" className="ss-btn-ghost" disabled>
                  {appCopy("Bientôt", "Soon")}
                </button>
              )}
            </article>
          );
        })}
      </div>
    </div>
  );
}

function McpPane({ studio, user, onCreateKey, onRevoke, onOpenCalendar, busy, revealed }) {
  const [client, setClient] = useState("claude");
  const [copied, setCopied] = useState("");
  const origin = typeof window === "undefined" ? "https://useprocess.xyz" : window.location.origin;
  const mcpUrl = `${origin.replace(/\/$/, "")}/api/mcp`;
  const token = revealed || "ss_live_YOUR_KEY";
  const claudeCli = `claude mcp add --transport http process-clipping ${mcpUrl} --header "Authorization: Bearer ${token}"`;
  const codexExport = `export PROCESS_MCP_KEY='${token}'`;
  const codexCli = `codex mcp add process-clipping --url ${mcpUrl} --bearer-token-env-var PROCESS_MCP_KEY`;
  const cursorDeeplink = useMemo(() => {
    const config = btoa(JSON.stringify({ url: mcpUrl, headers: { Authorization: `Bearer ${token}` } }))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
    return `cursor://anysphere.cursor-deeplink/mcp/install?name=process-clipping&config=${config}`;
  }, [mcpUrl, token]);

  async function copy(id, text) {
    await navigator.clipboard.writeText(text);
    playConfirm();
    setCopied(id);
    window.setTimeout(() => setCopied((cur) => (cur === id ? "" : cur)), 1600);
  }

  const ask = {
    n: "3",
    title: appCopy("Demande-lui un post", "Ask it to post"),
    body: appCopy(
      "Exemple : « Liste tous les formats » ou « Planifie un carousel demain à 18h ». Il a 100 % de la bibliothèque Tiktoks.",
      "Example: “List every format” or “Schedule a carousel tomorrow at 6pm.” It has 100% of the Tiktoks library."
    ),
    cta: appCopy("Ouvrir le calendrier", "Open the calendar"),
    primary: true,
  };

  const steps =
    client === "codex"
      ? [
          { n: "1", title: appCopy("Copie la première commande", "Copy the first command"), body: appCopy("Colle-la dans le terminal de Codex.", "Paste it in the Codex terminal."), field: codexExport, copyId: "codex-env" },
          { n: "2", title: appCopy("Puis la deuxième", "Then the second"), body: appCopy("Toujours dans le même terminal. Relance Codex après.", "Still in the same terminal. Restart Codex afterwards."), field: codexCli, copyId: "codex-cli" },
          ask,
        ]
      : client === "claude-code"
        ? [
            { n: "1", title: appCopy("Copie cette commande", "Copy this command"), body: appCopy("Tu la colleras dans le terminal au step suivant.", "You'll paste it in the terminal next."), field: claudeCli, copyId: "cli" },
            { n: "2", title: appCopy("Colle-la dans Claude Code", "Paste it in Claude Code"), body: appCopy("Ouvre ton projet, colle la commande, puis relance la session.", "Open your project, paste the command, then reload the session."), cta: appCopy("Ouvrir Claude Code", "Open Claude Code"), href: "https://docs.anthropic.com/en/docs/claude-code" },
            ask,
          ]
        : client === "cursor"
          ? [
              { n: "1", title: appCopy("Copie l'adresse MCP", "Copy the MCP address"), body: appCopy("Tu la colleras dans Cursor au step suivant.", "You'll paste this into Cursor next."), field: mcpUrl, copyId: "url" },
              { n: "2", title: appCopy("Ajoute Process dans Cursor", "Add Process in Cursor"), body: appCopy("Un clic. Cursor te demande de confirmer. L'agent voit tous les formats Tiktoks.", "One click. Cursor will ask you to confirm. The agent sees every Tiktoks format."), cta: appCopy("Ouvrir Cursor", "Open Cursor"), href: cursorDeeplink },
              ask,
            ]
          : [
              { n: "1", title: appCopy("Copie l'adresse MCP", "Copy the MCP address"), body: appCopy("Tu la colleras dans Claude au step suivant.", "You'll paste this URL into Claude next."), field: mcpUrl, copyId: "url" },
              { n: "2", title: appCopy("Claude → Customize → Connectors", "Claude → Customize → Connectors"), body: appCopy("Dans Claude desktop ou claude.ai, va dans Customize → Connectors. Nomme-le Process et colle l'adresse.", "In Claude desktop or claude.ai, go to Customize → Connectors. Name it Process and paste the address."), cta: appCopy("Ouvrir Claude Customize", "Open Claude Customize"), href: "https://claude.ai/settings/connectors" },
              ask,
            ];

  return (
    <section className="ss-mcp">
      <header className="ss-mcp-hero">
        <div className="ss-mcp-orbit" aria-hidden>
          {CLIENTS.slice(0, 2).map((item) => (
            <span key={item.id} className="ss-mcp-orbit__item">
              <img src={item.logo} alt="" style={{ background: item.bg }} />
            </span>
          ))}
          <span className="ss-mcp-orbit__item is-core">
            <img src={LOGO} alt="" />
          </span>
          {CLIENTS.slice(2).map((item) => (
            <span key={item.id} className="ss-mcp-orbit__item">
              <img src={item.logo} alt="" style={{ background: item.bg }} />
            </span>
          ))}
        </div>
        <h2>{appCopy("Tes IA publient tes TikToks", "Your AI posts your TikToks")}</h2>
        <p className="ss-mcp-sub">
          {appCopy(
            "L'agent voit 100 % des formats Tiktoks, peut en créer, coller des liens, et lire ton studio.",
            "The agent sees 100% of Tiktoks formats, can create them, paste links, and read your studio."
          )}
        </p>
      </header>

      <div className="ss-mcp-panel">
        <div className="ss-mcp-bar">
          <div className="ss-mcp-tabs" role="tablist">
            {CLIENTS.map((item) => (
              <button key={item.id} type="button" role="tab" aria-selected={client === item.id} className={client === item.id ? "is-on" : ""} onClick={() => setClient(item.id)}>
                <img src={item.logo} alt="" className="ss-mcp-tabs__mark" style={{ background: item.bg }} />
                {item.label}
              </button>
            ))}
          </div>
        </div>
        <div className="ss-mcp-board">
          {steps.map((step) => (
            <article key={`${client}-${step.n}`} className="ss-mcp-card">
              <span className="ss-mcp-card__n">{step.n}</span>
              <h3>
                {step.n === "1" ? <img src={LOGO} alt="" width={18} height={18} style={{ borderRadius: 4, objectFit: "cover" }} /> : null}
                {step.title}
              </h3>
              <p>{step.body}</p>
              <div className="ss-mcp-card__action">
                {step.field ? <CopyField value={step.field} copied={copied === step.copyId} onCopy={() => void copy(step.copyId, step.field)} /> : null}
                {step.cta && step.href ? (
                  <a className={step.primary ? "ss-btn-purple" : "ss-btn-ghost"} href={step.href}>
                    {step.cta}
                    {step.primary ? null : <ExternalIcon />}
                  </a>
                ) : null}
                {step.cta && step.primary && !step.href ? (
                  <button type="button" className="ss-btn-purple" onClick={onOpenCalendar}>
                    {step.cta}
                  </button>
                ) : null}
              </div>
            </article>
          ))}
        </div>
      </div>

      <p className="ss-mcp-foot">
        {appCopy("TikTok se branche dans Connexions. Ici, c'est uniquement tes assistants IA.", "TikTok is connected in Connections. This page is only for your AI assistants.")}
      </p>

      <div className="ss-mcp-keys">
        <div className="ss-mcp-keys__head">
          <div>
            <h3>{appCopy("Clés actives", "Active keys")}</h3>
            <p>
              {revealed
                ? appCopy("Copie-la maintenant — elle ne sera plus affichée. Elle marche pour tous tes agents.", "Copy it now — it won't be shown again. It works for every agent.")
                : appCopy("Une clé pour brancher Claude, Claude Code, Cursor et Codex. Crée-la une fois.", "One key to connect Claude, Claude Code, Cursor and Codex. Create it once.")}
            </p>
          </div>
          {revealed ? (
            <CopyField value={revealed} copied={copied === "key"} onCopy={() => void copy("key", revealed)} />
          ) : (
            <SuccessActionButton
              className="ss-btn-purple"
              disabled={busy}
              idleLabel={appCopy("Créer une clé", "Create a key")}
              savingLabel={appCopy("Création…", "Creating…")}
              successLabel={appCopy("Créée", "Created")}
              onAction={onCreateKey}
            />
          )}
        </div>
        {studio.keys?.length ? (
          studio.keys.map((key) => (
            <div key={key.id} className="ss-mcp-keys__row">
              <code>
                {key.prefix}… · {key.name}
              </code>
              <button type="button" onClick={() => onRevoke(key.id)}>
                {appCopy("Révoquer", "Revoke")}
              </button>
            </div>
          ))
        ) : (
          <p className="ss-mcp-keys__empty">{appCopy("Aucune clé pour l'instant.", "No keys yet.")}</p>
        )}
      </div>
      {user?.email ? <p className="ss-mcp-foot">{user.email}</p> : null}
    </section>
  );
}

function PostModal({ open, post, accounts, onClose, onSave, onDelete, busy }) {
  const [caption, setCaption] = useState(post?.caption || "");
  const [date, setDate] = useState(post?.date || ymd(new Date()));
  const [time, setTime] = useState(post?.time || "18:00");
  const [status, setStatus] = useState(post?.status || "scheduled");
  const [channelIds, setChannelIds] = useState(post?.channelIds || []);

  useEffect(() => {
    if (!open) return;
    setCaption(post?.caption || "");
    setDate(post?.date || ymd(new Date()));
    setTime(post?.time || "18:00");
    setStatus(post?.status === "published" ? "scheduled" : post?.status || "scheduled");
    setChannelIds(post?.channelIds || accounts.filter((row) => row.connected).map((row) => row.id).slice(0, 1));
  }, [open, post, accounts]);

  if (!open) return null;
  return (
    <div className="ss-modal" onClick={onClose}>
      <div className="ss-dialog" onClick={(event) => event.stopPropagation()}>
        <h2>{post?.id ? appCopy("Modifier le post", "Edit post") : appCopy("Nouveau post", "New post")}</h2>
        <label>
          {appCopy("Légende", "Caption")}
          <textarea className="af-input" rows={4} value={caption} onChange={(event) => setCaption(event.target.value)} />
        </label>
        <div className="ss-dialog-row">
          <label>
            {appCopy("Date", "Date")}
            <input className="af-input" type="date" value={date} onChange={(event) => setDate(event.target.value)} />
          </label>
          <label>
            {appCopy("Heure", "Time")}
            <input className="af-input" type="time" value={time} onChange={(event) => setTime(event.target.value)} />
          </label>
        </div>
        <label>
          {appCopy("Statut", "Status")}
          <select className="af-input" value={status} onChange={(event) => setStatus(event.target.value)}>
            <option value="draft">{appCopy("Brouillon", "Draft")}</option>
            <option value="scheduled">{appCopy("Planifié", "Scheduled")}</option>
          </select>
        </label>
        {accounts.length ? (
          <label>
            {appCopy("Compte", "Account")}
            <select className="af-input" value={channelIds[0] || ""} onChange={(event) => setChannelIds(event.target.value ? [event.target.value] : [])}>
              <option value="">{appCopy("Tous / plus tard", "All / later")}</option>
              {accounts.map((row) => (
                <option key={row.id} value={row.id}>
                  @{row.handle || row.name}
                </option>
              ))}
            </select>
          </label>
        ) : null}
        <div className="ss-dialog-actions">
          {post?.id ? (
            <button type="button" className="ss-btn-ghost" disabled={busy} onClick={() => onDelete(post.id)}>
              {appCopy("Supprimer", "Delete")}
            </button>
          ) : (
            <span />
          )}
          <button type="button" className="ss-btn-ghost" onClick={onClose}>
            {appCopy("Fermer", "Close")}
          </button>
          <SuccessActionButton
            className="ss-btn-purple"
            disabled={!caption.trim()}
            idleLabel={appCopy("Enregistrer", "Save")}
            onAction={() => onSave({ id: post?.id, caption, date, time, status, channelIds })}
            onSuccess={() => {
              window.setTimeout(() => onClose(), 800);
            }}
          />
        </div>
      </div>
    </div>
  );
}

export function AffiliateAutomationPage() {
  return (
    <div className="af-cook ss-soon-page">
      <div className="ss-soon-blur" aria-hidden="true">
        <nav className="ss-studio-tabs" aria-label={appCopy("Automatiser", "Automate")}>
          {TABS.map((item) => (
            <button key={item.id} type="button" className={item.id === "calendrier" ? "is-on" : ""}>
              {appCopy(item.fr, item.en)}
            </button>
          ))}
        </nav>
        <CalendarPane posts={previewPosts()} onCreate={() => {}} onOpen={() => {}} />
      </div>
      <div className="af-tiktok-soon-overlay" role="status">
        <span className="af-tiktok-soon-emoji" aria-hidden>
          🚧
        </span>
        <strong>{appCopy("Disponible bientôt", "Coming soon")}</strong>
      </div>
    </div>
  );
}
