package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ScrollNavigationModelTest {
 @Test fun downThresholdAndTenPointReverseHysteresisMatchSource() {
  var s=ScrollNavigationModel().update(10f,true).update(60f,true);assertFalse(s.hidden)
  s=s.update(61f,true);assertTrue(s.hidden)
  s=s.update(60f,true);assertTrue(s.hidden)
  s=s.update(50f,true);assertFalse(s.hidden)
 }
 @Test fun idleOffsetsNeverChangeVisibilityAndDuplicateOffsetsPreserveDirection() {
  val s=ScrollNavigationModel().update(10f,true).update(70f,true);assertTrue(s.hidden)
  assertEquals(s,s.update(70f,false));assertTrue(s.update(0f,false).hidden);assertEquals(s,s.update(Float.NaN,true))
 }
}
