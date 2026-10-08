package com.process.android

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlin.math.*

/** Live Process post-payment screen. This component never grants or infers Pro access. */
@Composable fun ProcessPostPaymentThankYou(
    accessVerified: Boolean,
    needsAppleSignIn: Boolean,
    authenticateAndMigrate: suspend () -> ProcessAccountCompletion,
    onComplete: () -> Unit,
    modifier: Modifier = Modifier,
    english: Boolean = false,
    reduceMotion: Boolean = rememberProcessReducedMotion(),
    appleMark: (@Composable () -> Unit)? = null,
) {
    val palette=InputPalette(isSystemInDarkTheme())
    val scope=rememberCoroutineScope()
    val gate=remember { PostPaymentGate() }
    var busy by remember { mutableStateOf(false) }
    var completed by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val currentAccess by rememberUpdatedState(accessVerified)
    val currentComplete by rememberUpdatedState(onComplete)
    val currentAuthenticate by rememberUpdatedState(authenticateAndMigrate)
    val haptics=LocalHapticFeedback.current
    val accent=Color(.655f,.769f,.949f)
    val badgeScale by animateFloatAsState(if(busy && !reduceMotion)1.10f else 1f,spring(.52f,420f),label="thank-you.seal")
    fun continueFlow() {
        if(!gate.begin(currentAccess))return
        busy=true;error=null
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        scope.launch {
            try {
                val result=if(needsAppleSignIn)currentAuthenticate() else ProcessAccountCompletion.Completed
                if(gate.finish(result,currentAccess)) {completed=true;currentComplete()}
                else if(result is ProcessAccountCompletion.Failed)error=result.message
            } catch(cancel:CancellationException) {throw cancel}
            catch(_:Exception) {error=if(english)"Sign-in couldn't be completed. Please try again." else "La connexion n’a pas pu aboutir. Réessaie."}
            finally {gate.cancel();busy=false}
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background),contentAlignment=Alignment.TopCenter) {
        val screenHeight=maxHeight
        Column(Modifier.widthIn(max=540.dp).fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min=screenHeight),horizontalAlignment=Alignment.CenterHorizontally) {
            Spacer(Modifier.height(24.dp).weight(1f))
            Column(Modifier.fillMaxWidth().padding(horizontal=32.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(22.dp)) {
                Box(Modifier.size(96.dp).background(Brush.linearGradient(listOf(accent.copy(alpha=.22f),accent.copy(alpha=.06f))),CircleShape),contentAlignment=Alignment.Center) {
                    Canvas(Modifier.size(44.dp).graphicsLayer {scaleX=badgeScale;scaleY=badgeScale}) {
                        val seal=Path();val center=size/2f
                        repeat(48) {i -> val a=i*PI/24-PI/2;val r=size.minDimension/2*(if(i%4 in 1..2).92f else 1f);val x=center.width+cos(a).toFloat()*r;val y=center.height+sin(a).toFloat()*r;if(i==0)seal.moveTo(x,y)else seal.lineTo(x,y)}
                        seal.close();drawPath(seal,accent)
                        val check=Path().apply {moveTo(size.width*.28f,size.height*.51f);lineTo(size.width*.43f,size.height*.65f);lineTo(size.width*.73f,size.height*.34f)}
                        drawPath(check,palette.background,style=Stroke(3.dp.toPx(),cap=StrokeCap.Round))
                    }
                }
                Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(12.dp)) {
                    Text(if(accessVerified) {if(english)"Thank you!"else"Merci !"} else {if(english)"Your access"else"Ton accès"},fontSize=36.sp,fontWeight=FontWeight.Bold,color=palette.primary)
                    Text(if(accessVerified) {if(english)"Your Pro access is on. Sign in to save your profile, scan, and plan."else"Ton accès Pro est activé. Connecte-toi pour sauvegarder ton profil, ton scan et ton plan."} else {if(english)"Your Pro access must be verified before you can continue."else"Ton accès Pro doit être vérifié avant de continuer."},fontSize=16.sp,fontWeight=FontWeight.Medium,lineHeight=23.sp,color=palette.body,textAlign=TextAlign.Center,modifier=Modifier.semantics {liveRegion=LiveRegionMode.Polite})
                }
            }
            Spacer(Modifier.height(32.dp).weight(1f))
            Column(Modifier.fillMaxWidth().padding(horizontal=28.dp).padding(bottom=44.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(14.dp)) {
                val fill=if(needsAppleSignIn)palette.primary else Color.White
                val ink=if(needsAppleSignIn)palette.background else Color.Black
                Button(::continueFlow,enabled=accessVerified&&!busy&&!completed,modifier=Modifier.fillMaxWidth().height(58.dp).graphicsLayer {alpha=if(busy).72f else 1f},shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=fill,contentColor=ink,disabledContainerColor=fill.copy(alpha=.72f),disabledContentColor=ink.copy(alpha=.6f))) {
                    if(busy)CircularProgressIndicator(Modifier.size(24.dp),color=ink,strokeWidth=2.dp)
                    else Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                        if(needsAppleSignIn)appleMark?.invoke()
                        Text(if(needsAppleSignIn) {if(english)"Continue with Apple"else"Continuer avec Apple"}else {if(english)"Continue"else"Continuer"},fontSize=17.sp,fontWeight=FontWeight.Bold)
                    }
                }
                if(needsAppleSignIn)Text(if(english)"Your data stays private and synced across your devices."else"Tes données restent privées et synchronisées sur tous tes appareils.",fontSize=12.sp,color=palette.muted,textAlign=TextAlign.Center,modifier=Modifier.padding(horizontal=8.dp))
            }
        }
    }
    error?.let {message -> AlertDialog(onDismissRequest={error=null},title={Text(if(english)"Sign-in failed"else"Connexion impossible")},text={Text(message)},confirmButton={TextButton(onClick={error=null}){Text("OK")}})}
}
