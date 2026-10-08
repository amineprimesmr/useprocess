package com.process.android

import java.time.Instant
import org.junit.Assert.*
import org.junit.Test

class ProcessCloudContractsTest {
    @Test fun usernameNormalizationPreservesUnicodeAndEnforcesReservedNames() {
        assertEquals("elodie.foo",ProcessUsernameRules.normalize(" @Élodie.Foo_ "))
        assertTrue(ProcessUsernameRules.valid("elodie"));assertFalse(ProcessUsernameRules.valid("admin"));assertFalse(ProcessUsernameRules.valid("1234"))
        assertTrue(ProcessUsernameRules.valid(ProcessUsernameRules.normalize("王小明")))
        assertFalse(ProcessUsernameRules.valid("a".repeat(25)))
    }
    @Test fun profileEditsCannotCarryEntitlementOrIdentityFields() {
        val fields=ProcessProfileEdit(firstName="  Alice ",age=25,heightCm=170.0,weightKg=65.0,gender="female").fields()
        assertEquals(setOf("firstName","age","height","weight","gender"),fields.keys);assertEquals("Alice",fields["firstName"])
        assertTrue(ProcessProfileEdit().fields().isEmpty())
    }
    @Test fun invalidProfileInputIsRejectedBeforeNetwork() {
        listOf(ProcessProfileEdit(age=4),ProcessProfileEdit(weightKg=Double.NaN),ProcessProfileEdit(heightCm=300.0),ProcessProfileEdit(gender="unknown"),ProcessProfileEdit(firstName="anonymous")).forEach {edit->
            assertThrows(IllegalArgumentException::class.java) {edit.fields()}
        }
    }
    @Test fun cloudProfileRejectsAnotherIdentityAndAcceptsFirestoreNumericTypes() {
        val p=ProcessCloudProfile.decode("a",mapOf("userId" to "a","age" to 25L,"height" to 170L,"weight" to 64.5,"isPremium" to true))
        assertEquals(25,p.age);assertEquals(170.0,p.heightCm!!,0.0);assertFalse(p.hasCompletedOnboarding)
        assertThrows(IllegalArgumentException::class.java) {ProcessCloudProfile.decode("a",mapOf("userId" to "b"))}
    }
    @Test fun swiftDateReferenceIsNotUnixAndHandlesNegativeFractions() {
        assertEquals(Instant.parse("2001-01-01T00:00:00Z"),ProcessSwiftDate.decode(0.0))
        assertEquals(Instant.parse("2000-12-31T23:59:59.500Z"),ProcessSwiftDate.decode(-.5))
        assertThrows(IllegalArgumentException::class.java) {ProcessSwiftDate.decode(Double.NaN)}
    }
}
