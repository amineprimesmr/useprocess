package com.process.android

import org.junit.Assert.*
import org.junit.Test

class ProcessToastModelTest {
    @Test fun firstDayAndMilestoneProgress() {
        val first=ProcessToastMessage.scanCompleted(0,1,7)
        assertEquals("Premier jour de ta série !",first.text)
        assertEquals(1f/7,first.streakProgress!!,0f)
        assertEquals(1f,ProcessToastMessage.scanCompleted(7,8,7).streakProgress!!,0f)
        assertEquals(1f,ProcessToastMessage.scanCompleted(1,2,null).streakProgress!!,0f)
    }
    @Test fun exactCounterAndProgressDelayBoundaries() {
        val msg=ProcessToastMessage.scanCompleted(2,3,7)
        assertEquals(2,ProcessToastTimeline.displayedCounter(msg,319))
        assertEquals(3,ProcessToastTimeline.displayedCounter(msg,320))
        assertEquals(0f,ProcessToastTimeline.progress(msg,359),0f)
        assertEquals(3f/7,ProcessToastTimeline.progress(msg,360),0f)
    }
    @Test fun oldDismissCannotClearAReplacementToast() {
        assertFalse(ProcessToastTimeline.canDismiss("new","old"))
        assertFalse(ProcessToastTimeline.canDismiss(null,"old"))
        assertTrue(ProcessToastTimeline.canDismiss("new","new"))
    }
}
