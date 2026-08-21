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
    invalidUrl: t(locale, "Lien App Store invalide.", "Invalid App Store link."),
    minBid: t(locale, "Enchère minimum : 5 $.", "Minimum bid is $5."),
    raiseOnly: t(locale, "L'enchère doit dépasser ton montant actuel.", "Bid must beat your current amount."),
    checkoutError: t(locale, "Paiement impossible. Réessaie.", "Couldn't open checkout. Try again."),
    redirecting: t(locale, "Ouverture Stripe…", "Opening Stripe…"),
    successTitle: t(locale, "Enchère confirmée", "Bid confirmed"),
    successBody: t(locale, "Tu es sur le board. Rank = bid.", "You're on the board. Rank = bid."),
    backHome: t(locale, "Retour", "Back"),
  };
}
