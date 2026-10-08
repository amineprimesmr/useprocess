package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ScrollIndicatorModelTest {
 @Test fun clampsOverscrollAndHandlesEmptyOrNonfiniteRange() {assertEquals(0f,scrollIndicatorProgress(-10f,100f));assertEquals(1f,scrollIndicatorProgress(110f,100f));assertEquals(0f,scrollIndicatorProgress(10f,0f));assertEquals(0f,scrollIndicatorProgress(Float.NaN,100f));assertEquals(.5f,scrollIndicatorProgress(50f,100f))}
 @Test fun dragUsesOriginalProgressAndClampsAtBothEnds() {assertEquals(.75f,scrollIndicatorDraggedProgress(.5f,90f,360f));assertEquals(0f,scrollIndicatorDraggedProgress(.1f,-90f,360f));assertEquals(1f,scrollIndicatorDraggedProgress(.9f,90f,360f));assertEquals(0f,scrollIndicatorDraggedProgress(.5f,1f,0f))}
}
