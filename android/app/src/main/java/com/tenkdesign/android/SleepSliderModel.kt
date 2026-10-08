package com.tenkdesign.android

import kotlin.math.*
import java.util.Locale

/** BTSlider: Balaji Venkatesh, 05/09/26. */
data class SleepRange(val start:Double=0.0,val end:Double=.5)
object SleepSliderModel {
    fun wrap(value:Double)=if(value.isFinite())((value%1)+1)%1 else 0.0
    fun move(range:SleepRange,start:Boolean,target:Double,minimum:Double=.1):SleepRange {
        val next=wrap(target);val a=wrap(range.start);val b=wrap(range.end)
        val other=if(start)b else a;val diff=abs(next-other)
        return if(min(diff,1-diff)<minimum.coerceIn(0.0,.5)) {
            val delta=next-if(start)a else b
            SleepRange(wrap(a+delta),wrap(b+delta))
        } else if(start)SleepRange(next,b) else SleepRange(a,next)
    }
    fun progressAt(x:Double,y:Double)=wrap((atan2(y,x)+PI/2)/(2*PI))
    fun time(progress:Double):String {
        val minutes=floor(wrap(progress)*1440+.5).toInt()%1440
        val hour=minutes/60
        return String.format(Locale.US,"%d:%02d %s",if(hour%12==0)12 else hour%12,minutes%60,if(hour<12)"AM"else"PM")
    }
    fun sweep(range:SleepRange)=wrap(range.end-range.start)*360.0
}
