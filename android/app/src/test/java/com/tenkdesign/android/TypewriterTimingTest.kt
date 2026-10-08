package com.tenkdesign.android
import org.junit.Assert.*
import org.junit.Test

class TypewriterTimingTest {
    @Test fun fullPauseNeverDividesByZeroAndStepsAtCharacterBoundaries() {
        assertEquals(0f,TypewriterTiming.progress(.09,1.0,10,1.0),0f)
        assertEquals(.1f,TypewriterTiming.progress(.1,1.0,10,1.0),.0001f)
        assertEquals(1f,TypewriterTiming.progress(1.0,1.0,10,1.0),0f)
    }
    @Test fun noPauseInterpolatesContinuouslyAndHalfPauseHolds() {
        assertEquals(.15f,TypewriterTiming.progress(.15,1.0,10,0.0),.0001f)
        assertEquals(.1f,TypewriterTiming.progress(.125,1.0,10,.5),.0001f)
        assertEquals(.15f,TypewriterTiming.progress(.175,1.0,10,.5),.0001f)
    }
    @Test fun emptyContentAndTimesAtBoundaryRemainFinite() {
        assertEquals(1f,TypewriterTiming.progress(0.0,0.0,0,1.0),0f)
        assertEquals(0f,TypewriterTiming.progress(-1.0,1.0,10,1.0),0f)
        assertEquals(1f,TypewriterTiming.progress(2.0,1.0,10,1.0),0f)
    }
    @Test fun blinkingIndicatorMatchesQuarterSecondRampsAndHold() {
        assertEquals(0f,TypewriterTiming.indicator(0.0),.0001f)
        assertEquals(1f,TypewriterTiming.indicator(.25),.0001f)
        assertEquals(1f,TypewriterTiming.indicator(.30),.0001f)
        assertEquals(0f,TypewriterTiming.indicator(.6),.0001f)
    }
}
