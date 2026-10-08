package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState

@Stable class SwipeActionCoordinator {var activeId:String? by mutableStateOf(null);internal set;fun close(){activeId=null}}
@Composable fun rememberSwipeActionCoordinator(contextKey:Any)=remember(contextKey){SwipeActionCoordinator()}
data class TenKSwipeAction(val id:String,val label:String,val background:Color,val tint:Color=Color.White,val width:Dp=45.dp,val height:Dp=45.dp,val onAction:()->Boolean,val icon:@Composable ()->Unit)
@Composable fun TenKSwipeActions(
 id:String,coordinator:SwipeActionCoordinator,actions:List<TenKSwipeAction>,modifier:Modifier=Modifier,
 spacing:Dp=10.dp,leadingPadding:Dp=0.dp,trailingPadding:Dp=10.dp,content:@Composable ()->Unit,
) {
 require(id.isNotBlank());require(actions.map {it.id}.distinct().size==actions.size)
 require(spacing.value.isFinite()&&spacing>=0.dp&&leadingPadding.value.isFinite()&&leadingPadding>=0.dp&&trailingPadding.value.isFinite()&&trailingPadding>=0.dp)
 require(actions.all {it.id.isNotBlank()&&it.width.value.isFinite()&&it.height.value.isFinite()&&it.width>0.dp&&it.height>0.dp})
 val density=LocalDensity.current;val width=with(density){(actions.fold(0.dp){a,b->a+b.width}+spacing*maxOf(actions.size-1,0)+leadingPadding+trailingPadding).toPx()}
 var offset by remember(id,coordinator){mutableFloatStateOf(0f)};var bounce by remember(id,coordinator){mutableFloatStateOf(0f)}
 var dragging by remember(id,coordinator){mutableStateOf(false)};var sourceY by remember(id){mutableStateOf<Float?>(null)}
 val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
 fun close(){offset=0f;bounce=0f;dragging=false;if(coordinator.activeId==id)coordinator.close()}
 LaunchedEffect(coordinator.activeId,life,width){if(coordinator.activeId!=id||!life.isAtLeast(Lifecycle.State.RESUMED)||actions.isEmpty())close()}
 val rendered by animateFloatAsState(offset,if(dragging)snap()else tween(300),label="swipe offset")
 val renderedBounce by animateFloatAsState(bounce,if(dragging)snap()else tween(300),label="swipe resistance")
 val progress=if(width>0f)(-rendered/width).coerceIn(0f,1f)else 0f
 val latestActions by rememberUpdatedState(actions)
 Box(modifier.clipToBounds().onGloballyPositioned {coordinates->val y=coordinates.positionInRoot().y;if(sourceY!=null&&kotlin.math.abs(y-sourceY!!)>1f&&(offset!=0f||dragging))close();sourceY=y}.semantics {
  customActions=actions.map {action->CustomAccessibilityAction(action.label){val dismiss=action.onAction();if(dismiss)close();true}}
 }.pointerInput(id,coordinator,width,life) {
  if(actions.isEmpty()||!life.isAtLeast(Lifecycle.State.RESUMED))return@pointerInput
  var start=0f;var translation=0f;val velocity=VelocityTracker()
  detectHorizontalDragGestures(onDragStart={start=offset;translation=0f;dragging=true;coordinator.activeId=id;velocity.resetTracking()},onDragEnd={
   val open=swipeActionsShouldOpen(offset,velocity.calculateVelocity().x,width);dragging=false;bounce=0f;offset=if(open)-width else 0f;if(!open&&coordinator.activeId==id)coordinator.close()
  },onDragCancel={close()}) {change,amount->
   change.consume();velocity.addPosition(change.uptimeMillis,change.position);translation+=amount
   val value=swipeActionsPosition(start,translation,width);offset=value.offset;bounce=value.bounce
  }
 }) {
  Box(Modifier.offset {IntOffset((rendered+renderedBounce).toInt(),0)}) {content()}
  if(progress>0f)Box(Modifier.matchParentSize()) {
   var preceding=0.dp
   latestActions.forEach {action->
    val position=preceding;preceding+=action.width+spacing
    Box(Modifier.align(Alignment.CenterEnd).offset {IntOffset((action.width.toPx()+leadingPadding.toPx()+position.toPx()*progress+rendered+renderedBounce).toInt(),0)}.size(action.width,action.height).background(action.background,CircleShape).clickable(role=Role.Button){if(action.onAction())close()}.semantics {contentDescription=action.label},contentAlignment=Alignment.Center) {
     CompositionLocalProvider(androidx.compose.material3.LocalContentColor provides action.tint) {action.icon()}
    }
   }
  }
 }
 DisposableEffect(id,coordinator){onDispose {if(coordinator.activeId==id)coordinator.close()}}
}
