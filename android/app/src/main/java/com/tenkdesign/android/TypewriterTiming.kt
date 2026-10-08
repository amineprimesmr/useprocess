package com.tenkdesign.android

import kotlin.math.floor

/** Android adaptation of Balaji Venkatesh's TWTextEffect typing curve (31/08/26). */
object TypewriterTiming {
    fun progress(timeSeconds:Double,durationSeconds:Double,characters:Int,pause:Double):Float {
        if(characters<=0 || durationSeconds<=0) return 1f
        if(timeSeconds<=0) return 0f
        if(timeSeconds>=durationSeconds) return 1f
        val position=timeSeconds/durationSeconds*characters
        val index=floor(position);val fraction=position-index;val clamped=pause.coerceIn(0.0,1.0)
        return ((index+if(clamped>=1 || fraction<clamped) 0.0 else (fraction-clamped)/(1-clamped))/characters).toFloat()
    }
    fun opacity(progress:Float,index:Int,count:Int,fade:Boolean):Float {
        val value=(progress*count-index).coerceIn(0f,1f)
        return if(fade) value else if(value>=.5f)1f else 0f
    }
    fun indicator(seconds:Double):Float {
        val phase=((seconds%0.6)+.6)%.6
        return when {phase<.25->(phase/.25).toFloat();phase<.35->1f;else->((.6-phase)/.25).toFloat()}
    }
}
