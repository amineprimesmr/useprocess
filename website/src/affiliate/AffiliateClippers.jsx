import { useCallback, useEffect, useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { affiliateApi, getAuthToken } from "../features/firebase-client.js";
import { IconTrophy } from "./AffiliateIcons.jsx";
import { formatViewCount, money } from "./affiliate-utils.js";
import { isAffiliateLocalPreview, LOCAL_PREVIEW_CLIPPERS } from "./affiliate-local-preview.js";
import "./affiliate-clippers.css";

const SORTS = [
  { id: "earnings", label: () => appCopy("Gains", "Earnings") },
  { id: "sales", label: () => appCopy("Ventes", "Sales") },
  { id: "trials", label: () => appCopy("Essais", "Trials") },
  { id: "installs", label: () => appCopy("Installs", "Installs") },
  { id: "visits", label: () => appCopy("Visites", "Visits") },
];

function metric(stats, sort) {
  const row = stats || {};
  if (sort === "sales") return Number(row.paidCount) || 0;
  if (sort === "trials") return Number(row.trialCount) || 0;
  if (sort === "installs") return Number(row.referredCount) || 0;
  if (sort === "visits") return Number(row.linkViews) || 0;
  if (sort === "paywalls") return Number(row.paywallCount) || 0;
  return Number(row.lifetimeCents) || 0;
}

function rankRows(rows, sort) {
  return [...rows]
    .sort((a, b) => {
      const primary = metric(b.stats, sort) - metric(a.stats, sort);
      if (primary) return primary;
      const earnings = (b.stats?.lifetimeCents || 0) - (a.stats?.lifetimeCents || 0);
      if (earnings) return earnings;
      const sales = (b.stats?.paidCount || 0) - (a.stats?.paidCount || 0);
      if (sales) return sales;
      const trials = (b.stats?.trialCount || 0) - (a.stats?.trialCount || 0);
      if (trials) return trials;
      const installs = (b.stats?.referredCount || 0) - (a.stats?.referredCount || 0);
      if (installs) return installs;
      return String(a.displayName || "").localeCompare(String(b.displayName || ""), "en", {
        sensitivity: "base",
      });
    })
    .map((row, index) => ({ ...row, rank: index + 1 }));
}

function initials(name) {
  const parts = String(name || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
}

function avatarHue(name) {
  let hash = 0;
  for (const ch of String(name || "")) hash = (hash * 31 + ch.charCodeAt(0)) % 360;
  return hash;
}

function ClipperAvatar({ name, place }) {
  const hue = avatarHue(name);
  return (
    <span
      className={`af-clip-avatar ${place ? `is-${place}` : ""}`}
      style={place ? undefined : { background: `hsl(${hue} 42% 92%)`, color: `hsl(${hue} 45% 32%)` }}
    >
      {initials(name)}
    </span>
  );
}

function ordinal(rank) {
  const n = Number(rank) || 0;
  return appCopy(`n°${n}`, `#${n}`);
}

function PodiumCard({ row, place }) {
  return (
    <article className={`af-podium-card is-${place} ${row.isYou ? "is-you" : ""}`}>
      <div className="af-podium-place" aria-hidden="true">
        {place === 1 ? "🥇" : place === 2 ? "🥈" : "🥉"}
      </div>
      <ClipperAvatar name={row.displayName} place={place} />
      <strong>{row.displayName}</strong>
      {row.code ? <span className="af-clip-code">{row.code}</span> : null}
      {row.isYou ? <span className="af-clip-you">{appCopy("Toi", "You")}</span> : null}
      <div className="af-podium-earn">{money(row.stats?.lifetimeCents)}</div>
      <p className="af-podium-meta">
        {row.stats?.paidCount || 0} {appCopy("ventes", "sales")}
        <span aria-hidden="true"> · </span>
        {row.stats?.trialCount || 0} {appCopy("essais", "trials")}
        <span aria-hidden="true"> · </span>
        {row.stats?.referredCount || 0} {appCopy("installs", "installs")}
      </p>
    </article>
  );
}

export function AffiliateClippersPage({ user, dashboard }) {
  const [rows, setRows] = useState([]);
  const [viewerStatus, setViewerStatus] = useState(dashboard?.status || "");
  const [sort, setSort] = useState("earnings");
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("loading");
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!user) return;
    setError("");
    if (isAffiliateLocalPreview()) {
      setRows(LOCAL_PREVIEW_CLIPPERS);
      setViewerStatus(dashboard?.status || "active");
      setStatus("ready");
      return;
    }
    try {
      const token = await getAuthToken(user);
      const data = await affiliateApi("affiliateLeaderboard", {
        token,
        body: { sort: "earnings" },
        timeoutMs: 15000,
      });
      setRows(Array.isArray(data.clippers) ? data.clippers : []);
      setViewerStatus(data.viewerStatus || dashboard?.status || "");
      setStatus("ready");
    } catch (err) {
      setStatus("error");
      setError(
        appCopy(
          "Impossible de charger le classement pour le moment.",
          "Couldn't load the leaderboard right now."
        )
      );
      console.warn("[clippers]", err);
    }
  }, [user, dashboard?.status]);

  useEffect(() => {
    void load();
  }, [load]);

  const ranked = useMemo(() => rankRows(rows, sort), [rows, sort]);
  const query = search.trim().toLowerCase();
  const visible = useMemo(() => {
    if (!query) return ranked;
    return ranked.filter((row) => {
      const name = String(row.displayName || "").toLowerCase();
      const code = String(row.code || "").toLowerCase();
      return name.includes(query) || code.includes(query);
    });
  }, [ranked, query]);

  const you = ranked.find((row) => row.isYou) || null;
  const first = ranked[0] || null;
  const second = ranked[1] || null;
  const third = ranked[2] || null;

  return (
    <div className="af-clippers">
      <header className="af-clip-hero">
        <p className="af-clip-kicker">{appCopy("Classement", "Leaderboard")}</p>
        <h2>
          <IconTrophy />
          {appCopy("Clippers", "Clippers")}
        </h2>
        <p>
          {appCopy(
            "Tous les clippers Process, classés par gains, ventes, essais et installs. Le podium change selon le filtre.",
            "Every Process clipper, ranked by earnings, sales, trials, and installs. The podium follows the filter."
          )}
        </p>
      </header>

      {viewerStatus === "pending" ? (
        <div className="af-pending-banner">
          <IconTrophy />
          <div>
            <strong>{appCopy("Candidature en cours de validation", "Application under review")}</strong>
            <p>
              {appCopy(
                "Ton nom apparaît dans le classement dès que le compte est validé. En attendant, tu peux voir le podium.",
                "Your name shows up on the leaderboard once the account is approved. Until then, you can still see the podium."
              )}
            </p>
          </div>
        </div>
      ) : null}

      {you ? (
        <section className="af-clip-youbar" aria-live="polite">
          <ClipperAvatar name={you.displayName} />
          <div>
            <strong>
              {appCopy("Tu es", "You're")} {ordinal(you.rank)}
              {ranked.length > 1
                ? ` ${appCopy("sur", "of")} ${ranked.length}`
                : ""}
            </strong>
            <span>
              {money(you.stats?.lifetimeCents)}
              <span aria-hidden="true"> · </span>
              {you.stats?.paidCount || 0} {appCopy("ventes", "sales")}
              <span aria-hidden="true"> · </span>
              {you.stats?.trialCount || 0} {appCopy("essais", "trials")}
              <span aria-hidden="true"> · </span>
              {you.stats?.referredCount || 0} {appCopy("installs", "installs")}
            </span>
          </div>
        </section>
      ) : null}

      <div className="af-clip-toolbar">
        <div className="af-toolbar" role="tablist" aria-label={appCopy("Trier le classement", "Sort the leaderboard")}>
          {SORTS.map((item) => (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={sort === item.id}
              className={`af-chip-btn ${sort === item.id ? "is-active" : ""}`}
              onClick={() => setSort(item.id)}
            >
              {item.label()}
            </button>
          ))}
        </div>
        <label className="af-clip-search">
          <span className="visually-hidden">{appCopy("Rechercher un clipper", "Search a clipper")}</span>
          <input
            className="af-clip-search-input"
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={appCopy("Nom ou code…", "Name or code…")}
          />
        </label>
      </div>

      {status === "loading" ? (
        <div className="af-podium" aria-hidden="true">
          {[2, 1, 3].map((place) => (
            <div key={place} className={`af-podium-card is-${place} is-skeleton`} />
          ))}
        </div>
      ) : null}

      {status === "error" ? (
        <div className="af-card af-card-pad">
          <p>{error}</p>
          <button type="button" className="af-chip-btn is-active" onClick={() => void load()}>
            {appCopy("Réessayer", "Try again")}
          </button>
        </div>
      ) : null}

      {status === "ready" && ranked.length === 0 ? (
        <div className="af-card af-empty">
          <div className="af-empty-content">
            <h2>{appCopy("Pas encore de classement", "No ranking yet")}</h2>
            <p>
              {appCopy(
                "Dès qu’un clipper est validé, il apparaît ici avec ses stats.",
                "As soon as a clipper is approved, they show up here with their stats."
              )}
            </p>
          </div>
        </div>
      ) : null}

      {status === "ready" && ranked.length > 0 ? (
        <>
          <section
            className={`af-podium af-podium-${Math.min(ranked.length, 3)}`}
            aria-label={appCopy("Podium", "Podium")}
          >
            {second ? <PodiumCard row={second} place={2} /> : null}
            {first ? <PodiumCard row={first} place={1} /> : null}
            {third ? <PodiumCard row={third} place={3} /> : null}
          </section>

          <section className="af-card af-clip-board">
            <div className="af-card-head af-clip-board-head">
              <h2>{appCopy("Tous les clippers", "All clippers")}</h2>
              <span>
                {visible.length}
                {visible.length !== ranked.length ? ` / ${ranked.length}` : ""}
              </span>
            </div>
            <div className="af-table-wrap">
              <table className="af-table af-clip-table">
                <thead>
                  <tr>
                    <th>{appCopy("#", "#")}</th>
                    <th>{appCopy("Clipper", "Clipper")}</th>
                    <th>{appCopy("Gains", "Earnings")}</th>
                    <th>{appCopy("Ventes", "Sales")}</th>
                    <th>{appCopy("Essais", "Trials")}</th>
                    <th>{appCopy("Installs", "Installs")}</th>
                    <th>{appCopy("Visites", "Visits")}</th>
                  </tr>
                </thead>
                <tbody>
                  {visible.map((row) => (
                    <tr key={`${row.code || row.displayName}-${row.rank}`} className={row.isYou ? "is-you" : ""}>
                      <td className="af-clip-rank">
                        {row.rank <= 3 ? (row.rank === 1 ? "🥇" : row.rank === 2 ? "🥈" : "🥉") : row.rank}
                      </td>
                      <td>
                        <div className="af-clip-name">
                          <ClipperAvatar name={row.displayName} place={row.rank <= 3 ? row.rank : 0} />
                          <div>
                            <strong>
                              {row.displayName}
                              {row.isYou ? <span className="af-clip-you">{appCopy("Toi", "You")}</span> : null}
                            </strong>
                            {row.code ? <span className="af-clip-code">{row.code}</span> : null}
                          </div>
                        </div>
                      </td>
                      <td>{money(row.stats?.lifetimeCents)}</td>
                      <td>{row.stats?.paidCount || 0}</td>
                      <td>{row.stats?.trialCount || 0}</td>
                      <td>{row.stats?.referredCount || 0}</td>
                      <td>{formatViewCount(row.stats?.linkViews || 0)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {visible.length === 0 ? (
              <p className="af-clip-empty-search">
                {appCopy("Aucun clipper ne correspond.", "No clipper matches that search.")}
              </p>
            ) : null}
          </section>
        </>
      ) : null}
    </div>
  );
}
