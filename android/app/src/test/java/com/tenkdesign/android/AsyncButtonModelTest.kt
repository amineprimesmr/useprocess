package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class AsyncButtonModelTest {
    @Test fun originalDemoPhaseBoundaries() {
        assertEquals(AsyncButtonModel.DemoPhase.IDLE, AsyncButtonModel.demoPhase(-1))
        assertEquals(AsyncButtonModel.DemoPhase.ANALYZING, AsyncButtonModel.demoPhase(0))
        assertEquals(AsyncButtonModel.DemoPhase.ANALYZING, AsyncButtonModel.demoPhase(2999))
        assertEquals(AsyncButtonModel.DemoPhase.PROCESSING, AsyncButtonModel.demoPhase(3000))
        assertEquals(AsyncButtonModel.DemoPhase.FAILED, AsyncButtonModel.demoPhase(6000))
        assertEquals(AsyncButtonModel.DemoPhase.IDLE, AsyncButtonModel.demoPhase(7000))
    }
    @Test fun primarySpeedAndDelayedSecondaryRotation() {
        assertEquals(0f, AsyncButtonModel.spinnerDegrees(-1), .001f)
        assertEquals(216f, AsyncButtonModel.spinnerDegrees(350), .001f)
        assertEquals(257.14285f, AsyncButtonModel.spinnerDegrees(1000), .001f)
        assertEquals(61.714287f, AsyncButtonModel.spinnerDegrees(1500), .001f)
    }
}
