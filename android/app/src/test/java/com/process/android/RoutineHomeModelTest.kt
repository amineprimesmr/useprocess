package com.process.android
import org.junit.Test
import org.junit.Assert.*
class RoutineHomeModelTest {
 @Test fun fiveSecondHoldCompletesExactlyOnceAndNeverOpensDetails() {
  val model=RoutineHoldModel();model.begin(100)
  assertFalse(model.tick(5099));assertTrue(model.tick(5100));assertFalse(model.tick(5200));assertFalse(model.release(5300))
 }
 @Test fun shortTapIntermediateReleaseAndCancellationStayDistinct() {
  val model=RoutineHoldModel();model.begin(100);assertTrue(model.release(449))
  model.begin(100);assertFalse(model.release(450))
  model.begin(100);model.tick(2400);model.cancel();assertFalse(model.release(2500));assertFalse(model.tick(9000))
 }
 @Test fun stepTicksClampSafelyAndUnknownRemainsUnknown() {
  assertNull(RoutineStepProgress.percent(null));assertEquals(0,RoutineStepProgress.percent(-1));assertEquals(100,RoutineStepProgress.percent(Int.MAX_VALUE))
  assertEquals(1,RoutineStepProgress.filledTicks(1,40));assertEquals(20,RoutineStepProgress.filledTicks(50,40));assertEquals(0,RoutineStepProgress.filledTicks(null,40))
 }
}
