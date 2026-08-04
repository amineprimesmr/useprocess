export const MYFIDPASS_MONTHLY_COST = 49.99;

export const REVENUE_SIMULATOR_ASSUMPTIONS = {
  participationRate: 0.14,
  activeMemberRate: 0.58,
  extraVisitPerActiveMember: 0.18,
  basketLiftOnMembers: 0.05,
  reactivationShare: 0.008,
  maxIncrementalShareOfRevenue: 0.06,
  googleReviewsPerActiveMember: 2,
  instagramFollowsPerEnrolledMember: 0.52,
  tiktokFollowsPerEnrolledMember: 0.38,
};

export const REVENUE_SIMULATOR_ENGAGEMENT_CHANNELS = [
  { id: "google", icon: "/assets/logos/google.png", label: "Repas drainants", period: "/sem." },
  { id: "instagram", icon: "/assets/logos/instagram.png", label: "Jours hydratés", period: "/sem." },
  { id: "tiktok", icon: "/assets/logos/tiktok.png", label: "Points debloat", period: "/sem." },
];

export const REVENUE_SIMULATOR_DAYS_PER_MONTH = 30;

export const REVENUE_SIMULATOR_DEFAULTS = {
  dailyVisitors: 14,
  avgBasket: 6,
};

export const REVENUE_SIMULATOR_LIMITS = {
  dailyVisitors: { min: 3, max: 21 },
  avgBasket: { min: 2, max: 10 },
};
