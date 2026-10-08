package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class CoverFlowModelTest {
    @Test fun rotationsCapButOffsetsContinueForDistantCards() {
        val config=CoverFlowConfig(activeElevation=20f)
        val left=CoverFlowModel.transform(-2f,config)
        assertEquals(58f,left.rotation,0f);assertEquals(0f,left.anchorX,0f);assertEquals(20f,left.anchorZ,0f)
        assertEquals(2*160/1.4f,left.offset,.0001f)
        assertEquals(-29f,CoverFlowModel.transform(.5f,config).rotation,0f)
    }
    @Test fun metalReflectionGapAndFourthPowerFade() {
        val c=CoverFlowConfig()
        assertEquals(0f,CoverFlowModel.reflectionAlpha(220.25f,220f,c),0f)
        assertEquals(.8f,CoverFlowModel.reflectionAlpha(220.5f,220f,c),0f)
        assertEquals(.05f,CoverFlowModel.reflectionAlpha(330.5f,220f,c),.00001f)
        assertEquals(0f,CoverFlowModel.reflectionAlpha(441f,220f,c),0f)
    }
    @Test fun activeCardAlwaysDrawsAboveNeighbors() {
        assertEquals(1000f,CoverFlowModel.zIndex(3,3),0f)
        assertTrue(CoverFlowModel.zIndex(2,3)>CoverFlowModel.zIndex(1,3))
        assertTrue(CoverFlowModel.zIndex(4,3)>CoverFlowModel.zIndex(5,3))
    }
}
