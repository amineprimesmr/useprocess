package com.tenkdesign.android

import kotlin.math.min

/** Original FWTransition geometry, Balaji Venkatesh, 28/08/26. */
data class FlipRect(val x:Float,val y:Float,val width:Float,val height:Float)
object FlipTransitionModel {
    const val MENU_SETTLE_MILLIS=120L
    fun target(windowWidth:Float,windowHeight:Float):FlipRect {
        val width=min(windowWidth*.88f,500f);val height=min(windowHeight*.5f,500f)
        return FlipRect((windowWidth-width)/2,(windowHeight-height)/2,width,height)
    }
    fun frame(source:FlipRect,target:FlipRect,progress:Float):FlipRect {
        val t=progress.coerceIn(0f,1f)
        fun lerp(a:Float,b:Float)=a+(b-a)*t
        return FlipRect(lerp(source.x,target.x),lerp(source.y,target.y),lerp(source.width,target.width),lerp(source.height,target.height))
    }
    fun destinationVisible(progress:Float)=progress>.5f
    fun destinationScale(frame:FlipRect,target:FlipRect)=min(frame.width/target.width,frame.height/target.height)
}
