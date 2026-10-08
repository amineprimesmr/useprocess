package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ProcessBillingGateTest {
 @Test fun signedOutAndConcurrentOperationsCannotStart(){assertFalse(ProcessBillingGate(null).begin());assertFalse(ProcessBillingGate(" ").begin());val gate=ProcessBillingGate("a");assertTrue(gate.begin());assertFalse(gate.begin());gate.cancel();assertTrue(gate.begin())}
 @Test fun accountChangesCannotUnlockAccess(){val gate=ProcessBillingGate("a");assertTrue(gate.begin());assertFalse(gate.finish(ProcessBillingResult.VerifiedAccess("a"),"b"));assertTrue(gate.begin());assertFalse(gate.finish(ProcessBillingResult.VerifiedAccess("b"),"a"))}
 @Test fun pendingAndCancelCanRetryButCompletionIsOneShot(){val gate=ProcessBillingGate("a");assertTrue(gate.begin());assertFalse(gate.finish(ProcessBillingResult.Pending,"a"));assertTrue(gate.begin());assertFalse(gate.finish(ProcessBillingResult.Cancelled,"a"));assertTrue(gate.begin());assertTrue(gate.finish(ProcessBillingResult.VerifiedAccess("a"),"a"));assertFalse(gate.begin());assertFalse(gate.finish(ProcessBillingResult.VerifiedAccess("a"),"a"))}
 @Test(expected=IllegalArgumentException::class) fun incompleteLiveProductCannotBeShownAsPurchasable(){ProcessBillingOffer("",ProcessBillingPlan.LIFETIME,"—","")}
 @Test fun closePolicyHonorsVisibilityBusyAndDuplicateTapGuard(){
  val p=PaywallClosePolicy()
  assertEquals(PaywallCloseAction.IGNORE,p.attempt(0,false,true,false))
  assertEquals(PaywallCloseAction.IGNORE,p.attempt(0,true,true,true))
  assertEquals(PaywallCloseAction.SHAKE,p.attempt(1000,true,true,false))
  assertEquals(PaywallCloseAction.IGNORE,p.attempt(1200,true,true,false))
  assertEquals(PaywallCloseAction.SHOW_OFFER,p.attempt(1400,true,true,false))
  assertEquals(PaywallCloseAction.LEAVE,p.attempt(1800,true,true,false))
 }

}
