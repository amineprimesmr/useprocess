package com.process.android
import org.junit.Test
import org.junit.Assert.*
class CarouselGeometryTest {
 @Test fun crossfadeClampsEdgesAndInvalidProgress() {
  assertEquals(0f,CarouselGeometry.progress(0,-.8f,4),0f)
  assertEquals(3f,CarouselGeometry.progress(3,.6f,4),0f)
  assertEquals(1f,CarouselGeometry.progress(1,Float.NaN,4),0f)
  assertEquals(.5f,CarouselGeometry.backdropOpacity(0,.5f),0f)
  assertEquals(1f,CarouselGeometry.backdropOpacity(1,.5f),0f)
  assertEquals(0f,CarouselGeometry.progress(9,0f,0),0f)
 }
 @Test fun wallpaperHeightSupportsSmallAndLargeHosts() {
  assertEquals(0f,CarouselGeometry.wallpaperHeight(100f),0f)
  assertEquals(672f,CarouselGeometry.wallpaperHeight(852f),0f)
  assertEquals(700f,CarouselGeometry.wallpaperHeight(2000f),0f)
 }
 @Test fun scrollActiveTypeThreeRetainsDirectionAndReduceMotion() {
  assertEquals(ScrollCardTransform(.9f,2f,-10f,-5f,-116f),CarouselGeometry.scrollTransform(-232f,-1f))
  assertEquals(ScrollCardTransform(.9f,2f,-10f,5f,-232f),CarouselGeometry.scrollTransform(232f,1f))
  assertEquals(ScrollCardTransform(1f,0f,0f,0f,0f),CarouselGeometry.scrollTransform(232f,1f,true))
 }
}
