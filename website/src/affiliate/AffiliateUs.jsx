import { useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconCheck, IconCopy, IconExternal } from "./AffiliateIcons.jsx";
import { US_COMMANDS, US_LINKS, US_PARTS } from "./us-guide.js";
import "./affiliate-us.css";

function CopyBlock({ value, label }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      /* ignore */
    }
  }

  return (
    <div className="af-us-copy">
      {label ? <p className="af-us-copy__label">{label}</p> : null}
      <code>{value}</code>
      <button type="button" onClick={copy}>
        {copied ? <IconCheck /> : <IconCopy />}
        {copied ? appCopy("Copié", "Copied") : appCopy("Copier", "Copy")}
      </button>
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

function Step({ n, title, children }) {
  return (
    <article className="af-us-step">
      <header>
        <span>{String(n).padStart(2, "0")}</span>
        <h4>{title}</h4>
      </header>
      <div className="af-us-step__body">{children}</div>
    </article>
  );
}

function Path({ ios, android }) {
  return (
    <dl className="af-us-paths">
      <div>
        <dt>iPhone</dt>
        <dd>{ios}</dd>
      </div>
      <div>
        <dt>Android</dt>
        <dd>{android}</dd>
      </div>
    </dl>
  );
}

export function AffiliateUsPage() {
  function jump(id) {
    document.getElementById(`af-us-${id}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return (
    <div className="af-md af-us">
      <nav className="af-md-toc" aria-label={appCopy("Étapes", "Steps")}>
        {US_PARTS.map((part) => (
          <button key={part.id} type="button" className="af-md-toc__item" onClick={() => jump(part.id)}>
            {part.n}. {appCopy(part.fr, part.en)}
          </button>
        ))}
      </nav>

      <article className="af-md-page">
        <p className="af-md-kicker">{appCopy("Audience US", "US audience")}</p>
        <h2>{appCopy("Poster aux États-Unis", "Post in the United States")}</h2>
        <p className="af-md-lead">
          {appCopy(
            "TikTok lit la langue, la région, le fuseau, le GPS et l'IP. Un seul signal FR = compte détecté. Téléphone dédié US + VPN Ashburn, dans cet ordre.",
            "TikTok reads language, region, timezone, GPS, and IP. One FR signal = the account gets flagged. Dedicated US phone + Ashburn VPN, in that order."
          )}
        </p>

        <p className="af-us-gold">
          {appCopy(
            "Règle d'or : VPN Outline ON avant d'ouvrir TikTok. Une seule ouverture sans VPN peut shadow-ban le compte.",
            "Golden rule: Outline VPN ON before opening TikTok. One open without VPN can shadow-ban the account."
          )}
        </p>

        <section id="af-us-prep" className="af-us-part">
          <h3>
            <span>0</span>
            {appCopy("Prérequis — avant de toucher au téléphone", "Prereqs — before you touch the phone")}
          </h3>
          <ul className="af-us-need">
            <li>
              {appCopy(
                "Un téléphone dédié, neuf ou reset. Pas ton iPhone du quotidien.",
                "A dedicated phone, new or factory-reset. Not your daily iPhone."
              )}
            </li>
            <li>
              {appCopy(
                "Aucune SIM. Jamais. Wi‑Fi uniquement, à chaque session.",
                "No SIM. Ever. Wi‑Fi only, every session."
              )}
            </li>
            <li>
              {appCopy(
                "Un PC (Mac ou Windows) pour Hetzner + Outline Manager.",
                "A PC (Mac or Windows) for Hetzner + Outline Manager."
              )}
            </li>
            <li>
              {appCopy(
                "Carte bancaire pour vérifier Hetzner (~4 € / mois, CX22).",
                "A card to verify Hetzner (~€4 / month, CX22)."
              )}
            </li>
            <li>
              {appCopy(
                "Un email neuf, jamais utilisé sur un compte Apple/Google FR.",
                "A fresh email, never used on a FR Apple/Google account."
              )}
            </li>
            <li>{appCopy("Compte 45–90 min la première fois.", "Budget 45–90 min the first time.")}</li>
          </ul>
        </section>

        <section id="af-us-phone" className="af-us-part">
          <h3>
            <span>1</span>
            {appCopy("Téléphone dédié US", "Dedicated US phone")}
          </h3>
          <p>
            {appCopy(
              "Cette partie est non négociable. Tu configures le téléphone comme si tu vivais aux USA — puis tu ne touches plus à la langue, la région, ni le fuseau.",
              "This part is non-negotiable. Set the phone up as if you live in the US — then never touch language, region, or timezone again."
            )}
          </p>

          <Step n={1} title={appCopy("Reset complet", "Factory reset")}>
            <p>
              {appCopy(
                "Efface tout. Un téléphone déjà utilisé en France garde trop de traces. Après le reset, les menus du téléphone sont en English.",
                "Erase everything. A phone already used in France keeps too many traces. After the reset, the phone menus are in English."
              )}
            </p>
            <Path
              ios={appCopy(
                "Réglages → Général → Transférer ou réinitialiser → Effacer contenu et réglages",
                "Settings → General → Transfer or Reset iPhone → Erase All Content and Settings"
              )}
              android={appCopy(
                "Paramètres → Système → Options de réinitialisation → Effacer toutes les données",
                "Settings → System → Reset options → Erase all data"
              )}
            />
          </Step>

          <Step n={2} title={appCopy("Setup assistant 100 % US", "100% US setup assistant")}>
            <p>
              {appCopy(
                "À l'écran de bienvenue, choisis exactement ça — et ne change plus jamais :",
                "On the welcome screen, pick exactly this — and never change it:"
              )}
            </p>
            <ul>
              <li>
                {appCopy("Langue : English (United States)", "Language: English (United States)")}
              </li>
              <li>{appCopy("Région / pays : United States", "Region / country: United States")}</li>
              <li>
                {appCopy(
                  "Fuseau : New York ou Los Angeles — automatique OFF (sinon le Wi‑Fi FR te recale sur Paris).",
                  "Timezone: New York or Los Angeles — automatic OFF (otherwise French Wi‑Fi snaps you back to Paris)."
                )}
              </li>
              <li>{appCopy("Clavier : English (US)", "Keyboard: English (US)")}</li>
            </ul>
          </Step>

          <Step n={3} title={appCopy("Nouvel Apple ID / Google US", "New US Apple ID / Google")}>
            <p>
              {appCopy(
                "Pas ton compte existant. Nouveau compte, pays = United States, code postal US, paiement = None.",
                "Not your existing account. New account, country = United States, US ZIP, payment = None."
              )}
            </p>
            <ul>
              <li>
                {appCopy("Code postal New York :", "New York ZIP:")} <strong>10001</strong>
              </li>
              <li>
                {appCopy("Code postal Los Angeles :", "Los Angeles ZIP:")} <strong>90001</strong>
              </li>
            </ul>
            <Ext href={US_LINKS.appleId}>appleid.apple.com</Ext>
          </Step>

          <Step n={4} title={appCopy("Localisation OFF, pour de bon", "Location OFF, permanently")}>
            <p>
              {appCopy(
                "GPS éteint en global, et TikTok = Never / Don't allow.",
                "GPS off globally, and TikTok = Never / Don't allow."
              )}
            </p>
            <Path
              ios="Settings → Privacy & Security → Location Services → Off. Later, TikTok → Never."
              android="Settings → Location → Off. Later, TikTok → Don't allow."
            />
          </Step>

          <Step n={5} title={appCopy("Wi‑Fi only — jamais de SIM, jamais de 4G", "Wi‑Fi only — never a SIM, never cellular")}>
            <p>
              {appCopy(
                "Une SIM envoie le code opérateur (MCC/MNC) = France, même derrière un VPN. Mode avion + Wi‑Fi, ou cellulaire coupé.",
                "A SIM sends the carrier code (MCC/MNC) = France, even behind a VPN. Airplane mode + Wi‑Fi, or cellular off."
              )}
            </p>
          </Step>
        </section>

        <section id="af-us-hetzner" className="af-us-part">
          <h3>
            <span>2</span>
            {appCopy("Serveur Hetzner aux USA", "Hetzner server in the USA")}
          </h3>

          <Step n={6} title={appCopy("Créer le compte Cloud", "Create the Cloud account")}>
            <p>
              {appCopy(
                "Hetzner Cloud, pas Robot. Ils demandent une CB — normal. Le crédit offert couvre les premiers jours.",
                "Hetzner Cloud, not Robot. They ask for a card — that's normal. The free credit covers the first days."
              )}
            </p>
            <Ext href={US_LINKS.hetzner}>hetzner.com/cloud</Ext>
          </Step>

          <Step n={7} title={appCopy("Nouveau projet + Add Server", "New project + Add Server")}>
            <p>
              {appCopy(
                "Dans la console : New Project → nom (ex. TikTok-US) → Add Server.",
                "In the console: New Project → name (e.g. TikTok-US) → Add Server."
              )}
            </p>
            <Ext href={US_LINKS.hetznerConsole}>console.hetzner.cloud</Ext>
          </Step>

          <Step n={8} title={appCopy("Réglages du serveur — tout se joue ici", "Server settings — this is the whole point")}>
            <ul>
              <li>
                <strong>Location :</strong>{" "}
                {appCopy(
                  "Ashburn, VA (USA). Obligatoire. Pas Falkenstein, pas Helsinki.",
                  "Ashburn, VA (USA). Mandatory. Not Falkenstein, not Helsinki."
                )}
              </li>
              <li>
                <strong>Image :</strong> Ubuntu 22.04
              </li>
              <li>
                <strong>Type :</strong>{" "}
                {appCopy("CX22 (~4 €/mois). Suffisant.", "CX22 (~€4/month). Enough.")}
              </li>
              <li>
                <strong>User Data :</strong>{" "}
                {appCopy("colle exactement :", "paste exactly:")}
              </li>
            </ul>
            <CopyBlock
              value={US_COMMANDS.dockerUserData}
              label={appCopy("Cloud-init — installe Docker tout seul", "Cloud-init — installs Docker for you")}
            />
            <p>
              {appCopy(
                "Laisse le reste par défaut. Create & Buy Now. Note l'IP. Le mot de passe root arrive par email.",
                "Leave the rest default. Create & Buy Now. Note the IP. The root password arrives by email."
              )}
            </p>
          </Step>
        </section>

        <section id="af-us-ssh" className="af-us-part">
          <h3>
            <span>3</span>
            {appCopy("Connexion SSH", "SSH connection")}
          </h3>

          <Step n={9} title={appCopy("Ouvrir le terminal", "Open Terminal")}>
            <ul>
              <li>{appCopy("Mac : Spotlight → Terminal", "Mac: Spotlight → Terminal")}</li>
              <li>
                {appCopy(
                  "Windows : Windows + R → cmd → Entrée",
                  "Windows: Windows + R → cmd → Enter"
                )}
              </li>
            </ul>
          </Step>

          <Step n={10} title={appCopy("Se connecter", "Connect")}>
            <p>
              {appCopy(
                "Remplace TON_IP par l'IP Hetzner. Si on te demande « continue connecting? » → yes. Le mot de passe ne s'affiche pas quand tu tapes : normal.",
                "Replace TON_IP with the Hetzner IP. If it asks “continue connecting?” → yes. The password doesn't echo as you type: that's normal."
              )}
            </p>
            <CopyBlock value={US_COMMANDS.ssh} />
          </Step>

          <Step n={11} title={appCopy("Mettre à jour Ubuntu", "Update Ubuntu")}>
            <p>{appCopy("Une fois connecté, lance :", "Once connected, run:")}</p>
            <CopyBlock value={US_COMMANDS.update} />
          </Step>
        </section>

        <section id="af-us-outline" className="af-us-part">
          <h3>
            <span>4</span>
            {appCopy("Installer Outline sur le serveur", "Install Outline on the server")}
          </h3>

          <Step n={12} title={appCopy("Lancer le script officiel", "Run the official script")}>
            <p>
              {appCopy(
                "Colle ça dans le SSH. Si Docker ? → y. 1 à 3 minutes.",
                "Paste this in SSH. If Docker? → y. 1 to 3 minutes."
              )}
            </p>
            <CopyBlock value={US_COMMANDS.outline} />
          </Step>

          <Step n={13} title={appCopy("Copier le JSON vert — ne le perds pas", "Copy the green JSON — don't lose it")}>
            <p>
              {appCopy(
                "À « CONGRATULATIONS! », copie TOUT le bloc entre { et } — apiUrl + certSha256. Ça ressemble à :",
                "At “CONGRATULATIONS!”, copy the WHOLE block between { and } — apiUrl + certSha256. It looks like:"
              )}
            </p>
            <p className="af-us-example">
              {`{"apiUrl":"https://TON_IP:XXXX/xxxxx","certSha256":"XXXX"}`}
            </p>
          </Step>

          <Step n={14} title={appCopy("Ouvrir les ports Hetzner", "Open the Hetzner ports")}>
            <p>
              {appCopy(
                "Le script affiche DEUX ports (ex. 6311 et 48682). Les tiens sont uniques. Console → Firewalls → Create Firewall. Ajoute aussi SSH, sinon tu te fermes la porte.",
                "The script prints TWO ports (e.g. 6311 and 48682). Yours are unique. Console → Firewalls → Create Firewall. Also add SSH, or you lock yourself out."
              )}
            </p>
            <ul>
              <li>
                <strong>TCP 22</strong> — SSH
              </li>
              <li>
                <strong>TCP</strong> {appCopy("port API (le premier)", "API port (the first one)")}
              </li>
              <li>
                <strong>TCP + UDP</strong> {appCopy("port d'accès (le second)", "access port (the second one)")}
              </li>
            </ul>
            <p>
              {appCopy("Attache le firewall au serveur.", "Attach the firewall to the server.")}
            </p>
            <Ext href={US_LINKS.hetznerConsole}>console.hetzner.cloud</Ext>
          </Step>
        </section>

        <section id="af-us-manager" className="af-us-part">
          <h3>
            <span>5</span>
            {appCopy("Outline Manager sur le PC", "Outline Manager on the PC")}
          </h3>

          <Step n={15} title={appCopy("Télécharger Manager", "Download Manager")}>
            <p>
              {appCopy(
                "Windows ou Mac. C'est l'app bureau, pas l'app téléphone.",
                "Windows or Mac. This is the desktop app, not the phone app."
              )}
            </p>
            <Ext href={US_LINKS.outlineGetStarted}>getoutline.org/get-started</Ext>
          </Step>

          <Step n={16} title={appCopy("Coller le JSON", "Paste the JSON")}>
            <p>
              {appCopy(
                "Set up Outline anywhere → colle le JSON de l'étape 13 → Done. Le serveur doit passer Online (vert).",
                "Set up Outline anywhere → paste the JSON from step 13 → Done. The server should go Online (green)."
              )}
            </p>
          </Step>

          <Step n={17} title={appCopy("Créer la clé iPhone / Android", "Create the iPhone / Android key")}>
            <p>
              {appCopy(
                "+ en bas → nom (ex. iPhone-TikTok) → icône partager. Tu obtiens un lien ss://… et un QR code. Garde-les pour l'étape suivante.",
                "+ at the bottom → name (e.g. iPhone-TikTok) → share icon. You get an ss://… link and a QR code. Keep them for the next step."
              )}
            </p>
          </Step>
        </section>

        <section id="af-us-vpn" className="af-us-part">
          <h3>
            <span>6</span>
            {appCopy("VPN sur le téléphone dédié", "VPN on the dedicated phone")}
          </h3>

          <Step n={18} title={appCopy("Installer Outline Client", "Install Outline Client")}>
            <p>
              {appCopy(
                "Sur le téléphone US, depuis l'App Store / Play Store US. Toujours Outline Client, pas un VPN random.",
                "On the US phone, from the US App Store / Play Store. Always Outline Client, not a random VPN."
              )}
            </p>
            <div className="af-us-links">
              <Ext href={US_LINKS.outlineIos}>Outline iOS</Ext>
              <Ext href={US_LINKS.outlineAndroid}>Outline Android</Ext>
            </div>
          </Step>

          <Step n={19} title={appCopy("Connecter la clé", "Connect the key")}>
            <p>
              {appCopy(
                "Ouvre Outline → + → scanne le QR (ou colle ss://). Connect. Une icône clé = IP américaine.",
                "Open Outline → + → scan the QR (or paste ss://). Connect. A key icon = US IP."
              )}
            </p>
            <p>
              {appCopy("Vérifie tout de suite :", "Check right away:")}{" "}
              <Ext href={US_LINKS.ipCheck}>whatismyipaddress.com</Ext>
              {appCopy(" → United States.", " → United States.")}
            </p>
          </Step>
        </section>

        <section id="af-us-tiktok" className="af-us-part">
          <h3>
            <span>7</span>
            {appCopy("Compte TikTok US", "US TikTok account")}
          </h3>

          <Step n={20} title={appCopy("Réinstaller TikTok sous VPN", "Reinstall TikTok under VPN")}>
            <p>
              {appCopy(
                "VPN ON → désinstalle TikTok → réinstalle depuis le store US → ouvre TikTok (VPN toujours ON) → nouveau compte, country = United States.",
                "VPN ON → uninstall TikTok → reinstall from the US store → open TikTok (VPN still ON) → new account, country = United States."
              )}
            </p>
            <p>
              {appCopy(
                "Email neuf créé sous VPN, ou numéro US (TextNow, optionnel).",
                "Fresh email created under VPN, or a US number (TextNow, optional)."
              )}{" "}
              <Ext href={US_LINKS.textnow}>textnow.com</Ext>
            </p>
          </Step>

          <Step n={21} title={appCopy("Chaque session, dans cet ordre", "Every session, in this order")}>
            <ol>
              <li>{appCopy("Wi‑Fi, pas de SIM.", "Wi‑Fi, no SIM.")}</li>
              <li>{appCopy("Outline → Connect (icône clé).", "Outline → Connect (key icon).")}</li>
              <li>
                {appCopy("whatismyipaddress.com = USA.", "whatismyipaddress.com = USA.")}
              </li>
              <li>{appCopy("Ensuite seulement, TikTok.", "Only then, TikTok.")}</li>
            </ol>
          </Step>
        </section>

        <section id="af-us-check" className="af-us-part">
          <h3>
            <span>8</span>
            {appCopy("Check final — ne poste pas avant ça", "Final check — don't post before this")}
          </h3>
          <ul className="af-us-check">
            <li>
              {appCopy(
                "Langue English (US), région United States, fuseau US, auto-timezone OFF.",
                "Language English (US), region United States, US timezone, auto-timezone OFF."
              )}
            </li>
            <li>{appCopy("Localisation OFF. TikTok = Never.", "Location OFF. TikTok = Never.")}</li>
            <li>{appCopy("Aucune SIM. Wi‑Fi only.", "No SIM. Wi‑Fi only.")}</li>
            <li>
              {appCopy("IP = USA sur ", "IP = USA on ")}
              <Ext href={US_LINKS.ipCheck}>whatismyipaddress.com</Ext>
            </li>
            <li>
              {appCopy(
                "Outline Manager : serveur Online (vert).",
                "Outline Manager: server Online (green)."
              )}
            </li>
            <li>
              {appCopy(
                "TikTok → Settings → Privacy → Country/Region = United States.",
                "TikTok → Settings → Privacy → Country/Region = United States."
              )}
            </li>
          </ul>
          <p className="af-md-callout">
            {appCopy(
              "Si un check est rouge, n'ouvre pas TikTok. Corrige d'abord. Un leak FR suffit à brûler le compte.",
              "If any check is red, don't open TikTok. Fix it first. One FR leak is enough to burn the account."
            )}
          </p>
        </section>
      </article>
    </div>
  );
}
