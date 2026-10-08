package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ReferralCardModelTest {
 @Test fun normalizationUsesSourceFiveCharacterRule() {assertEquals("AB234",ReferralCardModel.normalize("  ab-234x  "));assertEquals("É123",ReferralCardModel.normalize("e\u0301 12🔥3"));assertEquals("",ReferralCardModel.normalize("---"))}
 @Test fun thresholdBoundsAndDirection() {assertNull(ReferralCardModel.tilt(10f,10f,100f,210f,9f,0f));assertNull(ReferralCardModel.tilt(10f,10f,Float.NaN,210f,10f,0f));assertEquals(ReferralCardTilt(-8f,8f,6f,2.6999998f),ReferralCardModel.tilt(1000f,1000f,100f,210f,10f,0f));val center=ReferralCardModel.tilt(50f,105f,100f,210f,10f,0f)!!;assertEquals(0f,center.x,0.0001f);assertEquals(0f,center.y,0.0001f)}
}
