package com.process.android

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Original Process engraved metal card. Code/link ownership and rewards remain host services. */
@Composable fun ProcessReferralMetalCard(
    code:String,copyText:String,modifier:Modifier=Modifier,english:Boolean=false,
    reduceMotion:Boolean=rememberProcessReducedMotion(),onCopied:()->Unit={},
) {
    val normalized=remember(code) {ReferralCardModel.normalize(code)}
    val clipboard=LocalClipboardManager.current
    val haptics=LocalHapticFeedback.current
    val density=LocalDensity.current.density
    val context=LocalContext.current
    val owner=LocalLifecycleOwner.current
    val scope=rememberCoroutineScope()
    var target by remember {mutableStateOf(ReferralCardTilt())}
    var interacting by remember {mutableStateOf(false)}
    var copied by remember {mutableStateOf(false)}
    var copyJob by remember {mutableStateOf<Job?>(null)}
    var sound by remember {mutableStateOf<MediaPlayer?>(null)}
    val stiffness=if(interacting)815.67f else 146f
    val damping=if(interacting).86f else .76f
    val tx by animateFloatAsState(if(reduceMotion)0f else target.x,spring(damping,stiffness),label="referral.tilt.x")
    val ty by animateFloatAsState(if(reduceMotion)0f else target.y,spring(damping,stiffness),label="referral.tilt.y")
    val px by animateFloatAsState(if(reduceMotion)0f else target.parallaxX,spring(damping,stiffness),label="referral.parallax.x")
    val py by animateFloatAsState(if(reduceMotion)0f else target.parallaxY,spring(damping,stiffness),label="referral.parallax.y")
    val scale by animateFloatAsState(if(interacting&&!reduceMotion)1.012f else 1f,spring(.8f,341.5f),label="referral.scale")
    fun stopFeedback() {copyJob?.cancel();copyJob=null;sound?.release();sound=null;copied=false;interacting=false;target=ReferralCardTilt()}
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver {_,event -> if(event==Lifecycle.Event.ON_STOP)stopFeedback()}
        owner.lifecycle.addObserver(observer)
        onDispose {owner.lifecycle.removeObserver(observer);stopFeedback()}
    }
    fun copy() {
        val payload=copyText.ifEmpty {normalized};if(payload.isEmpty())return
        clipboard.setText(AnnotatedString(payload));haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        copyJob?.cancel();sound?.release();sound=null;copied=true
        copyJob=scope.launch {
            var player:MediaPlayer?=null
            try {
                val audio=context.getSystemService(AudioManager::class.java)
                if(audio.ringerMode==AudioManager.RINGER_MODE_NORMAL) {
                    player=MediaPlayer()
                    try {
                        player.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                        context.resources.openRawResourceFd(R.raw.referral_copy).use {player.setDataSource(it.fileDescriptor,it.startOffset,it.length)}
                        player.prepare();player.start();sound=player
                    } catch(_:Exception) {player.release();player=null}
                }
                delay(280)
                repeat(8) {step ->delay(18);val volume=1f-(step+1)/8f;player?.setVolume(volume,volume)}
                player?.release();if(sound===player)sound=null;player=null
                delay(976);copied=false
            } finally {player?.release();if(sound===player)sound=null}
        }
        onCopied()
    }
    Box(modifier.fillMaxWidth().padding(vertical=18.dp).semantics {contentDescription=if(english)"Referral code $normalized"else"Code parrainage $normalized";customActions=listOf(CustomAccessibilityAction(if(english)"Copy referral link"else"Copier le lien de parrainage"){copy();true})}) {
        Box(Modifier.fillMaxWidth().height(210.dp).graphicsLayer {
            rotationZ=4.8f;rotationX=tx;rotationY=ty;translationX=px*density;translationY=py*density;scaleX=scale;scaleY=scale
            cameraDistance=900f*density;shadowElevation=(if(interacting)34f else 28f)*density;shape=RoundedCornerShape(26.dp);clip=false
            ambientShadowColor=Color.Black.copy(alpha=if(interacting).5f else .38f);spotShadowColor=ambientShadowColor
        }) {
            Box(Modifier.fillMaxSize().clip(RoundedCornerShape(26.dp)).pointerInput(reduceMotion) {
                awaitEachGesture {
                    val down=awaitFirstDown(requireUnconsumed=false)
                    try {
                        while(true) {
                            val change=awaitPointerEvent().changes.firstOrNull {it.id==down.id} ?: break
                            if(!change.pressed || change.isConsumed)break
                            val translation=change.position-down.position
                            ReferralCardModel.tilt(change.position.x/density,change.position.y/density,size.width/density,size.height/density,translation.x/density,translation.y/density)?.let {
                                if(!interacting)haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                interacting=true;target=it;change.consume()
                            }
                        }
                    } finally {target=ReferralCardTilt();interacting=false}
                }
            }) {
                ProcessReferralMetalSurface()
                Column(Modifier.fillMaxSize(),horizontalAlignment=Alignment.CenterHorizontally) {
                    Text(if(english)"YOUR REFERRAL CODE"else"TON CODE DE PARRAINAGE",fontSize=10.sp,fontWeight=FontWeight.SemiBold,letterSpacing=2.2.sp,color=Color(.36f,.37f,.40f),modifier=Modifier.padding(top=28.dp))
                    Spacer(Modifier.weight(1f))
                    Text(normalized,maxLines=1,fontSize=36.sp,fontWeight=FontWeight.Black,fontFamily=FontFamily.Monospace,letterSpacing=3.2.sp,style=TextStyle(brush=Brush.verticalGradient(listOf(Color(.30f,.31f,.34f),Color(.42f,.43f,.46f),Color(.34f,.35f,.38f))),shadow=Shadow(Color.White.copy(alpha=.48f),Offset(0f,1.4f*density),0f)),modifier=Modifier.padding(horizontal=16.dp))
                    Spacer(Modifier.weight(1f))
                    Text(if(english)"SHARE & EARN REWARDS"else"PARTAGE ET GAGNE",fontSize=10.sp,fontWeight=FontWeight.SemiBold,letterSpacing=2.sp,color=Color(.36f,.37f,.40f),modifier=Modifier.padding(bottom=28.dp))
                }
            }
            Button(onClick=::copy,enabled=normalized.isNotEmpty()||copyText.isNotEmpty(),modifier=Modifier.align(Alignment.BottomStart).padding(start=20.dp,bottom=14.dp).height(44.dp),shape=RoundedCornerShape(50),contentPadding=PaddingValues(horizontal=20.dp,vertical=11.dp),colors=ButtonDefaults.buttonColors(containerColor=Color.White,contentColor=Color.Black.copy(alpha=.88f))) {
                Text(if(copied) {if(english)"Copied"else"Copié"}else {if(english)"Copy"else"Copier"},fontSize=14.sp,fontWeight=FontWeight.SemiBold,modifier=Modifier.semantics {liveRegion=LiveRegionMode.Polite})
            }
        }
    }
}
