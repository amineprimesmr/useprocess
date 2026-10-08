package com.process.android
import org.junit.Assert.*
import org.junit.Test

class OnboardingStepTest {
    @Test fun liveIdsRoundTripAndAreUnique() {
        assertEquals(OnboardingStep.entries.size,OnboardingStep.entries.map { it.id }.toSet().size)
        OnboardingStep.entries.forEach { assertEquals(it,OnboardingStep.resolve(it.id)) }
    }
    @Test fun legacyMigrationsPreserveResumeDestination() {
        assertEquals(OnboardingStep.Motivation,OnboardingStep.resolve(5))
        assertEquals(OnboardingStep.Creation,OnboardingStep.resolve(24))
        assertEquals(OnboardingStep.Creation,OnboardingStep.resolve(41))
        assertEquals(OnboardingStep.Biometric,OnboardingStep.resolve(51))
        assertEquals(OnboardingStep.Weight,OnboardingStep.resolve(68))
        assertEquals(OnboardingStep.Gender,OnboardingStep.resolve(-1))
    }
    @Test fun visibleNavigationSkipsTechnicalFinalizationAndOptionalReferral() {
        assertEquals(OnboardingStep.Weight,OnboardingStep.Height.nextVisible())
        assertEquals(OnboardingStep.Referral,OnboardingStep.Transformation.nextVisible())
        assertEquals(OnboardingStep.Commitment,OnboardingStep.Transformation.nextVisible(false))
        assertNull(OnboardingStep.SignIn.nextVisible())
        assertFalse(OnboardingStep.visibleFlow().contains(OnboardingStep.Complete))
    }
    @Test fun unpaidResumeAvoidsReplayingPurchase() {
        assertEquals(OnboardingStep.Commitment,OnboardingStep.Payment.unpaidResume)
        assertEquals(OnboardingStep.Commitment,OnboardingStep.SignIn.unpaidResume)
        assertEquals(OnboardingStep.Age,OnboardingStep.Age.unpaidResume)
    }
}
