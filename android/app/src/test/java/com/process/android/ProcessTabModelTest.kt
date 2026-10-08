package com.process.android

import org.junit.Assert.*
import org.junit.Test

class ProcessTabModelTest {
    @Test fun tabOrderExcludesDisabledCoachAndNonTabRoutes() {
        assertEquals(listOf("plan","food","routine","profile"),ProcessMainSection.tabOrder.map{it.id})
    }
    @Test fun directionChangeDoesNotJumpAndReverseDragExpands() {
        val m=ProcessTabCollapseModel();m.update(0f,10f,true,true);m.update(10f,60f,true,true)
        assertEquals(.5f,m.progress,.0001f)
        m.update(60f,55f,true,true);assertEquals(.5f,m.progress,.0001f)
        m.update(55f,5f,true,true);assertEquals(0f,m.progress,.0001f)
    }
    @Test fun velocityProjectsThenSnapsWithoutConsumingContentScroll() {
        val m=ProcessTabCollapseModel();m.update(0f,10f,true,true);m.update(10f,40f,true,true)
        assertEquals(1f,m.endDrag(-200f,true),0f);m.expand();assertEquals(0f,m.progress,0f)
    }
    @Test fun shortContentNonDragAndNonfiniteInputsCannotCollapse() {
        val m=ProcessTabCollapseModel();m.update(0f,100f,false,true);assertEquals(0f,m.progress,0f)
        m.update(0f,10f,true,true);m.update(10f,110f,true,true);assertEquals(1f,m.progress,0f)
        m.update(110f,Float.NaN,true,true);assertEquals(1f,m.progress,0f)
        m.update(110f,120f,true,false);assertEquals(0f,m.progress,0f);assertEquals(0f,m.endDrag(-1000f,false),0f)
    }
}
