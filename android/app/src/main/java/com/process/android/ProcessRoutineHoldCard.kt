package com.process.android

import android.os.SystemClock
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.delay

@Composable internal fun ProcessRoutineHoldCard(
    title:String,completed:Boolean,enabled:Boolean,onOpen:()->Unit,onValidate:()->Unit,
    modifier:Modifier=Modifier,english:Boolean=false,reduceMotion:Boolean=false,content:@Composable ()->Unit,
) {
    val model=remember {RoutineHoldModel()};val owner=LocalLifecycleOwner.current;val haptic=LocalHapticFeedback.current
    var holding by remember {mutableStateOf(false)};var progress by remember {mutableFloatStateOf(0f)};var burst by remember {mutableStateOf(false)};var expandedBurst by remember {mutableStateOf(false)}
    val latestOpen by rememberUpdatedState(onOpen);val latestValidate by rememberUpdatedState(onValidate)
    val latestCompleted by rememberUpdatedState(completed);val latestEnabled by rememberUpdatedState(enabled)
    fun cancel(){model.cancel();holding=false;progress=0f}
    fun validate(){if(!latestCompleted&&latestEnabled){holding=false;burst=true;expandedBurst=true;haptic.performHapticFeedback(HapticFeedbackType.LongPress);latestValidate()}}
    DisposableEffect(owner){val observer=LifecycleEventObserver {_,event->if(event==Lifecycle.Event.ON_PAUSE)cancel()};owner.lifecycle.addObserver(observer);onDispose {owner.lifecycle.removeObserver(observer);model.cancel()}}
    LaunchedEffect(completed,enabled){if(completed||!enabled)cancel()}
    LaunchedEffect(holding) {
        if(holding) {
            val startedAt=SystemClock.uptimeMillis()
            var firstFrame:Long?=null
            while(model.holding)withFrameNanos {frame ->
                val origin=firstFrame?:frame.also {firstFrame=it}
                val finished=model.tick(startedAt+(frame-origin)/1_000_000);progress=model.progress
                if(finished)validate()
            }
        }
    }
    LaunchedEffect(burst){if(burst){delay(120);expandedBurst=false;delay(430);burst=false}}
    LaunchedEffect(holding){if(holding)while(true){delay(40);haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)}}
    val scale by animateFloatAsState(if(holding).97f else if(expandedBurst)1.03f else 1f,if(reduceMotion)snap()else if(holding)tween(180,easing=LinearOutSlowInEasing)else spring(.78f,223.8f),label="routine.hold.scale")
    val accent=Color(.655f,.769f,.949f);val shape=RoundedCornerShape(22.dp)
    Box(modifier.graphicsLayer {scaleX=scale;scaleY=scale}.pointerInput(enabled,completed) {
        awaitEachGesture {
            awaitFirstDown(requireUnconsumed=false)
            if(!latestEnabled||latestCompleted){if(waitForUpOrCancellation()!=null)latestOpen();return@awaitEachGesture}
            model.begin(SystemClock.uptimeMillis());holding=true;haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            try {
                val up=waitForUpOrCancellation()
                if(up!=null&&owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                    if(model.release(SystemClock.uptimeMillis()))latestOpen()
                    holding=false;progress=0f
                }else cancel()
            }finally {cancel()}
        }
    }.clearAndSetSemantics {
        contentDescription=title
        stateDescription=if(completed){if(english)"Completed for today"else"Validée pour aujourd’hui"}else{if(english)"Hold for 5 seconds to complete, or tap for details"else"Maintiens 5 secondes pour valider, ou tape pour les détails"}
        onClick(if(english)"Details"else"Détails"){latestOpen();true}
        if(enabled&&!completed)customActions=listOf(CustomAccessibilityAction(if(english)"Mark complete"else"Valider l’exercice"){validate();true})
    }) {
        content()
        if(holding)Canvas(Modifier.matchParentSize()) {
            val inset=1.5.dp.toPx();val r=22.dp.toPx();val right=size.width-inset;val bottom=size.height-inset
            val path=Path().apply {
                moveTo(size.width/2,inset);lineTo(right-r,inset);arcTo(Rect(right-2*r,inset,right,inset+2*r),-90f,90f,false)
                lineTo(right,bottom-r);arcTo(Rect(right-2*r,bottom-2*r,right,bottom),0f,90f,false)
                lineTo(inset+r,bottom);arcTo(Rect(inset,bottom-2*r,inset+2*r,bottom),90f,90f,false)
                lineTo(inset,inset+r);arcTo(Rect(inset,inset,inset+2*r,inset+2*r),180f,90f,false);lineTo(size.width/2,inset)
            }
            val measure=PathMeasure();measure.setPath(path,false);val drawn=Path();measure.getSegment(0f,measure.length*progress,drawn,true)
            drawPath(drawn,accent,style=Stroke(3.dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round))
            drawRoundRect(accent.copy(alpha=.18f+progress*.22f),cornerRadius=CornerRadius(r),style=Stroke(1.dp.toPx()))
        }
        if(burst||completed) {
            Box(Modifier.matchParentSize().border(2.dp,Color.Green.copy(alpha=if(completed).55f else .35f),shape).then(if(burst)Modifier.background(Color.White.copy(alpha=.28f),shape)else Modifier))
            Box(Modifier.padding(10.dp).size(22.dp).graphicsLayer {scaleX=if(burst)1.12f else 1f;scaleY=scaleX}.background(Color(0xff34c759),CircleShape),contentAlignment=Alignment.Center){Text("✓",color=Color.White,fontSize=16.sp,lineHeight=20.sp)}
        }
    }
}
