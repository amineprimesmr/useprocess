package com.process.android

/** Host must populate these values from live Play ProductDetails. No price, discount or entitlement is inferred. */
enum class ProcessBillingPlan { ANNUAL,MONTHLY,WEEKLY,LIFETIME }
data class ProcessBillingOffer(val productId:String,val plan:ProcessBillingPlan,val formattedPrice:String,val billingDescription:String) {
 init {require(productId.isNotBlank()&&formattedPrice.isNotBlank()&&billingDescription.isNotBlank())}
}
sealed interface ProcessBillingResult {
 data class VerifiedAccess(val accountKey:String):ProcessBillingResult
 data object Pending:ProcessBillingResult
 data object Cancelled:ProcessBillingResult
 data object NoPurchases:ProcessBillingResult
 data class Failed(val message:String):ProcessBillingResult
}
/** Single-operation gate. An obsolete account result cannot complete another account's flow. */
class ProcessBillingGate(val accountKey:String?) {
 var busy=false;private set
 var completed=false;private set
 fun begin():Boolean {if(accountKey.isNullOrBlank()||busy||completed)return false;busy=true;return true}
 fun finish(result:ProcessBillingResult,currentAccountKey:String?):Boolean {
  if(!busy)return false
  busy=false
  if(result is ProcessBillingResult.VerifiedAccess&&result.accountKey==accountKey&&currentAccountKey==accountKey&&!completed){completed=true;return true}
  return false
 }
 fun cancel(){busy=false}
}

enum class PaywallCloseAction { IGNORE,SHAKE,SHOW_OFFER,LEAVE }
class PaywallClosePolicy {
 private var lastTap:Long?=null
 private var attempts=0
 fun attempt(nowMillis:Long,visible:Boolean,allowsLeave:Boolean,busy:Boolean):PaywallCloseAction {
  if(!visible||!allowsLeave||busy)return PaywallCloseAction.IGNORE
  if(lastTap?.let {nowMillis-it<400}==true)return PaywallCloseAction.IGNORE
  lastTap=nowMillis;attempts++
  return when(attempts){1->PaywallCloseAction.SHAKE;2->PaywallCloseAction.SHOW_OFFER;else->PaywallCloseAction.LEAVE}
 }
}
