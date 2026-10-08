package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class FlipTransitionModelTest {
    @Test fun targetUsesSourceCapsAndCenters() {
        val small=FlipTransitionModel.target(200f,800f)
        assertEquals(12f,small.x,.0001f);assertEquals(200f,small.y,.0001f)
        assertEquals(176f,small.width,.0001f);assertEquals(400f,small.height,.0001f)
        assertEquals(FlipRect(250f,350f,500f,500f),FlipTransitionModel.target(1000f,1200f))
    }
    @Test fun halfwaySwitchMatchesOriginalAndFramesReturnToSource() {
        val source=FlipRect(10f,20f,100f,160f);val target=FlipRect(30f,200f,300f,400f)
        assertEquals(source,FlipTransitionModel.frame(source,target,0f))
        assertEquals(target,FlipTransitionModel.frame(source,target,1f))
        assertEquals(FlipRect(20f,110f,200f,280f),FlipTransitionModel.frame(source,target,.5f))
        assertFalse(FlipTransitionModel.destinationVisible(.5f));assertTrue(FlipTransitionModel.destinationVisible(.501f))
        assertEquals(.33333334f,FlipTransitionModel.destinationScale(source,target),.0001f)
    }
}
