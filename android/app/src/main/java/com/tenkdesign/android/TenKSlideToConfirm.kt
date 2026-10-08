package com.tenkdesign.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

/** SlideToConfirm by Balaji Venkatesh, 7 April 2025. Completion is a gesture, not payment verification. */
data class SlideConfirmConfig(
    val idleText:String="Swipe to Pay",
    val onSwipeText:String="Confirms Payment",
    val confirmationText:String="Success!",
    val tint:Color=Color(0xFF34C759),
    val foreground:Color=Color.White,
    val height:Dp=65.dp,
    val knobPadding:Dp=5.dp,
)

@Composable fun TenKSlideToConfirm(
    onSwiped:()->Unit,
    modifier:Modifier=Modifier,
    config:SlideConfirmConfig=SlideConfirmConfig(),
    reduceMotion:Boolean=false,
    accessibilityAction:String="Confirm by sliding",
) {
    require(config.height.value.isFinite() && config.height >= 40.dp)
    require(config.knobPadding.value.isFinite() && config.knobPadding >= 0.dp && config.knobPadding < config.height/2)
    var completed by remember {mutableStateOf(false)}
    var dragOffset by remember {mutableFloatStateOf(0f)}
    var dragging by remember {mutableStateOf(false)}
    val onConfirm by rememberUpdatedState(onSwiped)
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    val shimmer=remember {Animatable(0f)}
    LaunchedEffect(completed,reduceMotion,lifecycle) {
        if(completed||reduceMotion)shimmer.snapTo(0f)
        else lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while(true) {shimmer.snapTo(0f);shimmer.animateTo(1f,tween(2500,easing=LinearEasing))}
        }
    }
    fun confirm() {if(!completed){completed=true;dragging=false;onConfirm()}}
    val response:FiniteAnimationSpec<Float> = if(reduceMotion)snap() else spring(1f,550f)
    val completion by animateFloatAsState(if(completed)1f else 0f,response,label="slide.completion")
    val visualOffset by animateFloatAsState(dragOffset,if(dragging||reduceMotion)snap()else spring(1f,550f),label="slide.return")
    val parentWidth=LocalConfiguration.current.screenWidthDp.dp
    BoxWithConstraints(modifier,contentAlignment=Alignment.Center) {
        val width=minOf(maxWidth,300.dp,parentWidth*(.8f-.3f*completion))
        val height=config.height+(50.dp-config.height)*completion
        val limit=with(LocalDensity.current){(width-height).toPx()}.coerceAtLeast(0f)
        val progress=if(completed)1f else if(limit>0)visualOffset.coerceIn(0f,limit)/limit else 0f
        val background=if(isSystemInDarkTheme())Color.Black else Color.White
        Box(Modifier.width(width).height(height).clip(CircleShape).background(Color.Gray.copy(alpha=.25f)).clearAndSetSemantics {
            contentDescription=if(completed)config.confirmationText else config.idleText
            stateDescription=if(completed)config.confirmationText else config.idleText
            progressBarRangeInfo=ProgressBarRangeInfo(progress,0f..1f)
            if(completed)disabled() else customActions=listOf(CustomAccessibilityAction(accessibilityAction){confirm();true})
        }) {
            Box(Modifier.fillMaxHeight().width(height+(width-height)*progress).background(Brush.verticalGradient(listOf(config.tint,config.tint.copy(alpha=.86f))),CircleShape))
            Box(Modifier.fillMaxSize().drawWithContent {clipRect(right=size.width*progress){this@drawWithContent.drawContent()}}.padding(end=height*(1f-.4f*completion)/2),contentAlignment=Alignment.Center) {
                Text(config.onSwipeText,color=config.foreground,fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,modifier=Modifier.graphicsLayer {alpha=1f-completion}.blur((completion*10).dp))
                Text(config.confirmationText,color=config.foreground,fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,modifier=Modifier.graphicsLayer {alpha=completion}.blur(((1f-completion)*10).dp))
            }
            Box(Modifier.fillMaxSize().padding(start=height,end=height/2).drawWithContent {clipRect(left=-height.toPx()+(size.width+height.toPx())*progress){this@drawWithContent.drawContent()}},contentAlignment=Alignment.Center) {
                Text(config.idleText,color=Color.Gray.copy(alpha=.6f),fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,modifier=Modifier.drawWithContent {
                    drawContext.canvas.saveLayer(androidx.compose.ui.geometry.Rect(Offset.Zero,size),Paint())
                    drawContent()
                    if(!reduceMotion&&!completed) {
                        val x=(-1f/1.8f+shimmer.value*1.2f)*size.width
                        drawRect(Brush.horizontalGradient(listOf(Color.Transparent,Color.White,Color.Transparent),x,x+15.dp.toPx()),blendMode=BlendMode.SrcAtop)
                    }
                    drawContext.canvas.restore()
                })
            }
            val knobX=if(completed)limit else visualOffset.coerceIn(0f,limit)
            Box(Modifier.offset {IntOffset(knobX.toInt(),0)}.size(height).graphicsLayer {scaleX=1f-.4f*completion;scaleY=1f-.4f*completion}.then(
                if(completed)Modifier else Modifier.pointerInput(limit) {
                    detectDragGestures(
                        onDragStart={dragging=true},
                        onDragCancel={dragging=false;dragOffset=0f},
                        onDragEnd={dragging=false;if(limit>0f&&dragOffset>=limit)confirm()else dragOffset=0f},
                        onDrag={change,amount->change.consume();dragOffset=(dragOffset+amount.x).coerceIn(0f,limit)},
                    )
                }
            ).padding(config.knobPadding).background(background,CircleShape),contentAlignment=Alignment.Center) {
                Canvas(Modifier.size(21.dp)) {
                    val stroke=androidx.compose.ui.graphics.drawscope.Stroke(2.8.dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round)
                    val arrow=Path().apply {moveTo(size.width*.35f,size.height*.2f);lineTo(size.width*.65f,size.height*.5f);lineTo(size.width*.35f,size.height*.8f)}
                    val check=Path().apply {moveTo(size.width*.15f,size.height*.5f);lineTo(size.width*.4f,size.height*.75f);lineTo(size.width*.88f,size.height*.25f)}
                    val ink=if(background==Color.Black)Color.White else Color.Black
                    drawPath(arrow,ink.copy(alpha=1f-progress),style=stroke);drawPath(check,ink.copy(alpha=progress),style=stroke)
                }
            }
        }
    }
}
