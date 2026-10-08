package com.process.android

import org.junit.Assert.*
import org.junit.Test

class OnboardingPickerRulesTest {
    @Test fun ageBoundsAndRestoration() {
        assertEquals(25,OnboardingPickerRules.initialAge(0));assertEquals(25,OnboardingPickerRules.initialAge(101))
        for(age in 13..100)assertEquals(age,OnboardingPickerRules.initialAge(age))
    }
    @Test fun heightRestorationUsesProfileThenDefaultAndClamps() {
        assertEquals(180,OnboardingPickerRules.initialHeight(0.0,179.6))
        assertEquals(170,OnboardingPickerRules.initialHeight(Double.NaN,Double.POSITIVE_INFINITY))
        assertEquals(140,OnboardingPickerRules.initialHeight(120.0));assertEquals(220,OnboardingPickerRules.initialHeight(300.0))
        assertEquals(172,OnboardingPickerRules.initialHeight(171.5,190.0))
    }
    @Test fun rulerHas81ContiguousCentimetresAndSafeEndpoints() {
        assertEquals((140..220).toList(),(0..80).map(OnboardingPickerRules::heightForIndex))
        assertEquals(140,OnboardingPickerRules.heightForIndex(-100));assertEquals(220,OnboardingPickerRules.heightForIndex(200))
    }
    @Test fun imperialHeightRoundsTotalInchesBeforeFeetSplit() {
        assertEquals("5'7\"",OnboardingPickerRules.heightLabel(170,ProcessHeightUnit.FT))
        assertEquals("6'0\"",OnboardingPickerRules.heightLabel(183,ProcessHeightUnit.FT))
        assertEquals("170",OnboardingPickerRules.heightLabel(170,ProcessHeightUnit.CM))
    }
    @Test fun ageWheelSourceDistanceGeometryIsSymmetricAndBounded() {
        val center=OnboardingPickerRules.ageTransform(0f);assertEquals(1f,center.scale,0f);assertEquals(1f,center.alpha,0f)
        val adjacent=OnboardingPickerRules.ageTransform(1f);assertEquals(.56f,adjacent.scale,.0001f);assertEquals(.5f,adjacent.alpha,.0001f)
        val edge=OnboardingPickerRules.ageTransform(2.5f);assertEquals(.4f,edge.scale,.0001f);assertEquals(.2f,edge.alpha,.0001f)
        assertEquals(edge,OnboardingPickerRules.ageTransform(10f))
        for(i in 0..25)assertEquals(OnboardingPickerRules.ageTransform(i/10f),OnboardingPickerRules.ageTransform(-i/10f))
    }
}
