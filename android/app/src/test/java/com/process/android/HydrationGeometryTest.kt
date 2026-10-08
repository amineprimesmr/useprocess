package com.process.android
import org.junit.Assert.*
import org.junit.Test

class HydrationGeometryTest {
    @Test fun fillHandlesEmptyNegativeAndInvalidTargets() {
        assertEquals(.08f,HydrationGeometry.fill(-500,2000),0f)
        assertEquals(.25f,HydrationGeometry.fill(500,2000),0f)
        assertEquals(1f,HydrationGeometry.fill(2500,2000),0f)
        assertEquals(1f,HydrationGeometry.fill(500,0),0f)
    }
    @Test fun surfaceStaysInsideBottleAtAllLevelsAndTilts() {
        for(fill in listOf(-1f,0f,.25f,1f,2f)) for(roll in listOf(-2f,0f,2f)) for(pitch in listOf(-2f,0f,2f)) {
            val points=HydrationGeometry.surface(fill,roll,pitch,1.35f)
            assertEquals(25,points.size)
            points.forEach { assertTrue(it.y>=248f*.238f+1); assertTrue(it.y<=248f*.978f) }
            assertEquals(248f*.348f,points.first().x,.0001f)
            assertEquals(248f*.652f,points.last().x,.0001f)
        }
    }
    @Test fun motionUsesOriginalSmoothingAndDeadZone() {
        val m=WaterMotion(); m.gravity(.01f,-1f,.01f)
        assertEquals(0f,m.roll,0f); assertEquals(0f,m.pitch,0f)
        m.gravity(.5f,-1f,0f); assertEquals(.11f,m.roll,.0001f)
        m.reset(); assertEquals(0f,m.phase,0f)
    }
    @Test fun springMappingPreservesNaturalPeriod() {
        assertEquals(46.64f,HydrationGeometry.stiffness(.92f),.1f)
    }
}
