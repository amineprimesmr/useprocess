package com.tenkdesign.android

// Android adaptation of TenKPositionalPadSliderPhotosStylePositionPad.
// Original source: Balaji Venkatesh, 27/03/26. Original notices preserved in SOURCE-NOTICES.md.
import kotlin.math.hypot

data class PadPosition(val x:Float,val y:Float)
data class PadDot(val scale:Float,val opacity:Float)
data class PositionPadConfig(val count:Int=11,val size:Float=140f,val circleSize:Float=4f,val touchPointSize:Float=35f,val influenceRadius:Float=60f) {
    init {require(count in 2..15);require(size.isFinite()&&size>0);require(circleSize.isFinite()&&circleSize>0);require(touchPointSize.isFinite()&&touchPointSize>0);require(influenceRadius.isFinite()&&influenceRadius>0)}
    val itemSize:Float get()=size/count
}
object PositionPadModel {
    fun clamp(position:PadPosition)=PadPosition(position.x.takeIf {it.isFinite()}?.coerceIn(0f,1f)?:.5f,position.y.takeIf {it.isFinite()}?.coerceIn(0f,1f)?:.5f)
    fun location(position:PadPosition,config:PositionPadConfig):PadPosition {
        val value=clamp(position);val margin=config.itemSize/2;val travel=config.size-config.itemSize
        return PadPosition(margin+value.x*travel,margin+value.y*travel)
    }
    fun position(location:PadPosition,config:PositionPadConfig):PadPosition {
        val margin=config.itemSize/2;val travel=config.size-config.itemSize
        return clamp(PadPosition((location.x-margin)/travel,(location.y-margin)/travel))
    }
    fun active(location:PadPosition,config:PositionPadConfig)=((location.y/config.itemSize).toInt().coerceIn(0,config.count-1)) to ((location.x/config.itemSize).toInt().coerceIn(0,config.count-1))
    fun indicator(location:PadPosition,dragging:Boolean,config:PositionPadConfig):PadPosition {
        if(dragging)return PositionPadModel.location(position(location,config),config)
        val (row,column)=active(location,config)
        return PadPosition((column+.5f)*config.itemSize,(row+.5f)*config.itemSize)
    }
    fun dot(row:Int,column:Int,location:PadPosition,dragging:Boolean,config:PositionPadConfig):PadDot {
        require(row in 0 until config.count&&column in 0 until config.count)
        val (activeRow,activeColumn)=active(location,config)
        if(!dragging)return PadDot(if(row==activeRow&&column==activeColumn)3f else 1f,if(row==activeRow||column==activeColumn)1f else .3f)
        // Original proximity uses cell origins, while dots are drawn at cell centres. Preserve that offset.
        val distance=hypot(location.x-column*config.itemSize,row*config.itemSize-location.y)
        val proximity=1-(distance/config.influenceRadius).coerceIn(0f,1f)
        return PadDot(.7f+proximity,(.1f+proximity).coerceIn(0f,1f))
    }
}
