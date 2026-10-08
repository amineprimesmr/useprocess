package com.tenkdesign.android

// Android adaptation of SToasts by Balaji Venkatesh, 08–09/08/26.
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalAccessibilityManager
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import java.util.UUID

data class TenKStackedToast(
    val title:String,val description:String,val tint:Color,
    val autoDismissSeconds:Double?=null,val id:String=UUID.randomUUID().toString(),
)
private class ToastEntry(val toast:TenKStackedToast) {
    val visible=MutableTransitionState(false).apply {targetState=true}
    var requested=false
}

/** Place at the bottom of the host Box. Only the cards receive pointer input. */
@Composable fun TenKStackedToasts(
    toasts:List<TenKStackedToast>,onDismiss:(String)->Unit,
    modifier:Modifier=Modifier,glassTintOpacity:Float=0f,reduceMotion:Boolean=false,
    dismissLabel:String="Dismiss",icon:@Composable (TenKStackedToast)->Unit,
) {
    require(toasts.map {it.id}.distinct().size==toasts.size) {"Toast IDs must be unique"}
    val entries=remember {mutableStateListOf<ToastEntry>()}
    val dismiss by rememberUpdatedState(onDismiss)
    LaunchedEffect(toasts) {
        val ids=toasts.map {it.id}.toSet()
        entries.filter {it.toast.id !in ids}.forEach {it.visible.targetState=false}
        toasts.forEach {toast -> if(entries.none {it.toast.id==toast.id})entries.add(ToastEntry(toast))}
    }
    val density=LocalDensity.current.density
    val accessibility=LocalAccessibilityManager.current
    val dark=isSystemInDarkTheme()
    val ink=if(dark)Color.White else Color.Black
    val opacity=if(glassTintOpacity.isFinite())glassTintOpacity.coerceIn(0f,1f)else 0f
    val duration=if(reduceMotion)0 else 300
    val spec=tween<Float>(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f))
    val offset by animateFloatAsState(StackedToastModel.geometry(0,toasts.size).containerOffset,spec,label="toasts.container")
    Box(modifier.fillMaxWidth().height(90.dp).graphicsLayer {translationY=offset*density},contentAlignment=Alignment.TopCenter) {
        entries.forEach {entry ->
            key(entry.toast.id) {
                LaunchedEffect(entry) {
                    snapshotFlow {entry.visible.isIdle&&!entry.visible.currentState&&!entry.visible.targetState}.first {it}
                    entries.remove(entry)
                }
                val toast=toasts.firstOrNull {it.id==entry.toast.id}?:entry.toast
                val rank=toasts.asReversed().indexOfFirst {it.id==toast.id}.coerceAtLeast(0)
                val geometry=StackedToastModel.geometry(rank,toasts.size)
                val y by animateFloatAsState(geometry.stackOffset,spec,label="toast.stack.${toast.id}")
                val scale by animateFloatAsState(geometry.scale,spec,label="toast.scale.${toast.id}")
                fun requestDismiss() {if(!entry.requested&&entry.visible.targetState){entry.requested=true;dismiss(toast.id)}}
                LaunchedEffect(entry) {
                    StackedToastModel.autoDismissMs(toast.autoDismissSeconds)?.let {base ->
                        delay(accessibility?.calculateRecommendedTimeoutMillis(base,containsIcons=true,containsText=true,containsControls=true)?:base)
                        requestDismiss()
                    }
                }
                AnimatedVisibility(entry.visible,Modifier.zIndex((toasts.indexOfFirst {it.id==entry.toast.id}.takeIf {it>=0}?:entries.indexOf(entry)).toFloat()).graphicsLayer {translationY=y*density;scaleX=scale;scaleY=scale;transformOrigin=TransformOrigin(.5f,1f)},
                    enter=slideInVertically(tween(duration)){if(reduceMotion)0 else (500*density).toInt()}+fadeIn(tween(duration)),
                    exit=slideOutHorizontally(tween(duration)){if(reduceMotion)0 else -it}+fadeOut(tween(duration))) {
                    val blur by transition.animateFloat(transitionSpec={tween(duration)},label="toast.blur") {if(it==EnterExitState.Visible)0f else if(reduceMotion)0f else 8f}
                    Row(Modifier.widthIn(max=310.dp).fillMaxWidth().height(65.dp).blur(blur.dp)
                        .background((if(dark)Color(0xff151517)else Color(0xfff5f5f7)).copy(alpha=.86f),RoundedCornerShape(50))
                        .background((if(dark)Color.Black else Color.White).copy(alpha=opacity),RoundedCornerShape(50))
                        .background(Brush.verticalGradient(0f to toast.tint.copy(alpha=.15f),.5f to toast.tint.copy(alpha=.1f),1f to Color.Transparent),RoundedCornerShape(50))
                        .border(.5.dp,ink.copy(alpha=.08f),RoundedCornerShape(50))
                        .semantics(mergeDescendants=true) {liveRegion=LiveRegionMode.Polite;customActions=listOf(CustomAccessibilityAction(dismissLabel){requestDismiss();true})}
                        .pointerInput(entry,density) {
                            awaitEachGesture {
                                val down=awaitFirstDown(requireUnconsumed=false)
                                var translation=Offset.Zero
                                while(true) {
                                    val pointer=awaitPointerEvent().changes.firstOrNull {it.id==down.id}?:break
                                    if(pointer.isConsumed)break
                                    translation=pointer.position-down.position
                                    if(!pointer.pressed) {if(StackedToastModel.dismissGesture(translation.x/density,translation.y/density))requestDismiss();break}
                                    if(kotlin.math.hypot(translation.x,translation.y)>=20*density)pointer.consume()
                                }
                            }
                        }.padding(horizontal=20.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(15.dp)) {
                        Box(Modifier.size(28.dp),contentAlignment=Alignment.Center) {icon(toast)}
                        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                            Text(toast.title,fontSize=16.sp,color=ink,maxLines=1,overflow=TextOverflow.Ellipsis)
                            Text(toast.description,fontSize=11.sp,color=ink.copy(alpha=.6f),maxLines=1,overflow=TextOverflow.Ellipsis)
                        }
                    }
                }
            }
        }
    }
}
