package com.tenkdesign.android

enum class VerificationCodeLength(val digits:Int) { FOUR(4),SIX(6) }
enum class VerificationCodeStyle { ROUNDED,UNDERLINED }
enum class VerificationCodeState { TYPING,VALID,INVALID }
/** Decimal digits, including pasted Unicode decimal digits, normalized without losing leading zeroes. */
fun normalizedVerificationCode(input:String,length:VerificationCodeLength):String = buildString {
 input.codePoints().forEach { cp ->
  if(this.length<length.digits && Character.getType(cp)==Character.DECIMAL_DIGIT_NUMBER.toInt()) {
   val digit=Character.digit(cp,10);if(digit in 0..9)append(digit)
  }
 }
}
