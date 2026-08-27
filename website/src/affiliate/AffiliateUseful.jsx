import { useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronDown, IconChevronLeft, IconGlobe, IconHelp, IconMail, IconShield } from "./AffiliateIcons.jsx";
import { MethodBlock } from "./AffiliateMethod.jsx";
import { supportMailto } from "./affiliate-utils.js";
import { METHOD_MODULES } from "./method-catalog.js";
import "./affiliate-method.css";
import "./affiliate-useful.css";

const SHADOWBAN_MODULE = METHOD_MODULES.find((mod) => mod.id === "original");

export const USEFUL_TOPICS = [
  {
    id: "shadowban",
    icon: IconShield,
    title: () => appCopy("Shadowban", "Shadowban"),
    blurb: () =>
      appCopy(
        "Toute la méthode : le détecter, pourquoi ça arrive, et comment en sortir.",
        "The full method: how to spot it, why it happens, and how to get out."
      ),
  },
  {
    id: "questions",
    icon: IconHelp,
    title: () => appCopy("Questions", "Questions"),
    blurb: () =>
      appCopy(
        "Réponses déjà prêtes, et un formulaire pour poser la tienne.",
        "Answers we already have, plus a form to ask yours."
      ),
  },
];

const PREPARED_QUESTIONS = [
  {
    id: "accounts",
    q: () =>
      appCopy(
        "On garde nos comptes TikTok ou tu nous en donnes ?",
        "Do we keep our TikTok accounts, or do you give us some?"
      ),
    a: () =>
      appCopy(
        "Non : tu crées tes comptes toi-même. On n'en donne pas. Chaque compte doit suivre la méthodologie de lancement (création + warm) avant de poster à fond. Un compte lancé n'importe comment se fait shadowban.",
        "No: you create your own accounts. We don’t give you any. Every account has to follow the launch methodology (create + warm) before you post hard. An account launched sloppy gets shadowbanned."
      ),
  },
  {
    id: "api",
    q: () =>
      appCopy("Poster un TikTok via API, c'est nul ?", "Is posting a TikTok via API worthless?"),
    a: () =>
      appCopy(
        "Faux. Poster via API n'est pas le problème. Si tu respectes la méthodologie de lancement, et que tu vas sur tes différents comptes pour commenter, mettre des sondages, liker et scroller, il n'y aura pas de souci. Un compte que tu ne vis jamais, lui, se fait griller.",
        "False. Posting via API isn’t the problem. If you follow the launch methodology, and you actually go into each account to comment, add polls, like, and scroll, you’ll be fine. An account you never live in gets burned."
      ),
  },
];

function UsefulHero({ kicker, title, subtitle }) {
  return (
    <header className="af-useful-hero">
      <p className="af-useful-kicker">{kicker}</p>
      <h2>{title}</h2>
      {subtitle ? <p>{subtitle}</p> : null}
    </header>
  );
}

function TopicBack({ onBack }) {
  return (
    <button type="button" className="af-useful-back" onClick={onBack}>
      <IconChevronLeft />
      {appCopy("Utiles", "Useful")}
    </button>
  );
}

function ShadowbanTopic({ onBack }) {
  const blocks = SHADOWBAN_MODULE?.blocks || [];
  return (
    <div className="af-useful-article af-useful-article--method">
      <TopicBack onBack={onBack} />
      <div className="af-md af-md--solo">
        <article className="af-md-page">
          <p className="af-md-kicker">{appCopy("Utiles", "Useful")}</p>
          <h2>{appCopy(SHADOWBAN_MODULE?.title?.fr || "Shadowban", SHADOWBAN_MODULE?.title?.en || "Shadowban")}</h2>
          {blocks.map((block, i) => (
            <MethodBlock key={`shadowban-${block.type}-${i}`} block={block} vars={{}} pace={{ fr: "", en: "" }} />
          ))}
        </article>
      </div>
    </div>
  );
}

function FaqItem({ item, open, onToggle }) {
  return (
    <div className={`af-useful-faq ${open ? "is-open" : ""}`}>
      <button type="button" className="af-useful-faq-q" onClick={onToggle} aria-expanded={open}>
        <span>{item.q()}</span>
        <IconChevronDown />
      </button>
      {open ? <p className="af-useful-faq-a">{item.a()}</p> : null}
    </div>
  );
}

function QuestionsTopic({ displayName, email, onBack }) {
  const [openId, setOpenId] = useState(PREPARED_QUESTIONS[0]?.id || "");
  const [question, setQuestion] = useState("");
  const [sent, setSent] = useState(false);

  function submitQuestion(event) {
    event.preventDefault();
    const text = question.trim();
    if (!text) return;
    window.location.href = supportMailto(
      appCopy("Question clipper Process", "Process clipper question"),
      appCopy(
        `Prénom : ${displayName || ""}\nEmail : ${email || ""}\n\nQuestion :\n${text}\n`,
        `First name: ${displayName || ""}\nEmail: ${email || ""}\n\nQuestion:\n${text}\n`
      )
    );
    setSent(true);
  }

  return (
    <div className="af-useful-article">
      <TopicBack onBack={onBack} />
      <UsefulHero
        kicker={appCopy("Utiles", "Useful")}
        title={appCopy("Questions", "Questions")}
        subtitle={appCopy(
          "On répond d'abord aux questions qui reviennent. Si la tienne n'y est pas, envoie-la.",
          "We answer the recurring ones first. If yours isn’t here, send it."
        )}
      />

      <div className="af-useful-faq-list">
        {PREPARED_QUESTIONS.map((item) => (
          <FaqItem
            key={item.id}
            item={item}
            open={openId === item.id}
            onToggle={() => setOpenId((current) => (current === item.id ? "" : item.id))}
          />
        ))}
      </div>

      <section className="af-useful-card">
        <h3>{appCopy("Pose ta question", "Ask your question")}</h3>
        {sent ? (
          <p className="af-useful-sent">
            {appCopy(
              "Merci — ouvre ton app mail si ce n'est pas déjà fait.",
              "Thanks — open your mail app if it didn’t open already."
            )}
          </p>
        ) : (
          <form className="af-useful-form" onSubmit={submitQuestion}>
            <textarea
              className="af-input af-useful-textarea"
              rows={5}
              value={question}
              onChange={(event) => setQuestion(event.target.value)}
              placeholder={appCopy(
                "Ta question sur les comptes, l'API, le shadowban…",
                "Your question about accounts, the API, shadowban…"
              )}
              required
            />
            <button type="submit" className="af-btn af-btn-black" disabled={!question.trim()}>
              <IconMail style={{ width: 16, height: 16 }} />
              {appCopy("Envoyer la question", "Send the question")}
            </button>
          </form>
        )}
      </section>
    </div>
  );
}

function UsefulHub({ onOpen, onOpenUs }) {
  return (
    <div className="af-useful-article">
      <UsefulHero
        kicker={appCopy("Menu", "Menu")}
        title={appCopy("Utiles", "Useful")}
        subtitle={appCopy(
          "Poster aux US, shadowban, questions — tout ce qu'il faut pour clipper sans se griller.",
          "Post in the US, shadowban, questions — everything you need to clip without getting burned."
        )}
      />
      <div className="af-useful-grid">
        <button type="button" className="af-useful-topic" onClick={onOpenUs}>
          <IconGlobe />
          <strong>{appCopy("Poster US", "Post in the US")}</strong>
          <span>
            {appCopy(
              "Méthode pour poster depuis les États-Unis.",
              "How to post from the United States."
            )}
          </span>
        </button>
        {USEFUL_TOPICS.map((topic) => {
          const Icon = topic.icon;
          return (
            <button key={topic.id} type="button" className="af-useful-topic" onClick={() => onOpen(topic.id)}>
              <Icon />
              <strong>{topic.title()}</strong>
              <span>{topic.blurb()}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function AffiliateUsefulPage({ topic, displayName, email, onOpenTopic, onBack, onOpenUs }) {
  const current = useMemo(
    () => USEFUL_TOPICS.find((row) => row.id === topic) || null,
    [topic]
  );

  if (current?.id === "shadowban") {
    return <ShadowbanTopic onBack={onBack} />;
  }
  if (current?.id === "questions") {
    return <QuestionsTopic displayName={displayName} email={email} onBack={onBack} />;
  }
  return <UsefulHub onOpen={onOpenTopic} onOpenUs={onOpenUs} />;
}
