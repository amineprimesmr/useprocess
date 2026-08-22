export type Locale = "fr" | "en";

export function t(locale: Locale, fr: string, en: string): string {
  return locale === "en" ? en : fr;
}

export function siteCopy(locale: Locale) {
  return {
    brand: "footgoat",
    online: t(locale, "en ligne", "online"),
    visitorsSince: t(locale, "visiteurs", "visitors"),
    claimFor: t(locale, "Obtiens", "Get"),
    claimForJoin: t(locale, "pour", "for"),
    raiseToRank: (rank: number) =>
      locale === "fr" ? `Monter au #${rank} pour` : `Raise to #${rank} for`,
    alreadyOnBoardAt: (amount: string) =>
      t(locale, `Déjà sur le board à ${amount}.`, `Already on the board at ${amount}.`),
    checkoutFullBid: (amount: string) =>
      t(
        locale,
        `Tu paies ${amount} — le rang, c'est l'enchère.`,
        `You pay ${amount} — rank is the bid.`,
      ),
    payBid: (amount: string) => t(locale, `Payer ${amount}`, `Pay ${amount}`),
    heroHint: t(
      locale,
      "Les nouvelles places commencent à 5 $. Payer moins que le #1 te place quand même sur le board.",
      "New spots start at $5. Paying less than #1 still puts you on the board.",
    ),
    placeholder: t(locale, "un joueur", "a player"),
    outbid: t(locale, "Surenchérir", "Outbid"),
    alreadyOn: t(
      locale,
      "Le pseudo s'affiche sur le joueur. Le plus cher est #1.",
      "Your nickname shows on the player. Highest bid is #1.",
    ),
    nickPlaceholder: t(locale, "Ton pseudo", "Your nickname"),
    nickLabel: t(locale, "Pseudo", "Nickname"),
    needNick: t(locale, "Choisis un pseudo pour revendiquer le joueur.", "Pick a nickname to claim the player."),
    needNickTitle: t(locale, "Il te faut un pseudo", "You need a nickname"),
    needNickBody: t(
      locale,
      "2 à 16 caractères : lettres, chiffres ou _. C'est toi sur le classement.",
      "2–16 characters: letters, numbers, or _. That's you on the board.",
    ),
    invalidNick: t(locale, "Pseudo invalide.", "Invalid nickname."),
    ownedBy: (name: string) =>
      locale === "fr" ? `appartient à @${name}` : `owned by @${name}`,
    unclaimed: t(locale, "Libre — enchéris pour le prendre", "Open — bid to claim him"),
    preview: t(locale, "Aperçu", "Preview"),
    noPlayerMatch: t(locale, "Aucun joueur pour cette recherche.", "No player matches that search."),
    playerSuggestions: t(locale, "Joueurs", "Players"),
    clicks: t(locale, "clics", "clicks"),
    claimRank: t(locale, "prendre ce rang pour", "claim this rank for"),
    top3: "TOP 3",
    top10: "TOP 10",
    top20: "TOP 20",
    emptyTitle: t(locale, "Le classement est vide", "The board is empty"),
    emptyBody: t(locale, "5 $ suffisent pour la #1.", "$5 is enough for #1."),
    made: t(locale, "Total enchères", "Total bids"),
    sinceLaunch: t(locale, "live depuis", "live for"),
    needUrl: t(locale, "Choisis un joueur.", "Pick a player."),
    needUrlTitle: t(locale, "Quel joueur ?", "Which player?"),
    needUrlBody: t(
      locale,
      "Tape un nom et sélectionne-le dans la liste.",
      "Type a name and pick him from the list.",
    ),
    invalidUrl: t(locale, "Joueur introuvable.", "Player not found."),
    invalidUrlTitle: t(locale, "Joueur introuvable", "Player not found"),
    invalidUrlBody: t(
      locale,
      "Choisis un joueur dans la liste — Messi, CR7, Yamal…",
      "Pick a player from the list — Messi, CR7, Yamal…",
    ),
    minBid: t(locale, "Enchère minimum : 5 $.", "Minimum bid is $5."),
    maxBid: t(locale, "Enchère maximum : 999 999 $.", "Maximum bid is $999,999."),
    editAmount: t(locale, "Modifier le montant", "Edit amount"),
    raiseOnly: t(locale, "L'enchère doit dépasser ton montant actuel.", "Bid must beat your current amount."),
    checkoutError: t(locale, "Paiement impossible. Réessaie.", "Couldn't open checkout. Try again."),
    redirecting: t(locale, "Ouverture Stripe…", "Opening Stripe…"),
    successTitle: t(locale, "Enchère confirmée", "Bid confirmed"),
    successBody: t(locale, "Tu es sur le board. Rank = bid.", "You're on the board. Rank is the bid."),
    backHome: t(locale, "Retour", "Back"),
    liveLeaderboard: t(locale, "Classement live", "Live leaderboard"),
    amountLabel: t(locale, "Montant", "Amount"),
    increaseLabel: t(locale, "Augmenter", "Increase"),
    seeLeaderboard: t(locale, "Voir le classement ↓", "See leaderboard ↓"),
    checkoutHint: t(
      locale,
      "Le paiement s'ouvre avec l'enchère minimum + 1 $ déjà préremplie pour prendre la place tout de suite.",
      "Checkout opens with the minimum bid + $1 already filled so you take the spot immediately.",
    ),
    confirming: t(locale, "Confirmation en cours…", "Confirming…"),
    navLeader: (title: string) =>
      locale === "fr" ? `#1 : ${title}` : `#1: ${title}`,
    pageTitle: t(locale, "footgoat — Classement de joueurs à enchères", "footgoat — Public football bid leaderboard"),
    pageDescription: t(
      locale,
      "Paye pour être #1. Classement public des joueurs de foot — le rang, c'est l'enchère.",
      "Pay to be #1. Public football player leaderboard — rank is the bid.",
    ),
    ogDescription: t(
      locale,
      "Le classement public des GOAT. Rank is the bid.",
      "The public football GOAT leaderboard. Rank is the bid.",
    ),
  };
}

export function siteMetadata(locale: Locale) {
  const c = siteCopy(locale);
  return {
    title: c.pageTitle,
    description: c.pageDescription,
    ogDescription: c.ogDescription,
  };
}
