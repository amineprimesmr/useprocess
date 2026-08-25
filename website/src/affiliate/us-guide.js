export const US_LINKS = {
  hetzner: "https://www.hetzner.com/cloud",
  hetznerConsole: "https://console.hetzner.cloud/",
  outlineGetStarted: "https://getoutline.org/get-started/",
  outlineIos: "https://apps.apple.com/us/app/outline-app/id1356177741",
  outlineAndroid: "https://play.google.com/store/apps/details?id=org.outline.android.client",
  ipCheck: "https://whatismyipaddress.com/",
  appleId: "https://appleid.apple.com/",
  textnow: "https://www.textnow.com/",
};

export const US_BEFORE = [
  {
    fr: "Téléphone dédié, neuf ou reset usine. Pas ton iPhone du quotidien.",
    en: "Dedicated phone, new or factory-reset. Not your daily iPhone.",
  },
  {
    fr: "Setup : English (United States), région United States, clavier English (US).",
    en: "Setup: English (United States), region United States, English (US) keyboard.",
  },
  {
    fr: "Fuseau New York ou Los Angeles — automatique OFF (sinon le Wi‑Fi FR te recale sur Paris).",
    en: "Timezone New York or Los Angeles — automatic OFF (French Wi‑Fi otherwise snaps you back to Paris).",
  },
  {
    fr: "Localisation OFF en global. Plus tard TikTok = Never / Don't allow.",
    en: "Location OFF globally. Later TikTok = Never / Don't allow.",
  },
  {
    fr: "Aucune SIM. Jamais. Wi‑Fi uniquement, à chaque session.",
    en: "No SIM. Ever. Wi‑Fi only, every session.",
  },
  {
    fr: "Email neuf + Apple ID / Google US. Pays = United States, paiement = None. ZIP NY 10001 ou LA 90001.",
    en: "Fresh email + US Apple ID / Google. Country = United States, payment = None. ZIP NY 10001 or LA 90001.",
  },
  {
    fr: "Compte Hetzner Cloud + CB. Crée un token API Read & Write (Security → API Tokens). Ne crée pas le serveur.",
    en: "Hetzner Cloud account + card. Create a Read & Write API token (Security → API Tokens). Don't create the server.",
  },
  {
    fr: "Cursor ou Claude Code ouvert sur le Mac / PC.",
    en: "Cursor or Claude Code open on the Mac / PC.",
  },
];

export const US_AFTER = [
  {
    fr: "PC : Outline Manager → Set up Outline anywhere → colle le JSON → serveur Online (vert).",
    en: "PC: Outline Manager → Set up Outline anywhere → paste the JSON → server Online (green).",
  },
  {
    fr: "+ une clé (ex. iPhone-TikTok) → QR / lien ss://.",
    en: "+ a key (e.g. iPhone-TikTok) → QR / ss:// link.",
  },
  {
    fr: "Téléphone US : Outline Client depuis le store US → scan QR → Connect (icône clé).",
    en: "US phone: Outline Client from the US store → scan QR → Connect (key icon).",
  },
  {
    fr: "Safari : whatismyipaddress.com = United States.",
    en: "Safari: whatismyipaddress.com = United States.",
  },
  {
    fr: "VPN ON → désinstalle TikTok → réinstalle → nouveau compte, country = United States.",
    en: "VPN ON → uninstall TikTok → reinstall → new account, country = United States.",
  },
  {
    fr: "Chaque session : Wi‑Fi (pas de SIM) → Outline Connect → IP USA → ensuite seulement TikTok.",
    en: "Every session: Wi‑Fi (no SIM) → Outline Connect → US IP → only then TikTok.",
  },
];

export const US_AGENT_PROMPT = {
  fr: `# Setup VPN TikTok US — Hetzner Ashburn + Outline

Tu es un agent autonome (Cursor / Claude Code) avec accès shell. Tu fais TOUT le serveur toi-même. N'explique pas les commandes : exécute-les. Ne demande pas à l'humain de copier-coller du SSH si tu peux SSH.

## Ce que l'humain a DÉJÀ fait — ne le refais pas, ne le demande pas
- Téléphone dédié reset, langue English (United States), région United States
- Fuseau New York ou Los Angeles, automatique OFF
- GPS / Location Services OFF
- Aucune SIM, Wi-Fi only
- Email neuf + Apple ID / Google US (ZIP 10001 ou 90001, paiement None)
- Compte Hetzner Cloud vérifié avec CB

Toi tu ne touches PAS au téléphone. Uniquement le VPS + Outline.

## Contraintes dures — une violation = tu t'arrêtes
- Location Hetzner : Ashburn, VA uniquement. Code location \`ash\`. Jamais Falkenstein, Nuremberg, Helsinki, ni aucune région EU.
- Image : ubuntu-22.04
- Type : cx22
- Cloud-init User Data EXACTEMENT (une ligne) :
  #include get.docker.com
- VPN : script officiel Jigsaw Outline uniquement. Pas WireGuard, pas OpenVPN, pas Nord/Express, pas Vultr.
- Firewall Hetzner obligatoire : TCP 22 + port API Outline (TCP) + port d'accès Outline (TCP et UDP)
- Ne crée pas le compte TikTok. Ne poste rien.

## Procédure

### 0. Token Hetzner
Si \`HCLOUD_TOKEN\` ou un contexte \`hcloud\` existe déjà, continue.
Sinon : cherche dans l'env / \`~/.config/hcloud/cli.toml\`. Si rien, demande UNE fois le token (Read & Write, créé dans console.hetzner.cloud → Security → API Tokens).
Installe le CLI si besoin : \`brew install hcloud\` (Mac) ou le binaire officiel.

### 1. Clé SSH
Utilise \`~/.ssh/id_ed25519.pub\` ou \`id_rsa.pub\`. Importe-la dans Hetzner (\`hcloud ssh-key create\`) si elle n'y est pas encore.

### 2. Serveur
\`\`\`
hcloud server create \\
  --name tiktok-us \\
  --type cx22 \\
  --location ash \\
  --image ubuntu-22.04 \\
  --ssh-key <nom-de-la-cle> \\
  --user-data $'#include get.docker.com\\n'
\`\`\`
Attends le statut \`running\`. Récupère l'IPv4 publique.

### 3. SSH
\`ssh -o StrictHostKeyChecking=accept-new root@IP\`

Attends ~90 secondes que cloud-init installe Docker, puis \`docker --version\`.

### 4. Update + Outline
\`\`\`
apt update && apt upgrade -y
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)"
\`\`\`
Si le script demande Docker ? → y. Durée : 1 à 3 minutes.

À « CONGRATULATIONS! », copie le JSON COMPLET entre \`{\` et \`}\` (\`apiUrl\` + \`certSha256\`) et note les DEUX ports affichés.

### 5. Firewall
Crée un firewall \`tiktok-us\` avec :
- TCP 22
- TCP <port API Outline>
- TCP + UDP <port d'accès Outline>
Attache-le au serveur. Vérifie que tu peux encore SSH.

### 6. Recap final — affiche UNIQUEMENT ça à la fin

\`\`\`
SERVER_IP: x.x.x.x
OUTLINE_JSON:
{"apiUrl":"...","certSha256":"..."}

PORTS: 22 / API=xxxx / ACCESS=xxxx (tcp+udp)

TOI ENSUITE (humain, pas l'agent) :
1. PC : Outline Manager → https://getoutline.org/get-started/ → Set up Outline anywhere → colle le JSON → Online vert
2. + une clé (ex. iPhone-TikTok) → QR / ss://
3. Téléphone US : Outline Client (App Store / Play Store US) → scan QR → Connect → icône clé
4. Safari : https://whatismyipaddress.com/ = United States
5. VPN ON → désinstalle TikTok → réinstalle → nouveau compte United States
6. Chaque session : Wi-Fi (pas de SIM) → Outline Connect → IP USA → ENSUITE TikTok

Règle d'or : une ouverture TikTok sans VPN peut brûler le compte.
\`\`\`

## Fallback sans token
Si pas de token : demande IP + mot de passe root (serveur déjà créé à Ashburn, Ubuntu 22.04, CX22, user data \`#include get.docker.com\`). Puis SSH et reprends à l'étape 3.

## Stop
Si Hetzner n'a pas Ashburn, si Outline échoue après 1 retry, ou si tu n'as ni token ni IP : arrête et dis exactement ce qui bloque. Ne bricole pas un VPN EU.
`,
  en: `# US TikTok VPN setup — Hetzner Ashburn + Outline

You are an autonomous agent (Cursor / Claude Code) with shell access. Do the ENTIRE server yourself. Do not explain commands: run them. Do not ask the human to paste SSH if you can SSH.

## What the human ALREADY did — do not redo it, do not ask
- Dedicated factory-reset phone, language English (United States), region United States
- Timezone New York or Los Angeles, automatic OFF
- GPS / Location Services OFF
- No SIM, Wi-Fi only
- Fresh email + US Apple ID / Google (ZIP 10001 or 90001, payment None)
- Hetzner Cloud account verified with a card

You do NOT touch the phone. VPS + Outline only.

## Hard constraints — one violation = stop
- Hetzner location: Ashburn, VA only. Location code \`ash\`. Never Falkenstein, Nuremberg, Helsinki, or any EU region.
- Image: ubuntu-22.04
- Type: cx22
- Cloud-init User Data EXACTLY (one line):
  #include get.docker.com
- VPN: official Jigsaw Outline script only. No WireGuard, no OpenVPN, no Nord/Express, no Vultr.
- Hetzner firewall required: TCP 22 + Outline API port (TCP) + Outline access port (TCP and UDP)
- Do not create the TikTok account. Do not post anything.

## Procedure

### 0. Hetzner token
If \`HCLOUD_TOKEN\` or a \`hcloud\` context already exists, continue.
Otherwise: look in env / \`~/.config/hcloud/cli.toml\`. If nothing, ask ONCE for the token (Read & Write, created in console.hetzner.cloud → Security → API Tokens).
Install the CLI if needed: \`brew install hcloud\` (Mac) or the official binary.

### 1. SSH key
Use \`~/.ssh/id_ed25519.pub\` or \`id_rsa.pub\`. Import it into Hetzner (\`hcloud ssh-key create\`) if it is not there yet.

### 2. Server
\`\`\`
hcloud server create \\
  --name tiktok-us \\
  --type cx22 \\
  --location ash \\
  --image ubuntu-22.04 \\
  --ssh-key <key-name> \\
  --user-data $'#include get.docker.com\\n'
\`\`\`
Wait until status is \`running\`. Grab the public IPv4.

### 3. SSH
\`ssh -o StrictHostKeyChecking=accept-new root@IP\`

Wait ~90 seconds for cloud-init to install Docker, then \`docker --version\`.

### 4. Update + Outline
\`\`\`
apt update && apt upgrade -y
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)"
\`\`\`
If the script asks Docker? → y. Takes 1–3 minutes.

At “CONGRATULATIONS!”, copy the FULL JSON between \`{\` and \`}\` (\`apiUrl\` + \`certSha256\`) and note the TWO ports it printed.

### 5. Firewall
Create a firewall \`tiktok-us\` with:
- TCP 22
- TCP <Outline API port>
- TCP + UDP <Outline access port>
Attach it to the server. Confirm you can still SSH.

### 6. Final recap — print ONLY this at the end

\`\`\`
SERVER_IP: x.x.x.x
OUTLINE_JSON:
{"apiUrl":"...","certSha256":"..."}

PORTS: 22 / API=xxxx / ACCESS=xxxx (tcp+udp)

YOU NEXT (human, not the agent):
1. PC: Outline Manager → https://getoutline.org/get-started/ → Set up Outline anywhere → paste the JSON → Online green
2. + a key (e.g. iPhone-TikTok) → QR / ss://
3. US phone: Outline Client (US App Store / Play Store) → scan QR → Connect → key icon
4. Safari: https://whatismyipaddress.com/ = United States
5. VPN ON → uninstall TikTok → reinstall → new United States account
6. Every session: Wi-Fi (no SIM) → Outline Connect → US IP → THEN TikTok

Golden rule: one TikTok open without VPN can burn the account.
\`\`\`

## Fallback without a token
If there is no token: ask for IP + root password (server already created in Ashburn, Ubuntu 22.04, CX22, user data \`#include get.docker.com\`). Then SSH and resume at step 3.

## Stop
If Hetzner has no Ashburn, if Outline fails after 1 retry, or if you have neither token nor IP: stop and say exactly what blocked you. Do not improvise an EU VPN.
`,
};
