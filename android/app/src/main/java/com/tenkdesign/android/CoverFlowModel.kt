package com.tenkdesign.android

import kotlin.math.*

/** CoverFlow.swift and CoverFlowReflection.metal, Balaji Venkatesh, 05/05/26. */
data class CoverFlowConfig(val cardWidth:Float=160f,val rotation:Float=58f,val offsetFactor:Float=1.4f,val activeElevation:Float=0f,val reflectionGap:Float=.5f,val reflectionFade:Float=4f,val reflectionDim:Float=.8f)
object CoverFlowModel {
    data class Transform(val rotation:Float,val anchorX:Float,val anchorZ:Float,val offset:Float)
    fun transform(progress:Float,config:CoverFlowConfig):Transform {
        val p=if(progress.isFinite())progress else 0f
        val capped=p.coerceIn(-1f,1f)
        return Transform(-capped*config.rotation,if(capped<0)0f else 1f,abs(capped)*config.activeElevation,
            -p*(config.cardWidth/config.offsetFactor.coerceAtLeast(.01f)))
    }
    fun reflectionAlpha(y:Float,height:Float,config:CoverFlowConfig):Float {
        if(height<=0 || y<height+config.reflectionGap)return 0f
        val progress=(y-height-config.reflectionGap)/height
        if(progress>1)return 0f
        return (1-progress.coerceIn(0f,1f)).pow(config.reflectionFade.coerceAtLeast(0f))*config.reflectionDim.coerceIn(0f,1f)
    }
    fun zIndex(index:Int,active:Int)=if(index==active)1000f else if(active>index)index.toFloat()else -index.toFloat()
}
