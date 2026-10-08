package com.process.android
import com.tenkdesign.android.*
import org.junit.Test
import org.junit.Assert.*
class VerificationCodeModelTest {
 @Test fun pastedDigitsAreBoundedAndKeepZeroes(){assertEquals("0012",normalizedVerificationCode("00 12-345",VerificationCodeLength.FOUR))}
 @Test fun unicodeDecimalDigitsAreNormalized(){assertEquals("123456",normalizedVerificationCode("١٢３４𝟝６",VerificationCodeLength.SIX))}
 @Test fun lettersAndNumericSymbolsAreNotOtpDigits(){assertEquals("",normalizedVerificationCode("AB²½",VerificationCodeLength.SIX))}
}
