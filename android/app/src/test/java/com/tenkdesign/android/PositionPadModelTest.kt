package com.tenkdesign.android
import org.junit.Assert.*
import org.junit.Test
class PositionPadModelTest {
    private val c=PositionPadConfig()
    @Test fun endpointsAndRoundTripsRespectHalfCellMargins() {
        assertEquals(c.itemSize/2,PositionPadModel.location(PadPosition(0f,0f),c).x,.0001f)
        for(i in 0..100) {val p=PadPosition(i/100f,1-i/100f);val r=PositionPadModel.position(PositionPadModel.location(p,c),c);assertEquals(p.x,r.x,.00001f);assertEquals(p.y,r.y,.00001f)}
        assertEquals(PadPosition(0f,1f),PositionPadModel.position(PadPosition(-100f,500f),c))
    }
    @Test fun idleCrossAndZoomPreserveOriginalDotContract() {
        val location=PositionPadModel.location(PadPosition(.5f,.5f),c)
        assertEquals(PadDot(3f,1f),PositionPadModel.dot(5,5,location,false,c))
        assertEquals(PadDot(1f,1f),PositionPadModel.dot(5,0,location,false,c))
        assertEquals(PadDot(1f,.3f),PositionPadModel.dot(0,0,location,false,c))
        assertEquals(PadPosition(70f,70f),PositionPadModel.indicator(location,false,c))
    }
    @Test fun dragIndicatorTracksContinuousLocationWhileStoredCoordinatesDoNotSnap() {
        val position=PadPosition(.213f,.819f);val location=PositionPadModel.location(position,c)
        assertEquals(location,PositionPadModel.indicator(location,true,c));assertNotEquals(location,PositionPadModel.indicator(location,false,c))
        val far=PositionPadModel.dot(0,0,PadPosition(140f,140f),true,c);assertEquals(.7f,far.scale,0f);assertEquals(.1f,far.opacity,0f)
    }
    @Test fun invalidConfigAndNonFiniteCoordinatesCannotCauseNaNRendering() {
        assertThrows(IllegalArgumentException::class.java) {PositionPadConfig(count=1)}
        assertThrows(IllegalArgumentException::class.java) {PositionPadConfig(influenceRadius=0f)}
        assertEquals(PadPosition(.5f,.5f),PositionPadModel.clamp(PadPosition(Float.NaN,Float.POSITIVE_INFINITY)))
    }
}
