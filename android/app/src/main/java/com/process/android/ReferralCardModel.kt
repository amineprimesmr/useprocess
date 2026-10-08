package com.process.android
import java.text.Normalizer
import java.util.Locale
import kotlin.math.hypot

data class ReferralCardTilt(val x:Float=0f,val y:Float=0f,val parallaxX:Float=0f,val parallaxY:Float=0f)
object ReferralCardModel {
    fun normalize(raw:String):String {
        val value=Normalizer.normalize(raw.trim().uppercase(Locale.ROOT),Normalizer.Form.NFC)
        val characters=value.codePoints().filter {Character.isLetterOrDigit(it)}.limit(5).toArray()
        return String(characters,0,characters.size)
    }
    fun tilt(x:Float,y:Float,width:Float,height:Float,translationX:Float,translationY:Float):ReferralCardTilt? {
        if(!listOf(x,y,width,height,translationX,translationY).all {it.isFinite()} || width<=1 || height<=1 || hypot(translationX,translationY)<10)return null
        val nx=((x-width/2)/(width/2)).coerceIn(-1f,1f);val ny=((y-height/2)/(height/2)).coerceIn(-1f,1f)
        return ReferralCardTilt(-ny*8,nx*8,nx*6,ny*6*.45f)
    }
}
