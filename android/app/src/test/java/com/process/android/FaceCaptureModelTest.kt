package com.process.android
import org.junit.Test
import org.junit.Assert.*
class FaceCaptureModelTest {
 private fun ready()=FaceCaptureObservation(1,.3f,.5f,.5f,0f,0f,.5f,1000)
 @Test fun captureRequiresRecentRealSingleFace(){assertTrue(ready().canCapture(1500));assertFalse(ready().canCapture(1751));assertFalse(ready().canCapture(999));assertEquals(FaceCaptureHint.MULTIPLE,ready().copy(faceCount=2).hint());assertEquals(FaceCaptureHint.SEARCHING,ready().copy(faceCount=0).hint())}
 @Test fun invalidGeometryLightAndPoseStayBlocked(){assertEquals(FaceCaptureHint.UNAVAILABLE,ready().copy(fill=Float.NaN).hint());assertEquals(FaceCaptureHint.LOW_LIGHT,ready().copy(luminance=.07f).hint());assertEquals(FaceCaptureHint.TOO_FAR,ready().copy(fill=.027f).hint());assertEquals(FaceCaptureHint.TOO_CLOSE,ready().copy(fill=.83f).hint());assertEquals(FaceCaptureHint.TURN_FORWARD,ready().copy(yaw=19f).hint());assertEquals(FaceCaptureHint.OFF_CENTER,ready().copy(centerX=.1f).hint())}
 @Test fun cropRotationsMatchUprightDetectorCoordinates(){val rect=FaceCaptureRect(20,30,500,400);assertEquals(FaceCaptureRect(80,20,450,500),rect.rotated(640,480,90));assertEquals(FaceCaptureRect(140,80,620,450),rect.rotated(640,480,180));assertEquals(FaceCaptureRect(30,140,400,620),rect.rotated(640,480,270))}
 @Test fun originalOvalHasNarrowerChinThanForehead(){val top=FaceCaptureGeometry.contour(-Math.PI/4);val bottom=FaceCaptureGeometry.contour(Math.PI/4);assertTrue(top.first>bottom.first);assertEquals(.5f,FaceCaptureGeometry.contour(Math.PI/2).first,.00001f)}
}
