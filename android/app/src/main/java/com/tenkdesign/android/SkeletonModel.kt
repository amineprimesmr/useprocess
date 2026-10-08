package com.tenkdesign.android

import kotlin.math.max

/** Skeleton original source by Balaji Venkatesh, 12–13 April 2025. */
object SkeletonModel {
    data class Geometry(val bandWidth:Float,val blurRadius:Float,val startX:Float,val endX:Float)
    fun geometry(width:Float):Geometry {
        val w=if(width.isFinite())width.coerceAtLeast(0f)else 0f
        val band=w/2;val blur=max(band/2,30f)
        return Geometry(band,blur,-band-2*blur,w+band+2*blur)
    }
    fun fraction(elapsedMillis:Long):Float {
        val progress=(elapsedMillis.coerceAtLeast(0)%1500)/1500f
        // Invert the x of CSS/Swift easeInOut (0.42,0,0.58,1), then evaluate y.
        var low=0f;var high=1f
        repeat(20) {
            val t=(low+high)/2;val inv=1-t
            val x=3*inv*inv*t*.42f+3*inv*t*t*.58f+t*t*t
            if(x<progress)low=t else high=t
        }
        val t=(low+high)/2
        return 3*(1-t)*t*t+t*t*t
    }
}
