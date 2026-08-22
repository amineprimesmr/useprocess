export type Locale = "fr" | "en";

export function t(locale: Locale, fr: string, en: string): string {
  return locale === "en" ? en : fr;
}

export function siteCopy(locale: Locale) {
  return {
    brand: "appmog",
    online: t(locale, "en ligne", "online"),
    visitorsSince: t(locale, "visiteurs", "visitors"),
    claimFor: t(locale, "Prendre la #1 pour", "Claim #1 for"),
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
    placeholder: t(locale, "Lien App Store de ton app", "Your App Store link"),
    outbid: t(locale, "Surenchérir", "Outbid"),
    alreadyOn: t(
      locale,
      "Déjà listé ? Colle le même lien App Store pour monter.",
      "Already listed? Paste the same App Store link to move up.",
    ),
    clicks: t(locale, "clics", "clicks"),
    claimRank: t(locale, "prendre ce rang pour", "claim this rank for"),
    top3: "TOP 3",
    top10: "TOP 10",
    top20: "TOP 20",
    emptyTitle: t(locale, "Le classement est vide", "The board is empty"),
    emptyBody: t(locale, "5 $ suffisent pour la #1.", "$5 is enough for #1."),
    made: t(locale, "Total enchères", "Total bids"),
    sinceLaunch: t(locale, "live depuis", "live for"),
    needUrl: t(locale, "Ajoute le lien App Store de ton app.", "Add your App Store link."),
    needUrlTitle: t(locale, "Colle ton lien App Store", "Paste your App Store link"),
    needUrlBody: t(
      locale,
      "Copie l'URL de ton app sur l'App Store, puis colle-la ici pour enchérir.",
      "Copy your app's URL from the App Store, then paste it here to bid.",
    ),
    invalidUrl: t(locale, "Lien App Store invalide.", "Invalid App Store link."),
    invalidUrlTitle: t(locale, "Lien App Store invalide", "Invalid App Store link"),
    invalidUrlBody: t(
      locale,
      "Utilise un lien apps.apple.com avec l'ID de ton app (ex. …/id123456789).",
      "Use an apps.apple.com link with your app ID (e.g. …/id123456789).",
    ),
    minBid: t(locale, "Enchère minimum : 5 $.", "Minimum bid is $5."),
    maxBid: t(locale, "Enchère maximum : 999 999 $.", "Maximum bid is $999,999."),
    editAmount: t(locale, "Modifier le montant", "Edit amount"),
    raiseOnly: t(locale, "L'enchère doit dépasser ton montant actuel.", "Bid must beat your current amount."),
    checkoutError: t(locale, "Paiement impossible. Réessaie.", "Couldn't open checkout. Try again."),
    redirecting: t(locale, "Ouverture Stripe…", "Opening Stripe…"),
    successTitle: t(locale, "Enchère confirmée", "Bid confirmed"),
    successBody: t(locale, "Tu es sur le board. Rank = bid.", "You're on the board. Rank = bid."),
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
    pageTitle: t(locale, "appmog — Classement d'apps à enchères", "appmog — Public app bid leaderboard"),
    pageDescription: t(
      locale,
      "Paye pour être #1. Classement public d'apps iOS — lien App Store uniquement. Le rang, c'est l'enchère.",
      "Pay to be #1. Public iOS app leaderboard — App Store link only. Rank is the bid.",
    ),
    ogDescription: t(
      locale,
      "Le classement public des apps mobiles. Rank is the bid.",
      "The public mobile app leaderboard. Rank is the bid.",
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
