const ART: Record<string, string> = {
  "lionel messi": "/players/messi.jpg",
  "lionel andres messi": "/players/messi.jpg",
  "leo messi": "/players/messi.jpg",
  messi: "/players/messi.jpg",
  "cristiano ronaldo": "/players/ronaldo.jpg",
  "cristiano ronaldo dos santos aveiro": "/players/ronaldo.jpg",
  cr7: "/players/ronaldo.jpg",
  "lamine yamal": "/players/yamal.jpg",
  yamal: "/players/yamal.jpg",
  neymar: "/players/neymar.jpg",
  "neymar jr": "/players/neymar.jpg",
  "neymar jr.": "/players/neymar.jpg",
  "neymar da silva santos junior": "/players/neymar.jpg",
  "erling haaland": "/players/haaland.jpg",
  "erling braut haaland": "/players/haaland.jpg",
  haaland: "/players/haaland.jpg",
  "kylian mbappe": "/players/mbappe.jpg",
  "kylian mbappé": "/players/mbappe.jpg",
  mbappe: "/players/mbappe.jpg",
  mbappé: "/players/mbappe.jpg",
  "ronaldo (brazilian footballer)": "/players/r9.jpg",
  "ronaldo nazario": "/players/r9.jpg",
  "ronaldo luís nazário de lima": "/players/r9.jpg",
  "ronaldo luis nazario de lima": "/players/r9.jpg",
  r9: "/players/r9.jpg",
  fenomeno: "/players/r9.jpg",
  "vinicius junior": "/players/vinicius.jpg",
  "vinícius júnior": "/players/vinicius.jpg",
  "vinicius jr": "/players/vinicius.jpg",
  "vini jr": "/players/vinicius.jpg",
  vinicius: "/players/vinicius.jpg",
  "diego maradona": "/players/maradona.jpg",
  "diego armando maradona": "/players/maradona.jpg",
  maradona: "/players/maradona.jpg",
  "jude bellingham": "/players/bellingham.jpg",
  bellingham: "/players/bellingham.jpg",
  "zinedine zidane": "/players/zidane.jpg",
  zidane: "/players/zidane.jpg",
  zizou: "/players/zidane.jpg",
  pele: "/players/pele.jpg",
  pelé: "/players/pele.jpg",
  "edson arantes do nascimento": "/players/pele.jpg",
  "johan cruyff": "/players/cruyff.jpg",
  "johan cruijff": "/players/cruyff.jpg",
  cruyff: "/players/cruyff.jpg",
  "zlatan ibrahimovic": "/players/zlatan.jpg",
  "zlatan ibrahimović": "/players/zlatan.jpg",
  zlatan: "/players/zlatan.jpg",
  ibrahimovic: "/players/zlatan.jpg",
  "karim benzema": "/players/benzema.jpg",
  benzema: "/players/benzema.jpg",
  ronaldinho: "/players/ronaldinho.jpg",
  "ronaldinho gaucho": "/players/ronaldinho.jpg",
  "ronaldo de assis moreira": "/players/ronaldinho.jpg",
  "gareth bale": "/players/bale.jpg",
  bale: "/players/bale.jpg",
  "toni kroos": "/players/kroos.jpg",
  kroos: "/players/kroos.jpg",
  "virgil van dijk": "/players/vandijk.jpg",
  "van dijk": "/players/vandijk.jpg",
  vandijk: "/players/vandijk.jpg",
};

export function normalizePlayerName(raw: string): string {
  return raw
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/^wiki:/, "")
    .replace(/^tm:/, "")
    .replace(/[_-]+/g, " ")
    .replace(/[.’']/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function playerArtUrl(...hints: Array<string | null | undefined>): string | undefined {
  for (const hint of hints) {
    if (!hint) continue;
    const key = normalizePlayerName(hint);
    if (ART[key]) return ART[key];
    for (const [alias, url] of Object.entries(ART)) {
      const a = normalizePlayerName(alias);
      if (key === a || key.endsWith(` ${a}`) || a.endsWith(` ${key}`)) return url;
    }
  }
  return undefined;
}

export function applyPlayerArt<T extends { listingKey?: string; title?: string; icon?: string }>(row: T): T {
  const art = playerArtUrl(row.listingKey, row.title);
  if (!art) return row;
  return { ...row, icon: art };
}
