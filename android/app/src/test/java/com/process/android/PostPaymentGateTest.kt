package com.process.android
import org.junit.Test
import org.junit.Assert.*
class PostPaymentGateTest {
 @Test fun entitlementMustBeVerifiedAndRemainValid() {val g=PostPaymentGate();assertFalse(g.begin(false));assertTrue(g.begin(true));assertFalse(g.finish(ProcessAccountCompletion.Completed,false));assertFalse(g.completed);assertTrue(g.begin(true));assertTrue(g.finish(ProcessAccountCompletion.Completed,true));assertFalse(g.begin(true))}
 @Test fun cancellationFailureAndDoubleTapCannotNavigate() {val g=PostPaymentGate();assertTrue(g.begin(true));assertFalse(g.begin(true));assertFalse(g.finish(ProcessAccountCompletion.Cancelled,true));assertTrue(g.begin(true));assertFalse(g.finish(ProcessAccountCompletion.Failed("offline"),true));assertTrue(g.begin(true));g.cancel();assertFalse(g.finish(ProcessAccountCompletion.Completed,true));assertTrue(g.begin(true))}
}
