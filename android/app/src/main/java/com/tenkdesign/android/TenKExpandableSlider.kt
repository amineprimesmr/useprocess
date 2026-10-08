package com.tenkdesign.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner

/** CustomSlider, Balaji Venkatesh,8November2024. Original upper-bound-based fill and translation preserved. */
data class ExpandableSliderConfig(
 val inactiveTint:Color=Color.Black.copy(alpha=.06f),val activeTint:Color=Color.Black,
 val cornerRadius:Dp=15.dp,val extraHeight:Dp=25.dp,
 val overlayActiveTint:Color=Color.White,val overlayInactiveTint:Color=Color.Black,
)
@Composable fun TenKExpandableSlider(
 value:Float,onValueChange:(Float)->Unit,modifier:Modifier=Modifier,range:ClosedFloatingPointRange<Float> = 0f..100f,
 config:ExpandableSliderConfig=ExpandableSliderConfig(),reduceMotion:Boolean=false,
 accessibilityLabel:String="Value",onGestureActive:(Boolean)->Unit={},overlay:@Composable (Color)->Unit={},
) {
 val bounded=ExpandableSliderModel.safe(value,range)
 require(config.cornerRadius.value.isFinite()&&config.cornerRadius>=0.dp&&config.extraHeight.value.isFinite()&&config.extraHeight>=0.dp)
 var active by remember {mutableStateOf(false)}
 val latestValue by rememberUpdatedState(bounded);val change by rememberUpdatedState(onValueChange);val gesture by rememberUpdatedState(onGestureActive)
 val owner=LocalLifecycleOwner.current
 fun end(){if(active){active=false;gesture(false)}}
 DisposableEffect(owner){val observer=LifecycleEventObserver {_,event->if(event==Lifecycle.Event.ON_PAUSE)end()};owner.lifecycle.addObserver(observer);onDispose {owner.lifecycle.removeObserver(observer);end()}}
 val height by animateDpAsState(20.dp+if(active)config.extraHeight else 0.dp,if(reduceMotion)snap()else tween(500,easing=CubicBezierEasing(.2f,.8f,.2f,1f)),label="expandable.height")
 val opacity by animateFloatAsState(if(active)1f else 0f,if(reduceMotion)snap()else tween(if(active)300 else 150,delayMillis=if(active)120 else 0,easing=CubicBezierEasing(.42f,0f,.58f,1f)),label="expandable.overlay")
 val fraction=ExpandableSliderModel.fraction(bounded,range)
 Box(modifier.fillMaxWidth().height(20.dp+config.extraHeight).drawWithContent {
     val y=(size.height-height.toPx())/2
     val path=Path().apply {addRoundRect(RoundRect(0f,y,size.width,y+height.toPx(),CornerRadius(config.cornerRadius.toPx())))}
     clipPath(path){this@drawWithContent.drawContent()}
 }.semantics {
     contentDescription=accessibilityLabel;progressBarRangeInfo=ProgressBarRangeInfo(bounded,range)
     setProgress {change(ExpandableSliderModel.safe(it,range));true}
 }.pointerInput(range,owner) {
     awaitEachGesture {
         val down=awaitFirstDown(requireUnconsumed=false);down.consume()
         val start=down.position;val initial=latestValue;active=true;gesture(true)
         try {
             while(active&&owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                 val event=awaitPointerEvent();val pointer=event.changes.firstOrNull {it.id==down.id}?:break
                 if(pointer.isConsumed)break
                 if(!pointer.pressed){pointer.consume();break}
                 change(ExpandableSliderModel.drag(initial,pointer.position.x-start.x,size.width.toFloat(),range));pointer.consume()
             }
         }finally {end()}
     }
 }) {
     Box(Modifier.fillMaxSize().background(config.inactiveTint))
     Box(Modifier.fillMaxSize().drawWithContent {clipRect(right=size.width*fraction){this@drawWithContent.drawContent()}}.background(config.activeTint))
     Box(Modifier.fillMaxSize().graphicsLayer {alpha=opacity}.clearAndSetSemantics {},contentAlignment=Alignment.CenterStart) {
         overlay(config.overlayInactiveTint)
         Box(Modifier.fillMaxSize().drawWithContent {clipRect(right=size.width*fraction){this@drawWithContent.drawContent()}},contentAlignment=Alignment.CenterStart){overlay(config.overlayActiveTint)}
     }
 }
}
