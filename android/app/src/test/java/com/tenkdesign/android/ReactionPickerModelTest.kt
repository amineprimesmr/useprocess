package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class ReactionPickerModelTest {
    @Test fun insertReservesOneOfSixSlots() {
        val reactions=listOf("👍","👌","🎉","❤️","🔥","🥳","😃")
        assertEquals(reactions.take(5),ReactionPickerModel.limited(reactions,true))
        assertEquals(reactions.take(6),ReactionPickerModel.limited(reactions,false))
    }
    @Test fun delaysAreCumulativeAsInOriginalLoop() {
        assertEquals(listOf(150L,180L,240L,330L,450L,600L),(0..5).map {ReactionPickerModel.revealMillis(it,false)})
        assertEquals(listOf(80L,100L,140L,200L,280L),(0..4).map {ReactionPickerModel.revealMillis(it,true)})
    }
    @Test fun fiveParticlesStaggerGrowAndFade() {
        assertEquals(0f,ReactionPickerModel.particle(0,0,20f).scale,0f)
        assertEquals(0f,ReactionPickerModel.particle(4,1000,20f).scale,0f)
        assertEquals(-10f,ReactionPickerModel.particle(0,500,20f).x,0f)
        assertEquals(10f,ReactionPickerModel.particle(1,500,20f).x,0f)
        (0..4).forEach { assertEquals(0f,ReactionPickerModel.particle(it,2300,20f).opacity,0f) }
    }
}
