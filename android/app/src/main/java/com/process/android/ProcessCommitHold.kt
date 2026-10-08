package com.process.android

import android.os.SystemClock
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay

/** Four-second commitment gesture. This screen does not collect fingerprints or authenticate a person. */
@Composable fun ProcessCommitHold(onComplete:()->Unit,modifier:Modifier=Modifier,english:Boolean=false,dark:Boolean=isSystemInDarkTheme(),onStarted:()->Unit={},onAbandoned:(Float)->Unit={}) {
    val palette=InputPalette(dark);val green=Color(.13f,.98f,.47f)
    val model=remember {CommitHoldModel()};val owner=LocalLifecycleOwner.current;val haptics=LocalHapticFeedback.current
    var pressed by remember {mutableStateOf(false)};var progress by remember {mutableFloatStateOf(0f)};var done by remember {mutableStateOf(false)};var delivered by remember {mutableStateOf(false)}
    val latestComplete by rememberUpdatedState(onComplete);val latestAbandoned by rememberUpdatedState(onAbandoned)
    val reduced=rememberProcessReducedMotion()
    fun release() {val abandoned=model.release();pressed=false;progress=model.progress;if(abandoned>.12f)latestAbandoned(abandoned)}
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver {_,event->if(event==Lifecycle.Event.ON_PAUSE)release()}
        owner.lifecycle.addObserver(observer)
        onDispose {owner.lifecycle.removeObserver(observer);model.release()}
    }
    LaunchedEffect(pressed) {
        if(pressed)while(model.pressed) {
            withFrameNanos {
                val milestones=model.tick(SystemClock.uptimeMillis());progress=model.progress
                if(milestones.isNotEmpty())haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                if(model.completed){done=true;pressed=false}
            }
        }
    }
    LaunchedEffect(done) {
        if(done&&!delivered)owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            if(!delivered) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress);delay(100)
                haptics.performHapticFeedback(HapticFeedbackType.LongPress);delay(250)
                delivered=true;latestComplete()
            }
        }
    }
    val scale by animateFloatAsState(if(pressed)1.05f else 1f,if(reduced)snap() else spring(.6f,438.65f),label="commit.fingerprint.scale")
    val visibleProgress by animateFloatAsState(progress,if(reduced)snap() else if(pressed)tween(16,easing=LinearEasing) else spring(.78f,322.27f),label="commit.progress")
    val rows=if(english)listOf("Stick to my plan 7 days a week","Scan my face and track my progress","Trust Process to guide me") else listOf("Tenir mon plan 7 jours sur 7","Scanner mon visage et suivre mes progrès","Faire confiance à Process pour m'accompagner")
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background)) {
        val height=maxHeight
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min=height)) {
            Spacer(Modifier.height(54.dp))
            Text(if(english)"Commit to yourself" else "Engage-toi envers toi-même",fontSize=32.sp,lineHeight=38.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center,modifier=Modifier.fillMaxWidth().padding(horizontal=32.dp))
            Spacer(Modifier.height(72.dp))
            Text(if(english)"From this day on, I commit to:" else "À partir de ce jour, je m'engage à :",fontSize=15.sp,color=palette.body,modifier=Modifier.padding(horizontal=40.dp))
            Spacer(Modifier.height(22.dp))
            Column(Modifier.padding(horizontal=40.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                rows.forEachIndexed {index,text->
                    val fill=((visibleProgress-index/3f)*3).coerceIn(0f,1f)
                    Row(horizontalArrangement=Arrangement.spacedBy(12.dp),verticalAlignment=Alignment.Top) {
                        Box(Modifier.padding(top=1.dp).size(22.dp),contentAlignment=Alignment.Center) {
                            Box(Modifier.size(22.dp).scale(1-fill*.08f).alpha(1-(fill*1.4f).coerceAtMost(1f)).border(1.5.dp,palette.primary.copy(alpha=.18f+.12f*(1-fill)),CircleShape))
                            Box(Modifier.size(20.dp).scale(.35f+.65f*fill).alpha(fill).clip(CircleShape).background(green),contentAlignment=Alignment.Center) {Text("✓",fontSize=13.sp,fontWeight=FontWeight.Bold,color=palette.background)}
                        }
                        Text(text,fontSize=14.sp,lineHeight=18.sp,fontWeight=if(fill>=.98f)FontWeight.SemiBold else FontWeight.Medium,color=palette.primary.copy(alpha=.34f+.66f*fill))
                    }
                }
            }
            Spacer(Modifier.height(36.dp));Spacer(Modifier.weight(1f))
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal=40.dp).height(380.dp),contentAlignment=Alignment.Center) {
                val side=(maxWidth-48.dp).coerceIn(260.dp,380.dp)
                Box(Modifier.size(side).pointerInput(model) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed=false)
                        if(model.press(SystemClock.uptimeMillis())) {pressed=true;progress=0f;onStarted();haptics.performHapticFeedback(HapticFeedbackType.LongPress)}
                        waitForUpOrCancellation();release()
                    }
                }.semantics(mergeDescendants=true) {
                    role=Role.Button;contentDescription=if(english)"I commit. Hold for 4 seconds, or activate to confirm" else "Je m'engage. Maintenir 4 secondes, ou activer pour valider"
                    progressBarRangeInfo=ProgressBarRangeInfo(progress,0f..1f)
                    onClick {if(model.activate()){progress=1f;done=true;pressed=false};true}
                },contentAlignment=Alignment.Center) {
                    Image(painterResource(if(dark)R.drawable.fingerprint_dark else R.drawable.fingerprint_light),contentDescription=null,modifier=Modifier.fillMaxSize().scale(scale))
                    Canvas(Modifier.size(side*(210f/380f)).offset(y=if(dark)0.dp else (-7).dp)) {
                        drawArc(Brush.linearGradient(listOf(green.copy(alpha=.6f),Color(.20f,.85f,.60f).copy(alpha=.4f),green.copy(alpha=.3f)),Offset.Zero,Offset(size.width,size.height)),startAngle=-90f,sweepAngle=visibleProgress*360,useCenter=false,style=Stroke(2.5.dp.toPx(),cap=StrokeCap.Round))
                    }
                }
            }
            Spacer(Modifier.height(50.dp))
        }
    }
}
