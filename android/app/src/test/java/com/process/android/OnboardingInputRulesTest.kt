package com.process.android

import org.junit.Assert.*
import org.junit.Test

class OnboardingInputRulesTest {
    @Test fun namesBootstrapInSourcePriorityWithoutAcceptingPlaceholders() {
        assertEquals("Amine",OnboardingInputRules.initialName("Amine","Other","Last"))
        assertEquals("Émilie",OnboardingInputRules.initialName("Process","Émilie","Last"))
        assertEquals("Last",OnboardingInputRules.initialName("", "anonymous", "Last"))
        assertEquals("",OnboardingInputRules.initialName("USER", "Process AI", null))
        assertFalse(OnboardingInputRules.isRealName("\u00a0 \n"))
        assertEquals("Anne-Marie",OnboardingInputRules.trimName("\u00a0Anne-Marie\n"))
    }
    @Test fun usernameBaseMatchesOriginalDiacriticsAndSeparators() {
        assertEquals("elodieanne",OnboardingInputRules.usernameBase(" Élodie-Anne "))
        assertEquals("jeanluc",OnboardingInputRules.usernameBase("Jean Luc"))
    }
    @Test fun weightParserNormalizesInternationalDigitsAndOneDecimalSeparator() {
        assertEquals("72.5",OnboardingInputRules.normalizeWeight("٧٢,٥"))
        assertEquals("72.5",OnboardingInputRules.normalizeWeight("७२.५"))
        assertEquals(".1234",OnboardingInputRules.normalizeWeight("..1,2x3 4 5"))
        assertEquals("12345",OnboardingInputRules.normalizeWeight("123456789"))
        assertEquals("",OnboardingInputRules.normalizeWeight("abc"))
    }
    @Test fun validationAlwaysUsesKgIncludingImperialInput() {
        assertTrue(OnboardingInputRules.plausibleWeight(OnboardingInputRules.kilograms("160",ProcessWeightUnit.LBS)))
        assertFalse(OnboardingInputRules.plausibleWeight(OnboardingInputRules.kilograms("60",ProcessWeightUnit.LBS)))
        assertFalse(OnboardingInputRules.plausibleWeight(OnboardingInputRules.kilograms("600",ProcessWeightUnit.LBS)))
        assertTrue(OnboardingInputRules.plausibleWeight(35.0));assertTrue(OnboardingInputRules.plausibleWeight(250.0))
        assertFalse(OnboardingInputRules.plausibleWeight(Double.NaN));assertFalse(OnboardingInputRules.plausibleWeight(Double.POSITIVE_INFINITY))
    }
    @Test fun unitPresentationUsesOriginalFactorAndOneDecimalFormatting() {
        val kg=72.5
        assertEquals("159.8",OnboardingInputRules.displayWeight(kg,ProcessWeightUnit.LBS))
        assertEquals("72.5",OnboardingInputRules.displayWeight(kg,ProcessWeightUnit.KG))
        assertEquals("70",OnboardingInputRules.displayWeight(70.0,ProcessWeightUnit.KG))
        assertEquals("",OnboardingInputRules.displayWeight(0.0,ProcessWeightUnit.KG))
    }
}
