const DRAFT_KEY = "process.affiliate.onboarding.v2";
const UNLOCK_PREFIX = "process.affiliate.unlocked.";

export const ONBOARDING_STEPS = [
  "firstName",
  "hours",
  "budget",
  "experience",
  "tiktokHandle",
  "goal",
  "terms",
  "opening",
  "stripe",
  "preview",
  "invite",
];

const QUESTION_STEPS = new Set([
  "firstName",
  "hours",
  "budget",
  "experience",
  "tiktokHandle",
  "goal",
  "terms",
]);

export function normalizeOnboardingAnswers(answers) {
  const next = { ...emptyOnboardingAnswers(), ...(answers || {}) };
  const fromList = Array.isArray(next.tiktokHandles)
    ? next.tiktokHandles.map((value) => String(value || ""))
    : [];
  const fromSingle = String(next.tiktokHandle || "")
    .split(/[\s,]+/)
    .map((value) => value.trim())
    .filter(Boolean);
  const handles = (fromList.length ? fromList : fromSingle).slice(0, 8);
  next.tiktokHandles = handles.length ? handles : [""];
  next.tiktokHandle = next.tiktokHandles.map((value) => value.trim()).filter(Boolean).join(" ");
  const fromCount = Number(next.accountCount);
  const fromGoal = Number(next.goal);
  const legacyGoal = { side: 1, replace: 3, agency: 5 }[next.goal];
  const accountCount = Number.isFinite(fromCount) && fromCount >= 1
    ? Math.min(5, Math.round(fromCount))
    : Number.isFinite(fromGoal) && fromGoal >= 1
      ? Math.min(5, Math.round(fromGoal))
      : legacyGoal || 0;
  next.accountCount = accountCount || "";
  if (accountCount) next.goal = String(accountCount);
  return next;
}

export function emptyOnboardingAnswers() {
  return {
    firstName: "",
    postedTiktok: "",
    tiktokHandle: "",
    tiktokHandles: [""],
    hoursPerDay: "",
    toolBudget: "",
    experience: "",
    goal: "",
    accountCount: "",
  };
}

export function emptyOnboardingDraft() {
  return {
    step: "firstName",
    answers: emptyOnboardingAnswers(),
    applied: false,
    stripeStarted: false,
    stripeDone: false,
  };
}

export function readOnboardingDraft() {
  try {
    const raw = window.localStorage.getItem(DRAFT_KEY);
    if (!raw) return emptyOnboardingDraft();
    const parsed = JSON.parse(raw);
    const rawStep = parsed?.step === "account" ? "invite" : parsed?.step;
    const remapped =
      rawStep === "validated" ? "stripe" : rawStep === "postedTiktok" ? "hours" : rawStep;
    const step = remapped;
    return {
      ...emptyOnboardingDraft(),
      ...parsed,
      step,
      answers: normalizeOnboardingAnswers({
        ...emptyOnboardingAnswers(),
        ...(parsed?.answers || {}),
      }),
    };
  } catch {
    return emptyOnboardingDraft();
  }
}

export function writeOnboardingDraft(next) {
  try {
    window.localStorage.setItem(DRAFT_KEY, JSON.stringify(next));
  } catch {
    /* private mode */
  }
}

export function syncOnboardingDraftFromStripeReturn() {
  const draft = readOnboardingDraft();
  try {
    const raw = (window.location.hash || "").replace(/^#\/?/, "");
    const query = raw.split("?")[1];
    if (!query) return draft;
    const params = Object.fromEntries(new URLSearchParams(query));
    if (params.stripe !== "return" && params.stripe !== "refresh") return draft;
    if (!draft.applied) return draft;
    const next = {
      ...draft,
      stripeDone: true,
      stripeStarted: true,
      step: "preview",
    };
    writeOnboardingDraft(next);
    return next;
  } catch {
    return draft;
  }
}

export function clearOnboardingDraft() {
  try {
    window.localStorage.removeItem(DRAFT_KEY);
  } catch {
    /* ignore */
  }
}

export function isOnboardingInProgress() {
  const draft = readOnboardingDraft();
  return Boolean(draft.applied && !isOnboardingUnlocked());
}

export function unlockKey(uid) {
  return `${UNLOCK_PREFIX}${uid || "anon"}`;
}

export function isOnboardingUnlocked(uid) {
  if (!uid) {
    try {
      return Boolean(window.localStorage.getItem(UNLOCK_PREFIX + "anon"));
    } catch {
      return false;
    }
  }
  try {
    return window.localStorage.getItem(unlockKey(uid)) === "1";
  } catch {
    return false;
  }
}

export function markOnboardingUnlocked(uid) {
  try {
    window.localStorage.setItem(unlockKey(uid), "1");
  } catch {
    /* ignore */
  }
  clearOnboardingDraft();
}

export function questionStepIndex(step) {
  const list = [...QUESTION_STEPS];
  const index = list.indexOf(step);
  return index < 0 ? list.length : index;
}

export function questionStepCount() {
  return QUESTION_STEPS.size;
}

export function isQuestionStep(step) {
  return QUESTION_STEPS.has(step);
}

export function nextOnboardingStep(step) {
  const index = ONBOARDING_STEPS.indexOf(step);
  return ONBOARDING_STEPS[Math.min(index + 1, ONBOARDING_STEPS.length - 1)];
}

export function prevOnboardingStep(step) {
  const index = ONBOARDING_STEPS.indexOf(step);
  return ONBOARDING_STEPS[Math.max(index - 1, 0)];
}

export function codeFromFirstName(name) {
  const cleaned = String(name || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^A-Za-z0-9]/g, "")
    .toUpperCase();
  const base = cleaned.slice(0, 10);
  if (base.length >= 3) return base;
  return `${base}PRO`.slice(0, 12);
}
