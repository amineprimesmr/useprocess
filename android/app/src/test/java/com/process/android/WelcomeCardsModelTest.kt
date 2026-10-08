package com.process.android
import org.junit.Test
import org.junit.Assert.*
class WelcomeCardsModelTest {
 @Test fun welcomeThenReferralDismissalIsMonotonic() {val initial=WelcomeCardDismissal();val referral=initial.dismissTop();assertTrue(referral.frontDismissed);assertFalse(referral.stackDismissed);val hidden=referral.dismissTop();assertEquals(WelcomeCardDismissal(true,true),hidden);assertEquals(hidden,hidden.dismissTop())}
 @Test fun oldStackDismissalImpliesFrontWasDismissed() {assertEquals(WelcomeCardDismissal(true,true),WelcomeCardDismissal(false,true).normalized())}
}
