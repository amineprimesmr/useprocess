package com.process.android

import kotlin.math.abs

/** Geometry extracted from the three original Swift carousel implementations. */
object CarouselGeometry {
    fun progress(page:Int,offset:Float,count:Int):Float = if(count<=1)0f else
        (page+if(offset.isFinite())offset else 0f).coerceIn(0f,(count-1).toFloat())
    fun backdropOpacity(index:Int,progress:Float):Float=(index+1-progress).coerceIn(0f,1f)
    fun wallpaperHeight(available:Float):Float=if(available.isFinite())(available-180f).coerceIn(0f,700f)else 0f
    fun scrollTransform(minX:Float,phase:Float,reduceMotion:Boolean=false):ScrollCardTransform {
        if(reduceMotion)return ScrollCardTransform(1f,0f,0f,0f,0f)
        val t=if(phase.isFinite())phase.coerceIn(-1f,1f)else 0f;val amount=abs(t)
        return ScrollCardTransform(1f-.1f*amount,2f*amount,-10f*amount,5f*t,if(minX.isFinite())if(minX<0f)minX/2f else -minX else 0f)
    }
}
data class ScrollCardTransform(val scale:Float,val blur:Float,val translationY:Float,val rotation:Float,val translationX:Float)
