package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.launch

/** Put at the viewport trailing edge; pass the actual content ScrollState and host-derived label. */
@Composable fun TenKScrollIndicator(scrollState:ScrollState,activeLabel:String,modifier:Modifier=Modifier) {
 val density=LocalDensity.current;val scope=rememberCoroutineScope();val dark=isSystemInDarkTheme()
 var dragging by remember(scrollState){mutableStateOf(false)}
 val visible=dragging||scrollState.isScrollInProgress
 val alpha by animateFloatAsState(if(visible)1f else 0f,tween(250),label="scroll label alpha")
 val lift by animateDpAsState(if(dragging)(-50).dp else 0.dp,tween(250),label="scroll label lift")
 val progress=scrollIndicatorProgress(scrollState.value.toFloat(),scrollState.maxValue.toFloat())
 val gradient=remember {Brush.verticalGradient(listOf(Color(0xFF2997FF),Color(0xFF007AFF)))}
 BoxWithConstraints(modifier.width(48.dp)) {
  val height=maxHeight;val thumbHeight=minOf(40.dp,height);val travel=with(density){(height-thumbHeight).toPx()}.coerceAtLeast(0f)
  val offset=travel*progress
  Box(Modifier.align(Alignment.TopEnd).padding(end=5.dp).width(8.dp).fillMaxHeight().shadow(10.dp,RoundedCornerShape(50),ambientColor=Color.Black.copy(alpha=.2f),spotColor=Color.Black.copy(alpha=.2f)).background(if(dark)Color(0xFF1C1C1E)else Color.White,RoundedCornerShape(50)))
  Box(Modifier.align(Alignment.TopEnd).offset {IntOffset(0,offset.toInt())}.width(48.dp).height(thumbHeight).semantics {
   contentDescription="Scroll position";stateDescription=activeLabel
   progressBarRangeInfo=ProgressBarRangeInfo(progress,0f..1f)
   setProgress {value->if(value.isFinite()){scope.launch {scrollState.scrollTo((value.coerceIn(0f,1f)*scrollState.maxValue).toInt())};true}else false}
  }.pointerInput(scrollState,travel) {
   var baseline=0f;var translation=0f
   detectDragGestures(onDragStart={baseline=scrollIndicatorProgress(scrollState.value.toFloat(),scrollState.maxValue.toFloat());translation=0f;dragging=true},onDragEnd={dragging=false},onDragCancel={dragging=false}) {change,amount->
    change.consume();translation+=amount.y
    val target=scrollIndicatorDraggedProgress(baseline,translation,travel)*scrollState.maxValue
    // Synchronous delta avoids queued scroll coroutines racing fast pointer movement.
    scrollState.dispatchRawDelta(target-scrollState.value)
   }
  },contentAlignment=Alignment.CenterEnd) {
   Box(Modifier.padding(end=5.dp).width(8.dp).fillMaxHeight().background(gradient,RoundedCornerShape(50)))
  }
  if(alpha>0f)Box(Modifier.align(Alignment.TopEnd).offset {IntOffset(with(density){(-18).dp.toPx()}.toInt()-50.dp.roundToPx(),(offset-10.dp.toPx()+lift.toPx()).toInt())}.size(50.dp).alpha(alpha).background(gradient,RoundedCornerShape(topStart=50.dp,topEnd=50.dp,bottomStart=50.dp,bottomEnd=5.dp)).clearAndSetSemantics {},contentAlignment=Alignment.Center) {
   Text(activeLabel,color=Color.White,fontSize=28.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,maxLines=1)
  }
 }
 DisposableEffect(scrollState){onDispose {dragging=false}}
}
