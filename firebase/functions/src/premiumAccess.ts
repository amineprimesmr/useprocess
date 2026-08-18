import { fetchSubscriber, hasActivePremium } from "./revenueCat";

export const PREMIUM_ENTITLEMENT_ID = "premium";

export async function verifyPremiumSubscriber(
  appUserId: string,
  secretKey: string
): Promise<void> {
  const subscriber = await fetchSubscriber(appUserId, secretKey);
  if (!hasActivePremium(subscriber, PREMIUM_ENTITLEMENT_ID)) {
    throw new Error("PREMIUM_REQUIRED");
  }
}
