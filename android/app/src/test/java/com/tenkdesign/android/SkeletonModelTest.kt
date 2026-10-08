package com.tenkdesign.android

import org.junit.Assert.*
import org.junit.Test

class SkeletonModelTest {
    @Test fun blurAndTravelCoverSmallAndLargeViews() {
        assertEquals(SkeletonModel.Geometry(20f,30f,-80f,120f),SkeletonModel.geometry(40f))
        assertEquals(SkeletonModel.Geometry(200f,100f,-400f,800f),SkeletonModel.geometry(400f))
    }
    @Test fun animationHasOriginalDurationAndSymmetricEasing() {
        assertEquals(0f,SkeletonModel.fraction(0),.00001f)
        assertEquals(.5f,SkeletonModel.fraction(750),.00001f)
        assertEquals(SkeletonModel.fraction(375),1-SkeletonModel.fraction(1125),.00001f)
        assertEquals(SkeletonModel.fraction(0),SkeletonModel.fraction(1500),.00001f)
        assertTrue(SkeletonModel.fraction(1499)>.99f)
    }
}
