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

export const US_COMMANDS = {
  dockerUserData: "#include get.docker.com",
  ssh: "ssh root@TON_IP",
  update: "apt update && apt upgrade -y",
  outline:
    'sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)"',
};

export const US_PARTS = [
  { id: "prep", n: "0", fr: "Prérequis", en: "Prereqs" },
  { id: "phone", n: "1", fr: "Téléphone", en: "Phone" },
  { id: "hetzner", n: "2", fr: "Serveur US", en: "US server" },
  { id: "ssh", n: "3", fr: "SSH", en: "SSH" },
  { id: "outline", n: "4", fr: "Outline serveur", en: "Outline server" },
  { id: "manager", n: "5", fr: "Manager", en: "Manager" },
  { id: "vpn", n: "6", fr: "VPN téléphone", en: "Phone VPN" },
  { id: "tiktok", n: "7", fr: "TikTok US", en: "US TikTok" },
  { id: "check", n: "8", fr: "Check", en: "Check" },
];
