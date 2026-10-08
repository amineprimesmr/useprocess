package com.process.android
import org.junit.Test
import org.junit.Assert.*
class GooeyRefreshGeometryTest {
 @Test fun thresholdAndFadeFollowSourceSixtyPointProgress() {
  assertEquals(0f,GooeyRefreshGeometry.progress(-1f),0f);assertEquals(.5f,GooeyRefreshGeometry.progress(30f),0f);assertEquals(1f,GooeyRefreshGeometry.progress(120f),0f)
  assertEquals(30f,GooeyRefreshGeometry.indicatorSize(.2f),0f);assertEquals(40f,GooeyRefreshGeometry.indicatorSize(1f),0f)
  assertEquals(0f,GooeyRefreshGeometry.spinnerOpacity(.8f),.0001f);assertEquals(.5f,GooeyRefreshGeometry.spinnerOpacity(.9f),.0001f)
  assertEquals(25f,GooeyRefreshGeometry.blur(0f),0f);assertEquals(0f,GooeyRefreshGeometry.blur(1f),0f)
 }
}
