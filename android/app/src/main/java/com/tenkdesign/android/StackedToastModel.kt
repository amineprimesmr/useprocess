package com.tenkdesign.android
import kotlin.math.min
import kotlin.math.max

data class StackedToastGeometry(val stackOffset:Float,val scale:Float,val containerOffset:Float)
object StackedToastModel {
    fun geometry(newestRank:Int,count:Int):StackedToastGeometry {
        val rank=max(newestRank,0)
        return StackedToastGeometry(min(rank*10f,20f),1-min(rank*.05f,.1f),25f-((count-1)*12.5f).coerceIn(0f,25f))
    }
    fun autoDismissMs(seconds:Double?):Long?=seconds?.takeIf {it.isFinite()&&it>=0}?.let {(it*1000).coerceAtMost(Long.MAX_VALUE.toDouble()).toLong()}
    fun dismissGesture(dx:Float,dy:Float)=dx.isFinite()&&dy.isFinite()&&kotlin.math.hypot(dx,dy)>=20f&&dx< -40f
}
