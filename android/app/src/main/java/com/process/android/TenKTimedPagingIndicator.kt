package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState

/** A controlled timer: a host which ignores onSelectionChange does not receive repeated requests. */
@Composable fun TenKTimedPagingIndicator(
 count:Int,durationMillis:Long,isPaused:Boolean,selection:Int,onSelectionChange:(Int)->Unit,
 modifier:Modifier=Modifier,contextKey:Any=Unit,activeTint:Color=LocalContentColor.current,inactiveTint:Color=Color.Gray,
 reduceMotion:Boolean=rememberProcessReducedMotion(),
) {
 require(count>=0);require(durationMillis in 1..Long.MAX_VALUE/1_000_000);require(if(count==0)selection==0 else selection in 0 until count)
 var progress by remember(contextKey){mutableFloatStateOf(0f)}
 val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState();val callback by rememberUpdatedState(onSelectionChange)
 val paused=isPaused||!life.isAtLeast(Lifecycle.State.RESUMED)
 LaunchedEffect(contextKey,count,durationMillis,selection,paused) {
  progress=0f
  if(paused||count<=1)return@LaunchedEffect
  val duration=durationMillis*1_000_000;val start=withFrameNanos {it}
  while(progress<1f)withFrameNanos {now->progress=((now-start).toDouble()/duration).coerceIn(0.0,1.0).toFloat()}
  timedPagingNext(selection,count)?.let(callback)
 }
 Row(modifier.height(10.dp).semantics(mergeDescendants=true) {
  contentDescription="Page indicator";stateDescription=if(count==0)"No pages"else "${selection+1} / $count"
  if(count>0)progressBarRangeInfo=ProgressBarRangeInfo(selection.toFloat(),0f..maxOf(count-1,0).toFloat())
 },horizontalArrangement=Arrangement.spacedBy(5.dp),verticalAlignment=Alignment.CenterVertically) {
  repeat(count){index->
   val active=index==selection
   val width by animateDpAsState(if(active&&!isPaused)20.dp else 5.dp,if(reduceMotion)snap()else tween(300),label="page width")
   Box(Modifier.width(width).height(5.dp).clip(CircleShape).background(inactiveTint)) {
    if(active)Box(Modifier.fillMaxHeight().fillMaxWidth(if(isPaused)1f else progress).background(activeTint))
   }
  }
 }
}
