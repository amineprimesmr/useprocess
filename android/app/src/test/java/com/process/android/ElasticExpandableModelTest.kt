package com.process.android
import com.tenkdesign.android.*
import org.junit.Test
import org.junit.Assert.*
class ElasticExpandableModelTest {
 @Test fun elasticPreservesStrictSourceEdgeGuardAndRounding() {
  assertEquals(40f,ElasticSegmentedModel.acceptedOffset(40f,300f,0f,400f,4),0f)
  assertEquals(299f,ElasticSegmentedModel.acceptedOffset(40f,299f,0f,400f,4),0f)
  assertEquals(2,ElasticSegmentedModel.dropIndex(150f,100f,4,true));assertEquals(1,ElasticSegmentedModel.dropIndex(150f,100f,4,false))
 }
 @Test fun relativeSliderUsesOriginalUpperBoundScaleAndClamps() {
  assertEquals(30f,ExpandableSliderModel.drag(10f,50f,100f,0f..40f),0f)
  assertEquals(.25f,ExpandableSliderModel.fraction(10f,10f..40f),0f)
  assertEquals(40f,ExpandableSliderModel.drag(10f,200f,100f,10f..40f),0f)
 }
 @Test fun sliderRejectsInvalidRangesAndSanitizesValues() {
  assertEquals(10f,ExpandableSliderModel.safe(Float.NaN,10f..40f),0f)
  try {ExpandableSliderModel.safe(0f,0f..0f);fail("Empty range accepted")}catch(_:IllegalArgumentException){}
 }
}
