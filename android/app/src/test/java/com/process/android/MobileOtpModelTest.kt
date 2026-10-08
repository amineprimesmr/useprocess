package com.process.android
import com.tenkdesign.android.*
import org.junit.Test
import org.junit.Assert.*
class MobileOtpModelTest {
 @Test fun phoneShapeRejectsNationalStringsAndOversize(){assertFalse(isMobileOtpE164("0612345678"));assertFalse(isMobileOtpE164("+0123456"));assertFalse(isMobileOtpE164("+1234567890123456"));assertTrue(isMobileOtpE164("+33612345678"))}
 @Test fun verifiedPhoneMustMatchRequestedPhone(){val verified=MobileOtpVerifiedSession("fixture-user","+15555550123");assertTrue(mobileOtpSessionMatches("+15555550123",verified));assertFalse(mobileOtpSessionMatches("+15555550124",verified))}
 @Test(expected=IllegalArgumentException::class) fun emptyProviderChallengeCannotBeUsed(){MobileOtpChallenge("","+15555550123")}
}
