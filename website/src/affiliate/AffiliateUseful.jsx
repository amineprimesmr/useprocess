import { useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronDown, IconChevronLeft, IconGlobe, IconHelp, IconMail, IconShield, IconWhatsApp } from "./AffiliateIcons.jsx";
import { SUPPORT_WHATSAPP_DISPLAY, SUPPORT_WHATSAPP_URL, supportMailto } from "./affiliate-utils.js";
import "./affiliate-useful.css";

export const USEFUL_TOPICS = [
  {
    id: "shadowban",
    icon: IconShield,
    title: () => appCopy("Shadowban", "Shadowban"),
    blurb: () =>
      appCopy(
        "Comment le détecter, pourquoi ça arrive, et comment en sortir.",
        "How to spot it, why it happens, and how to get out."
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
  {
    id: "aide",
    icon: IconWhatsApp,
    title: () => appCopy("Aide", "Help"),
    blurb: () =>
      appCopy(
        "Si besoin, WhatsApp — on répond plus vite.",
        "If you need a hand, WhatsApp — we reply faster."
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
      {appCopy("Toutes les sections", "All sections")}
    </button>
  );
}

function ShadowbanTopic({ onBack, onOpenMethod }) {
  return (
    <div className="af-useful-article">
      <TopicBack onBack={onBack} />
      <UsefulHero
        kicker={appCopy("Outils", "Tools")}
        title={appCopy("Shadowban", "Shadowban")}
        subtitle={appCopy(
          "Moins de 50 vues, ou le message « pas éligible au Pour toi » : le compte est grillé. On ne poste plus, on relance le warm.",
          "Under 50 views, or the “not eligible for For You” message: the account is burned. Stop posting and restart the warm-up."
        )}
      />

      <section className="af-useful-card">
        <h3>{appCopy("Tu es shadowban si", "You’re shadowbanned if")}</h3>
        <ul>
          <li>
            {appCopy(
              "TikTok dit que la vidéo n'est pas éligible à la recommandation Pour toi.",
              "TikTok says the video isn’t eligible for For You recommendations."
            )}
          </li>
          <li>
            {appCopy(
              "Tu restes sous 50 vues, même sans message.",
              "You stay under 50 views, even with no message."
            )}
          </li>
        </ul>
      </section>

      <section className="af-useful-card">
        <h3>{appCopy("Pourquoi ça arrive", "Why it happens")}</h3>
        <ul>
          <li>{appCopy("Compte pas assez chauffé.", "Account wasn’t warmed up enough.")}</li>
          <li>{appCopy("Slideshows full IA.", "Full-AI slideshows.")}</li>
          <li>{appCopy("Trop de posts trop vite.", "Too many posts too fast.")}</li>
        </ul>
      </section>

      <section className="af-useful-card">
        <h3>{appCopy("Quoi faire", "What to do")}</h3>
        <ul>
          <li>{appCopy("Arrête de poster 2 jours.", "Stop posting for 2 days.")}</li>
          <li>{appCopy("Scroll, like, Shop, panier, vérifs d'identité.", "Scroll, like, Shop, cart, identity checks.")}</li>
          <li>{appCopy("Un seul slideshow au bout de 3 jours.", "One slideshow after 3 days.")}</li>
        </ul>
      </section>

      <button type="button" className="af-btn af-btn-black" onClick={onOpenMethod}>
        {appCopy("Ouvrir la méthode Shadowban", "Open the Shadowban method")}
      </button>
    </div>
  );
}

function WhatsAppHelpCard() {
  return (
    <section className="af-useful-card af-useful-whatsapp">
      <h3>{appCopy("WhatsApp", "WhatsApp")}</h3>
      <p>
        {appCopy(
          "Si tu bloques, envoie un message. On répond plus vite que par mail.",
          "If you’re stuck, send a message. We reply faster than email."
        )}
      </p>
      <p className="af-useful-whatsapp__number">
        <a href={SUPPORT_WHATSAPP_URL} target="_blank" rel="noreferrer">
          {SUPPORT_WHATSAPP_DISPLAY}
        </a>
      </p>
      <a className="af-btn af-btn-black" href={SUPPORT_WHATSAPP_URL} target="_blank" rel="noreferrer">
        <IconWhatsApp style={{ width: 16, height: 16 }} />
        {appCopy("Ouvrir WhatsApp", "Open WhatsApp")}
      </a>
    </section>
  );
}

function HelpTopic({ onBack }) {
  return (
    <div className="af-useful-article">
      <TopicBack onBack={onBack} />
      <UsefulHero
        kicker={appCopy("Outils", "Tools")}
        title={appCopy("Aide", "Help")}
        subtitle={appCopy(
          "Si besoin, WhatsApp. Pour une question déjà vue, passe par Questions.",
          "WhatsApp if you need a hand. For a recurring question, start with Questions."
        )}
      />
      <WhatsAppHelpCard />
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
      appCopy("Question créateur Process", "Process creator question"),
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
        kicker={appCopy("Outils", "Tools")}
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
      <WhatsAppHelpCard />
    </div>
  );
}

function UsefulHub({ onOpen, onOpenUs }) {
  return (
    <div className="af-useful-article">
      <UsefulHero
        kicker={appCopy("Menu", "Menu")}
        title={appCopy("Outils", "Tools")}
        subtitle={appCopy(
          "Poster aux US, shadowban, questions, aide — tout ce qu'il faut pour clipper sans se griller.",
          "Post in the US, shadowban, questions, help — everything you need to clip without getting burned."
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

export function AffiliateUsefulPage({ topic, displayName, email, onOpenTopic, onBack, onOpenUs, onOpenShadowbanMethod }) {
  const current = useMemo(
    () => USEFUL_TOPICS.find((row) => row.id === topic) || null,
    [topic]
  );

  if (current?.id === "shadowban") {
    return <ShadowbanTopic onBack={onBack} onOpenMethod={onOpenShadowbanMethod} />;
  }
  if (current?.id === "questions") {
    return <QuestionsTopic displayName={displayName} email={email} onBack={onBack} />;
  }
  if (current?.id === "aide") {
    return <HelpTopic onBack={onBack} />;
  }
  return <UsefulHub onOpen={onOpenTopic} onOpenUs={onOpenUs} />;
}
