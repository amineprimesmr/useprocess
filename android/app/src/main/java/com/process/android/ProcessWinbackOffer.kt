package com.process.android
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** Kept as a distinct catalog entry for the former winback wheel; current live source is offer-only. */
@Composable fun ProcessWinbackOffer(
 accountKey:String?,offer:ProcessBillingOffer?,purchase:suspend (ProcessBillingOffer)->ProcessBillingResult,restore:suspend ()->ProcessBillingResult,
 onAccessVerified:()->Unit,onClose:()->Unit,onTerms:()->Unit,onPrivacy:()->Unit,modifier:Modifier=Modifier,english:Boolean=false,
)=ProcessLifetimeOffer(accountKey,offer,purchase,restore,onAccessVerified,onClose,onTerms,onPrivacy,modifier,english)
