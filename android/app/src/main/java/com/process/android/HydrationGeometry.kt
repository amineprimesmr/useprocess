package com.process.android

import kotlin.math.*

data class WaterPoint(val x: Float, val y: Float)
object HydrationGeometry {
    const val SIDE = 248f
    const val CONTENT_WIDTH = .315f
    const val MIN_X = .348f
    const val MAX_X = .652f
    const val MIN_Y = .238f
    const val MAX_Y = .978f
    const val BOOST = .148f
    const val CORNER = .24f
    fun fill(milliliters: Int, target: Int): Float = (milliliters.coerceAtLeast(0).toFloat() / target.coerceAtLeast(1)).coerceIn(.08f,1f)
    // Coordinates stay in SwiftUI points; density is applied once when drawing.
    fun surface(fill: Float, roll: Float, pitch: Float, phase: Float, side: Float = SIDE): List<WaterPoint> {
        val left=side*MIN_X; val width=side*(MAX_X-MIN_X)
        val top=side*MIN_Y; val bottom=side*MAX_Y
        val depth=fill.coerceIn(.05f,1f)*(bottom-top)*(1+BOOST)
        val rest=max(top,bottom-depth); val radius=width*CORNER
        return (0..24).map { index ->
            val t=index/24f; val x=left+t*width
            val y=rest-pitch.coerceIn(-1f,1f)*depth*.08f-roll.coerceIn(-1f,1f)*(t-.5f)*2*depth*.30f+sin(phase+x*.035f)*1.4f
            WaterPoint(x,y.coerceIn(top+1,bottom-radius*.12f))
        }
    }
    fun stiffness(response: Float): Float = (2*Math.PI/response).pow(2).toFloat()
}

class WaterMotion {
    var roll = 0f; private set
    var pitch = 0f; private set
    var phase = 0f; private set
    fun gravity(x: Float,y: Float,z: Float) {
        var nextRoll=(x/max(.35f,abs(y))).coerceIn(-1f,1f)
        var nextPitch=(z/.85f).coerceIn(-1f,1f)
        if(abs(nextRoll)<.025f) nextRoll=0f
        if(abs(nextPitch)<.025f) nextPitch=0f
        roll+=(nextRoll-roll)*.22f
        pitch+=(nextPitch-pitch)*.22f
        phase+=.06f
    }
    fun pour() { phase+=1.35f }
    fun reset() { roll=0f; pitch=0f; phase=0f }
}
