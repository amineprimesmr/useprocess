package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

/** The host supplies the real notification permission request; denial does not block continuing. */
@Composable fun ProcessCommitSlider(
    firstName:String,onComplete:()->Unit,modifier:Modifier=Modifier,
    requestNotificationPermission:suspend ()->Boolean={false},onReleased:(Float)->Unit={},
    english:Boolean=false,dark:Boolean=isSystemInDarkTheme()
) {
    val model=remember {CommitSliderModel()};val palette=InputPalette(dark);val accent=Color(.42f,.70f,1f)
    val reduced=rememberProcessReducedMotion();val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val haptics=LocalHapticFeedback.current;val density=LocalDensity.current.density
    val latestComplete by rememberUpdatedState(onComplete);val latestPermission by rememberUpdatedState(requestNotificationPermission)
    var progress by remember {mutableFloatStateOf(0f)};var dragging by remember {mutableStateOf(false)};var committed by remember {mutableStateOf(false)}
    var permissionFinished by remember {mutableStateOf(false)};var delivered by remember {mutableStateOf(false)}
    fun commit() {if(model.activate()){committed=true;progress=1f;dragging=false;haptics.performHapticFeedback(HapticFeedbackType.LongPress)}}
    LaunchedEffect(committed) {
        if(committed) {
            try {latestPermission()}catch(error:CancellationException){throw error}catch(_:Exception){}
            permissionFinished=true
        }
    }
    LaunchedEffect(permissionFinished,lifecycle) {
        if(permissionFinished&&!delivered&&lifecycle.isAtLeast(Lifecycle.State.RESUMED)) {delay(280);delivered=true;latestComplete()}
    }
    LaunchedEffect(lifecycle) {
        if(!lifecycle.isAtLeast(Lifecycle.State.RESUMED)&&!committed){model.cancel();progress=0f;dragging=false}
    }
    val animated by animateFloatAsState(progress,if(reduced||dragging)snap() else if(committed)spring(.86f,385.53f) else spring(.82f,273.40f),label="commit.slider.progress")
    val reveal by animateFloatAsState(if(committed)1f else ((progress-.06f)/.78f).coerceIn(0f,1f),if(reduced)snap() else tween(160,easing=FastOutSlowInEasing),label="commit.slider.title")
    val phase=if(!reduced&&!committed&&lifecycle.isAtLeast(Lifecycle.State.RESUMED)) {
        val transition=rememberInfiniteTransition(label="commit.chevrons")
        val value by transition.animateFloat(0f,1f,infiniteRepeatable(tween(700,easing=FastOutSlowInEasing),RepeatMode.Reverse),label="commit.chevrons.phase");value
    } else 0f
    Column(modifier.fillMaxSize().background(palette.background),verticalArrangement=Arrangement.Center) {
        Column(Modifier.fillMaxWidth().padding(horizontal=36.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(10.dp)) {
            Box(contentAlignment=Alignment.Center) {
                val name=OnboardingInputRules.trimName(firstName).takeIf(OnboardingInputRules::isRealName)
                Text(buildAnnotatedString {
                    append(if(english)"Start debloating today" else "Commence à debloat aujourd'hui")
                    if(name!=null){append(if(english)", " else " ");withStyle(SpanStyle(color=accent)){append(name)}}
                },fontSize=26.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center,modifier=Modifier.graphicsLayer {alpha=1-reveal;scaleX=1-reveal*.04f;scaleY=scaleX})
                Text(if(english)"Committed" else "C'est promis",fontSize=26.sp,fontWeight=FontWeight.Bold,color=accent,textAlign=TextAlign.Center,modifier=Modifier.graphicsLayer {alpha=reveal;scaleX=.96f+reveal*.04f;scaleY=scaleX})
            }
            Text(if(english)"A promise you make to yourself." else "Une promesse que tu te fais.",fontSize=15.sp,color=palette.muted,textAlign=TextAlign.Center)
        }
        Spacer(Modifier.height(32.dp))
        BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal=28.dp).height(92.dp).semantics(mergeDescendants=true) {
            role=Role.Button;contentDescription=if(english)"Slide to confirm" else "Glisse pour confirmer";progressBarRangeInfo=ProgressBarRangeInfo(progress,0f..1f)
            onClick {commit();true}
        }) {
            val travel=(maxWidth-92.dp).coerceAtLeast(1.dp);val knobX=6.dp+travel*animated
            Box(Modifier.fillMaxSize().clip(RoundedCornerShape(50)).background(if(dark)Color(.18f,.18f,.18f) else Color(.86f,.86f,.86f)))
            if(animated>.02f||committed)Box(Modifier.width(maxOf(92.dp,knobX+86.dp)).height(92.dp).clip(RoundedCornerShape(50)).background(Brush.horizontalGradient(listOf(accent.copy(alpha=.72f),accent,Color(.28f,.52f,.98f)))))
            Box(Modifier.fillMaxSize().drawWithContent {clipRect(right=size.width*animated){this@drawWithContent.drawContent()}}.clearAndSetSemantics {},contentAlignment=Alignment.Center) {Text(if(english)"Committed" else "C'est promis",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=Color.White)}
            Box(Modifier.fillMaxSize().drawWithContent {clipRect(left=size.width*animated){this@drawWithContent.drawContent()}}.clearAndSetSemantics {},contentAlignment=Alignment.Center) {Text(if(english)"Slide to confirm" else "Glisse pour confirmer",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary.copy(alpha=.72f))}
            if(!committed&&animated<.62f)Canvas(Modifier.align(Alignment.CenterEnd).padding(end=18.dp).width(33.dp).height(18.dp).alpha(1-(animated/.5f).coerceAtMost(1f))) {
                repeat(3) {index->
                    val x=index*11.dp.toPx()+phase*3.dp.toPx();val y=size.height/2
                    val color=palette.muted.copy(alpha=(.35f+index*.18f+phase*.22f).coerceAtMost(1f))
                    drawLine(color,Offset(x,y-5.dp.toPx()),Offset(x+5.dp.toPx(),y),2.dp.toPx(),StrokeCap.Round)
                    drawLine(color,Offset(x+5.dp.toPx(),y),Offset(x,y+5.dp.toPx()),2.dp.toPx(),StrokeCap.Round)
                }
            }
            Box(Modifier.offset(x=knobX,y=6.dp).size(80.dp).shadow(if(dragging)10.dp else 6.dp,CircleShape,ambientColor=accent.copy(alpha=.38f),spotColor=Color.Black.copy(alpha=.16f)).clip(CircleShape).background(Color.White).border(3.dp,accent,CircleShape)
                .pointerInput(travel,committed) {
                    var translation=0f
                    detectDragGestures(onDragStart={if(!committed){dragging=true;translation=0f;haptics.performHapticFeedback(HapticFeedbackType.LongPress)}},onDrag={change,amount->
                        if(!committed){change.consume();translation+=amount.x;val bucket=model.drag(translation,travel.value*density);progress=model.progress;if(bucket!=null)haptics.performHapticFeedback(if(bucket>=8)HapticFeedbackType.LongPress else HapticFeedbackType.TextHandleMove)}
                    },onDragEnd={
                        if(!committed) {
                            val released=progress
                            if(model.release()){committed=true;progress=1f;haptics.performHapticFeedback(HapticFeedbackType.LongPress)}
                            else {onReleased(released);progress=0f;haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}
                            dragging=false
                        }
                    },onDragCancel={model.cancel();progress=model.progress;dragging=false})
                })
        }
    }
}
