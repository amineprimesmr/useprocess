package com.process.android

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalAccessibilityManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Stable
class ProcessToastState {
    var message by mutableStateOf<ProcessToastMessage?>(null)
        private set
    fun show(message:ProcessToastMessage) {this.message=message}
    fun dismiss(id:String?=message?.id) {if(id!=null && ProcessToastTimeline.canDismiss(message?.id,id))message=null}
}

@Composable fun rememberProcessToastState()=remember {ProcessToastState()}

/** Mount last in the activity's full-screen Box. No system-overlay permission is used.
 * Android adapts the original legacy layout beneath the status inset, without faking a hardware island.
 */
@Composable
fun ProcessToastHost(
    state:ProcessToastState,
    modifier:Modifier=Modifier,
    onTap:(ProcessToastMessage)->Unit={},
    dismissDescription:String="Dismiss notification",
    symbol:@Composable ()->Unit={ProcessStreakFlame(height=32.dp,active=false,dark=true,timeSeconds=0.0)},
) {
    val current=state.message
    var rendered by remember {mutableStateOf<ProcessToastMessage?>(null)}
    var counterTarget by remember {mutableIntStateOf(0)}
    var progressTarget by remember {mutableFloatStateOf(0f)}
    val reduced=rememberProcessReducedMotion()
    val haptic=LocalHapticFeedback.current
    val accessibility=LocalAccessibilityManager.current
    val currentOnTap by rememberUpdatedState(onTap)
    LaunchedEffect(current?.id) {
        if(current!=null) {
            rendered=current
            counterTarget=current.streakBefore ?: current.streakAfter ?: 0
            progressTarget=0f
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            val timeout=accessibility?.calculateRecommendedTimeoutMillis(ProcessToastTimeline.DISMISS_MILLIS,containsIcons=true,containsText=true,containsControls=true) ?: ProcessToastTimeline.DISMISS_MILLIS
            delay(if(reduced)0 else ProcessToastTimeline.COUNTER_DELAY)
            counterTarget=current.streakAfter ?: 0
            if(!reduced)haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            delay(if(reduced)0 else ProcessToastTimeline.PROGRESS_DELAY-ProcessToastTimeline.COUNTER_DELAY)
            progressTarget=current.streakProgress?.coerceIn(0f,1f) ?: 0f
            delay((timeout-(if(reduced)0 else ProcessToastTimeline.PROGRESS_DELAY)).coerceAtLeast(0))
            state.dismiss(current.id)
        }
    }
    val count by animateIntAsState(counterTarget,if(reduced)tween(0)else spring(.8f,194.955f),label="toastCounter")
    val progress by animateFloatAsState(progressTarget,if(reduced)tween(0)else spring(.85f,157.914f),label="toastProgress")
    // Immediately remove the full-screen input layer when dismissed. Exit animation cannot trap taps.
    Box(modifier.fillMaxSize()) {
        if(current!=null) Box(Modifier.fillMaxSize().clickable(interactionSource=remember{MutableInteractionSource()},indication=null,onClick={state.dismiss(current.id)}).clearAndSetSemantics {})
        AnimatedVisibility(current!=null,modifier=Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(horizontal=10.dp,vertical=10.dp),
            enter=slideInVertically(tween(if(reduced)0 else 300)){-it}+fadeIn(tween(if(reduced)0 else 300)),
            exit=slideOutVertically(tween(if(reduced)0 else 300)){-it}+fadeOut(tween(if(reduced)0 else 300))) {
            rendered?.let {message ->
                Row(Modifier.fillMaxWidth().heightIn(min=112.dp).clip(RoundedCornerShape(18.dp)).background(Color.Black)
                    .border(.75.dp,Color.White.copy(alpha=.22f),RoundedCornerShape(18.dp))
                    .clickable(enabled=current?.id==message.id,role=Role.Button) {try {currentOnTap(message)} finally {state.dismiss(message.id)}}
                    .pointerInput(message.id) {
                        var dy=0f
                        detectVerticalDragGestures(onDragStart={dy=0f},onVerticalDrag={change,delta->dy+=delta;change.consume()},onDragEnd={if(dy<0)state.dismiss(message.id)})
                    }.semantics(mergeDescendants=true) {liveRegion=LiveRegionMode.Polite;customActions=listOf(CustomAccessibilityAction(dismissDescription){state.dismiss(message.id);true})}
                    .padding(horizontal=22.dp,vertical=10.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.width(46.dp),contentAlignment=Alignment.Center) {symbol()}
                    Column(Modifier.weight(1f).padding(bottom=8.dp),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                        Row(verticalAlignment=Alignment.CenterVertically) {
                            Text(message.title,fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=Color.White,modifier=Modifier.weight(1f))
                            if(message.streakAfter!=null) Text(count.toString(),fontSize=20.sp,fontWeight=FontWeight.Bold,color=Color(.34f,.72f,1f))
                        }
                        Text(message.text,fontSize=15.sp,color=Color.White.copy(alpha=.72f))
                        if(message.streakProgress!=null) Box(Modifier.padding(top=2.dp).fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(alpha=.14f))) {
                            Box(Modifier.fillMaxWidth(progress.coerceIn(0f,1f)).fillMaxHeight().background(Color(.34f,.72f,1f)))
                        }
                    }
                }
            }
        }
    }
}
