package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*

/** Current live source replaced the wheel with a plain lifetime offer; no simulated draw/discount/countdown. */
@Composable fun ProcessLifetimeOffer(
 accountKey:String?,offer:ProcessBillingOffer?,purchase:suspend (ProcessBillingOffer)->ProcessBillingResult,restore:suspend ()->ProcessBillingResult,
 onAccessVerified:()->Unit,onClose:()->Unit,onTerms:()->Unit,onPrivacy:()->Unit,
 modifier:Modifier=Modifier,english:Boolean=false,
) {
 require(offer==null||offer.plan==ProcessBillingPlan.LIFETIME)
 val actions=rememberProcessBillingActions(accountKey,onAccessVerified,english)
 val currentPurchase by rememberUpdatedState(purchase);val currentRestore by rememberUpdatedState(restore)
 val currentOffer by rememberUpdatedState(offer)
 val p=ProcessSurfacePalette(isSystemInDarkTheme())
 Column(modifier.fillMaxSize().background(p.background).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
  Text(if(english)"Lifetime access"else"Accès à vie",fontSize=34.sp,lineHeight=41.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=p.primary)
  Text(if(english)"A one-time purchase with no automatic renewal. This plan unlocks Process premium features."else"Achat unique, sans renouvellement automatique. Cette formule débloque les fonctionnalités premium de Process.",fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,color=p.primary)
  Text(offer?.formattedPrice?:"—",fontSize=28.sp,lineHeight=34.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=p.primary)
  Button(onClick={currentOffer?.let {selected->actions.run {currentPurchase(selected)}}},enabled=offer!=null&&!accountKey.isNullOrBlank()&&!actions.busy&&!actions.completed,modifier=Modifier.fillMaxWidth()) {
   if(actions.busy){CircularProgressIndicator(Modifier.size(18.dp),strokeWidth=2.dp);Spacer(Modifier.width(8.dp))}
   Text(if(english)"Buy lifetime access"else"Acheter l’accès à vie",letterSpacing=0.sp)
  }
  TextButton(onClick={actions.run {currentRestore()}},enabled=!accountKey.isNullOrBlank()&&!actions.busy&&!actions.completed){Text(if(english)"Restore purchases"else"Restaurer mes achats",letterSpacing=0.sp)}
  actions.error?.let {Text(it,color=Color.Red,fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,modifier=Modifier.semantics {liveRegion=LiveRegionMode.Polite})}
  TextButton(onClick=onTerms){Text(if(english)"Terms of Use"else"Conditions d’utilisation",letterSpacing=0.sp)}
  TextButton(onClick=onPrivacy){Text(if(english)"Privacy"else"Confidentialité",letterSpacing=0.sp)}
  TextButton(onClick=onClose,enabled=!actions.busy){Text(if(english)"Close"else"Fermer",letterSpacing=0.sp)}
 }
}

