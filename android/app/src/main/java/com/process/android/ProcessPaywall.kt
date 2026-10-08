package com.process.android

import android.os.SystemClock
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.sin

/** Current Process paywall. Prices and verified access are supplied by the host's Play/backend adapter. */
@Composable fun ProcessPaywall(
 accountKey:String?,offers:List<ProcessBillingOffer>,purchase:suspend (ProcessBillingOffer)->ProcessBillingResult,restore:suspend ()->ProcessBillingResult,
 onAccessVerified:()->Unit,onLeave:()->Unit,onLifetimeOffer:()->Unit,onReferral:()->Unit,onTerms:()->Unit,onPrivacy:()->Unit,
 modifier:Modifier=Modifier,loading:Boolean=false,allowsLeave:Boolean=true,english:Boolean=false,
 shortPlan:ProcessBillingPlan=ProcessBillingPlan.MONTHLY,annualComparePrice:String?=null,hasLifetimeOffer:Boolean=false,
 reduceMotion:Boolean=rememberProcessReducedMotion(),hero:(@Composable ()->Unit)?=null,
) {
 require(shortPlan==ProcessBillingPlan.MONTHLY||shortPlan==ProcessBillingPlan.WEEKLY)
 require(offers.map {it.plan}.distinct().size==offers.size)
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val dark=p.dark
 val actions=rememberProcessBillingActions(accountKey,onAccessVerified,english)
 val currentPurchase by rememberUpdatedState(purchase);val currentRestore by rememberUpdatedState(restore)
 var selected by rememberSaveable(accountKey) {mutableStateOf(ProcessBillingPlan.ANNUAL.name)}
 var initialSelected by remember(accountKey){mutableStateOf(false)}
 LaunchedEffect(accountKey,offers,loading) {if(!loading&&!initialSelected&&offers.isNotEmpty()){selected=(offers.firstOrNull {it.plan==ProcessBillingPlan.ANNUAL}?:offers.firstOrNull {it.plan==shortPlan})?.plan?.name?:ProcessBillingPlan.ANNUAL.name;initialSelected=true}}
 val offer=offers.firstOrNull {it.plan.name==selected};val currentOffer by rememberUpdatedState(offer)
 var menu by remember {mutableStateOf(false)};var retention by remember {mutableStateOf(false)}
 var closeVisible by remember(accountKey){mutableStateOf(false)}
 LaunchedEffect(accountKey,allowsLeave){closeVisible=false;if(allowsLeave){delay(5000);closeVisible=true}}
 val closePolicy=remember(accountKey){PaywallClosePolicy()};val shake=remember {Animatable(0f)};val scope=rememberCoroutineScope()
 fun close(){
  if(retention&&!actions.busy){retention=false;onLeave();return}
  when(closePolicy.attempt(SystemClock.elapsedRealtime(),closeVisible,allowsLeave,actions.busy)) {
   PaywallCloseAction.SHAKE->scope.launch {shake.snapTo(0f);shake.animateTo(1f,if(reduceMotion)snap()else tween(350));shake.snapTo(0f)}
   PaywallCloseAction.SHOW_OFFER->if(hasLifetimeOffer)retention=true else onLeave()
   PaywallCloseAction.LEAVE->onLeave()
   PaywallCloseAction.IGNORE->Unit
  }
 }
 BackHandler {close()}
 val background=if(dark)listOf(Color.Black,Color(.04f,.04f,.06f),Color(.07f,.09f,.14f),Color(.10f,.14f,.24f),Color(.12f,.17f,.30f))else listOf(Color.White,Color(.99f,.99f,1f),Color(.95f,.97f,1f),Color(.90f,.94f,.99f))
 BoxWithConstraints(modifier.fillMaxSize().background(Brush.verticalGradient(background))) {
  val minHeight=maxHeight
  Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min=minHeight).padding(top=4.dp,bottom=24.dp),horizontalAlignment=Alignment.CenterHorizontally) {
   Row(Modifier.fillMaxWidth().padding(horizontal=18.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.SpaceBetween) {
    Box {
     IconButton(onClick={menu=true},modifier=Modifier.size(32.dp)){Icon(Icons.Default.MoreVert,if(english)"Options and legal information"else"Options et informations légales",tint=p.primary.copy(alpha=.28f))}
     DropdownMenu(menu,{menu=false}) {
      DropdownMenuItem(text={Text(if(english)"Privacy Policy"else"Politique de confidentialité")},onClick={menu=false;onPrivacy()})
      DropdownMenuItem(text={Text(if(english)"Terms"else"Conditions")},onClick={menu=false;onTerms()})
      HorizontalDivider()
      DropdownMenuItem(text={Text(if(english)"Restore"else"Restaurer")},enabled=!actions.busy&&!accountKey.isNullOrBlank(),onClick={menu=false;actions.run {currentRestore()}})
      DropdownMenuItem(text={Text(if(english)"Referral code"else"Code de parrainage")},onClick={menu=false;onReferral()})
     }
    }
    if(allowsLeave)Box(Modifier.size(36.dp)) {if(closeVisible)IconButton(onClick=::close,enabled=!actions.busy,modifier=Modifier.size(36.dp).background(p.card,CircleShape)){Icon(Icons.Default.Close,if(english)"Close"else"Fermer",Modifier.size(14.dp),tint=p.primary)}}
   }
   Column(Modifier.padding(horizontal=24.dp).padding(bottom=14.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(12.dp)) {
    hero?.invoke()
    Text(buildAnnotatedString {
     append(if(english)"Unlock your personalized plan with "else"Débloque ton plan personnalisé avec ")
     withStyle(SpanStyle(brush=Brush.linearGradient(if(dark)listOf(Color(.52f,.88f,1f),Color(.34f,.72f,1f),Color(.20f,.56f,.98f))else listOf(Color(.28f,.66f,1f),Color(.14f,.50f,.96f),Color(.08f,.38f,.90f))))){append("Pro")}
    },color=p.primary,fontSize=31.sp,lineHeight=35.sp,letterSpacing=(-.45).sp,fontWeight=FontWeight.Bold,textAlign=TextAlign.Center)
    Text(if(english)"Keep your tracking, habits and AI coach in one place."else"Retrouve ton suivi, tes habitudes et ton coach IA dans un même espace.",color=p.secondary,fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,textAlign=TextAlign.Center)
   }
   Spacer(Modifier.height(8.dp).weight(1f))
   val labels=if(english)listOf("Personalized anti-bloat plan","Unlimited face scans","Daily guided hydration","AI coach for your face","Anti-bloat nutrition & meals")else listOf("Plan personnalisé anti-rétention","Scans visage illimités","Hydratation guidée au quotidien","Coach IA dédié à ton visage","Nutrition et repas anti-rétention")
   val symbols=listOf(Icons.Default.List,Icons.Default.Face,Icons.Default.Favorite,Icons.Default.Email,Icons.Default.Star)
   Column(Modifier.fillMaxWidth().padding(horizontal=26.dp)) {labels.forEachIndexed {i,title->Row(Modifier.fillMaxWidth().padding(vertical=6.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)){Icon(symbols[i],null,Modifier.size(30.dp).padding(4.dp),tint=p.primary.copy(alpha=if(dark).88f else .70f));Text(title,fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.Medium,color=p.primary.copy(alpha=.9f))}}}
   Spacer(Modifier.height(16.dp).weight(1f))
   Column(Modifier.padding(horizontal=20.dp),verticalArrangement=Arrangement.spacedBy(12.dp),horizontalAlignment=Alignment.CenterHorizontally) {
    BoxWithConstraints(Modifier.fillMaxWidth().border(1.dp,p.primary.copy(alpha=if(dark).26f else .14f),RoundedCornerShape(30.dp)).padding(5.dp)) {
     val cell=maxWidth/2;val offset by animateDpAsState(if(selected==ProcessBillingPlan.ANNUAL.name)0.dp else cell,if(reduceMotion)snap()else spring(.84f,224f),label="paywall.selection")
     Box(Modifier.offset {IntOffset(offset.roundToPx(),0)}.width(cell).height(88.dp).shadow(6.dp,RoundedCornerShape(24.dp)).background(if(dark)Color.White.copy(alpha=.12f)else Color.White.copy(alpha=.65f),RoundedCornerShape(24.dp)))
     Row(Modifier.selectableGroup()) {listOf(ProcessBillingPlan.ANNUAL,shortPlan).forEach {plan->
      val active=selected==plan.name;val item=offers.firstOrNull {it.plan==plan};val color=if(active)p.primary else p.primary.copy(alpha=if(dark).56f else .42f)
      Column(Modifier.weight(1f).height(88.dp).clip(RoundedCornerShape(24.dp)).selectable(selected=active,enabled=!actions.busy,role=Role.RadioButton){selected=plan.name}.padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(7.dp,Alignment.CenterVertically)) {
       Text(when(plan){ProcessBillingPlan.ANNUAL->if(english)"Annual"else"Annuel";ProcessBillingPlan.WEEKLY->if(english)"Weekly"else"Hebdo";else->if(english)"Monthly"else"Mensuel"},fontSize=(if(active)18 else 17).sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=if(active)FontWeight.Bold else FontWeight.SemiBold,color=color)
       Text(buildAnnotatedString {if(plan==ProcessBillingPlan.ANNUAL&&!annualComparePrice.isNullOrBlank()){withStyle(SpanStyle(textDecoration=TextDecoration.LineThrough,color=p.secondary)){append(annualComparePrice)};append(" ")};append(item?.formattedPrice?:"—")},fontSize=18.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=if(active)FontWeight.Bold else FontWeight.SemiBold,color=color,maxLines=1,overflow=TextOverflow.Ellipsis)
      }
     }}
    }
    val enabled=offer!=null&&!loading&&!actions.busy&&!actions.completed&&!accountKey.isNullOrBlank()
    val interaction=remember {MutableInteractionSource()};val pressed by interaction.collectIsPressedAsState();val scale by animateFloatAsState(if(pressed).985f else 1f,if(reduceMotion)snap()else spring(.82f,815f),label="paywall.press")
    Button(onClick={currentOffer?.let {chosen->actions.run {currentPurchase(chosen)}}},enabled=enabled,interactionSource=interaction,shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=p.primary,contentColor=p.background,disabledContainerColor=p.primary.copy(alpha=.55f),disabledContentColor=p.background),modifier=Modifier.fillMaxWidth().height(56.dp).graphicsLayer {scaleX=scale;scaleY=scale;translationX=10.dp.toPx()*sin(shake.value*Math.PI*3).toFloat();alpha=if(pressed).94f else 1f}) {
     if(actions.busy||loading)CircularProgressIndicator(Modifier.size(20.dp),color=p.background,strokeWidth=2.dp)
     else Text(if(english)"Continue — no commitment."else"Continuer, aucun engagement.",fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,textAlign=TextAlign.Center)
    }
    Text(offer?.billingDescription?:if(english)"Prices and billing terms unavailable."else"Prix et conditions de facturation indisponibles.",fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=p.secondary,textAlign=TextAlign.Center)
    if(!loading&&offer==null)Text(if(english)"This product is currently unavailable."else"Ce produit est actuellement indisponible.",fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=Color.Red.copy(alpha=.85f),textAlign=TextAlign.Center)
    actions.error?.let {Text(it,color=Color.Red,fontSize=13.sp,lineHeight=17.sp,letterSpacing=0.sp,modifier=Modifier.semantics {liveRegion=LiveRegionMode.Polite})}
   }
  }
  if(retention)AlertDialog(onDismissRequest={retention=false},title={Text(if(english)"Lifetime access"else"Accès à vie")},text={Text(if(english)"A one-time purchase is also available."else"Une formule avec achat unique est également disponible.")},confirmButton={TextButton(onClick={retention=false;onLifetimeOffer()}){Text(if(english)"View offer"else"Voir l’offre")}},dismissButton={TextButton(onClick={retention=false}){Text(if(english)"Stay on this offer"else"Rester sur l’offre")}})
 }
}
