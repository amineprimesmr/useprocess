package com.process.android

import java.text.Normalizer
import java.time.Instant
import java.util.Locale

object ProcessUsernameRules {
    private val reserved=setOf("process","admin","support","help","api","www","null","user","profil","profile","coach","sante","health","system","official","moderator","mod","team","staff","root","anonymous","guest")
    fun normalize(raw:String):String {
        val clean=Normalizer.normalize(raw.trim().lowercase(Locale.ROOT),Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"")
        val result=StringBuilder()
        clean.codePoints().forEach {if(Character.isLetter(it)||Character.isDigit(it)||it==95||it==46)result.appendCodePoint(it)}
        return result.toString().trim('.','_')
    }
    fun valid(tag:String):Boolean {
        val points=tag.codePoints().toArray()
        return points.size in 3..24&&points.isNotEmpty()&&(Character.isLetter(points.first())||Character.isDigit(points.first()))&&points.any {Character.isLetter(it)}&&tag !in reserved&&tag==normalize(tag)
    }
}

/** Only these editable fields may be sent; entitlement and server-owned state are never copied back. */
data class ProcessProfileEdit(val firstName:String?=null,val age:Int?=null,val heightCm:Double?=null,val weightKg:Double?=null,val gender:String?=null) {
    fun fields():Map<String,Any> = buildMap {
        firstName?.let {require(OnboardingInputRules.isRealName(it));put("firstName",OnboardingInputRules.trimName(it))}
        age?.let {require(it in 13..100);put("age",it)}
        heightCm?.let {require(it.isFinite()&&it in 140.0..220.0);put("height",it)}
        weightKg?.let {require(OnboardingInputRules.plausibleWeight(it));put("weight",it)}
        gender?.let {require(it in listOf("male","female","other","prefer_not_to_say"));put("gender",it)}
    }
}
data class ProcessCloudProfile(val userId:String,val firstName:String,val age:Int?,val heightCm:Double?,val weightKg:Double?,val gender:String?,val username:String?,val hasCompletedOnboarding:Boolean) {
    companion object {
        fun decode(userId:String,data:Map<String,Any>):ProcessCloudProfile {
            require(data["userId"]==null||data["userId"]==userId)
            fun number(key:String)=(data[key] as? Number)?.toDouble()?.takeIf {it.isFinite()}
            return ProcessCloudProfile(userId,data["firstName"] as? String?:"",number("age")?.toInt(),number("height"),number("weight"),data["gender"] as? String,data["username"] as? String,data["hasCompletedOnboarding"] as? Boolean?:false)
        }
    }
}
/** Swift JSONEncoder's default Date uses seconds from 2001-01-01, not Unix milliseconds. */
object ProcessSwiftDate {
    private const val REFERENCE_EPOCH=978307200L
    fun decode(seconds:Double):Instant {
        require(seconds.isFinite()&&seconds in -1e11..1e11)
        val whole=kotlin.math.floor(seconds).toLong()
        return Instant.ofEpochSecond(REFERENCE_EPOCH+whole,((seconds-whole)*1e9).toLong())
    }
}
