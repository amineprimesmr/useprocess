package com.tenkdesign.android

data class MobileOtpCountry(val name:String,val dialCode:String?,val code:String)
data class MobileOtpChallenge(val id:String,val e164:String) {init {require(id.isNotBlank());require(isMobileOtpE164(e164))}}
data class MobileOtpVerifiedSession(val uid:String,val e164:String) {init {require(uid.isNotBlank());require(isMobileOtpE164(e164))}}
sealed interface MobileOtpSendResult {
 data class Sent(val challenge:MobileOtpChallenge):MobileOtpSendResult
 data class Verified(val session:MobileOtpVerifiedSession):MobileOtpSendResult
}
/** Implement with a real authentication provider; never accept an arbitrary local "logged in" flag. */
interface MobileOtpService {
 suspend fun send(e164:String):MobileOtpSendResult
 suspend fun verify(challenge:MobileOtpChallenge,code:String):MobileOtpVerifiedSession
}
fun isMobileOtpE164(value:String):Boolean=Regex("\\+[1-9][0-9]{1,14}").matches(value)
/** Transport shape only; the host must resolve/validate national numbers using current numbering metadata. */
fun mobileOtpSessionMatches(expectedPhone:String,session:MobileOtpVerifiedSession)=expectedPhone==session.e164
