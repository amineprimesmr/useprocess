package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class SleepSliderModelTest {
    @Test fun midnightAndRoundedRollover() {
        assertEquals("12:00 AM",SleepSliderModel.time(0.0))
        assertEquals("12:00 PM",SleepSliderModel.time(.5))
        assertEquals("6:00 AM",SleepSliderModel.time(.25))
        assertEquals("12:00 AM",SleepSliderModel.time(1439.75/1440))
    }
    @Test fun approachingOtherKnobRotatesBothWithoutShrinkingRange() {
        val value=SleepSliderModel.move(SleepRange(.2,.5),true,.45)
        assertEquals(.45,value.start,.00001);assertEquals(.75,value.end,.00001)
        assertEquals(108.0,SleepSliderModel.sweep(value),.00001)
    }
    @Test fun minimumDistanceAlsoAppliesAcrossMidnight() {
        val value=SleepSliderModel.move(SleepRange(.7,.02),true,.98)
        assertEquals(.98,value.start,.00001);assertEquals(.3,value.end,.00001)
    }
    @Test fun ordinaryDragMovesOnlySelectedHandleAndAnglesBeginAtTop() {
        assertEquals(SleepRange(.25,.5),SleepSliderModel.move(SleepRange(0.0,.5),true,.25))
        assertEquals(0.0,SleepSliderModel.progressAt(0.0,-1.0),0.0)
        assertEquals(.25,SleepSliderModel.progressAt(1.0,0.0),0.0)
        assertEquals(.5,SleepSliderModel.progressAt(0.0,1.0),0.0)
    }
}
