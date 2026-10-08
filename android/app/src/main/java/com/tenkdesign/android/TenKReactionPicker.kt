package com.tenkdesign.android

import android.os.SystemClock
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import kotlinx.coroutines.delay
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

/** Native port of AMReactionView (Balaji Venkatesh, 22/08/26).
 * Android Popup/material/emoji rendering differ from Apple's glass/zoom and require comparison.
 */
@Composable
fun TenKReactionPicker(
    reactions: List<String>,
    selection: String?,
    onSelection: (String) -> Unit,
    modifier: Modifier = Modifier,
    forcePopover: Boolean = false,
    addsInsertButton: Boolean = false,
    reduceMotion: Boolean = false,
    pickerDescription: String = "Choose a reaction",
    insertDescription: String = "Insert reaction",
    reactionDescription: (String) -> String = { it },
    onInsertTapped: () -> Unit = {},
) {
    var expanded by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    val lifecycle = LocalLifecycleOwner.current
    val gap = with(LocalDensity.current) { 10.dp.roundToPx() }
    val popupPosition = remember(gap) { object : PopupPositionProvider {
        override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize): IntOffset {
            val x = (anchorBounds.left + (anchorBounds.width - popupContentSize.width) / 2)
                .coerceIn(0, (windowSize.width-popupContentSize.width).coerceAtLeast(0))
            val above = anchorBounds.top-popupContentSize.height-gap
            val y = (if (above >= 0) above else anchorBounds.bottom+gap)
                .coerceIn(0,(windowSize.height-popupContentSize.height).coerceAtLeast(0))
            return IntOffset(x,y)
        }
    } }
    var particleElapsed by remember { mutableLongStateOf(2300L) }
    var previousSelection by remember { mutableStateOf(selection) }
    LaunchedEffect(selection, reduceMotion) {
        if (selection != previousSelection) {
            previousSelection = selection
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            particleElapsed = if (reduceMotion || selection == null) 2300L else 0L
            if (particleElapsed == 0L) {
                val start = SystemClock.uptimeMillis()
                lifecycle.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                    while (particleElapsed < 2300L) withFrameNanos { particleElapsed = SystemClock.uptimeMillis() - start }
                }
            }
        }
    }
    Box(modifier, contentAlignment = Alignment.Center) {
        Box(Modifier.size(45.dp).shadow(2.dp,CircleShape).background(MaterialTheme.colorScheme.surfaceContainer,CircleShape)
            .clickable(role=Role.Button) { expanded = true; haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
            .semantics { contentDescription = pickerDescription + (selection?.let { ": ${reactionDescription(it)}" } ?: "") },
            contentAlignment=Alignment.Center) {
            AnimatedContent(selection ?: "☺", transitionSpec={fadeIn(tween(if(reduceMotion)0 else 300)) togetherWith fadeOut(tween(if(reduceMotion)0 else 300))}, label="selectedReaction") { Text(it,fontSize=20.sp) }
        }
        if (!reduceMotion && particleElapsed < 2300L && selection != null) repeat(5) { index ->
            val particle = ReactionPickerModel.particle(index,particleElapsed,22.5f)
            Text(selection,fontSize=22.5.sp,modifier=Modifier.graphicsLayer {
                alpha=particle.opacity; scaleX=particle.scale;scaleY=particle.scale
                translationX=particle.x.dp.toPx();translationY=particle.y.dp.toPx()
                transformOrigin=TransformOrigin(.5f,1f)
            })
        }
        if (expanded) Popup(popupPositionProvider=popupPosition, onDismissRequest={expanded=false}, properties=PopupProperties(focusable=true)) {
            val limited=ReactionPickerModel.limited(reactions,addsInsertButton)
            Row(Modifier.widthIn(max=370.dp).shadow(6.dp,CircleShape)
                .background(MaterialTheme.colorScheme.surfaceContainer,CircleShape).horizontalScroll(rememberScrollState()).padding(horizontal=5.dp)) {
                limited.forEachIndexed { index,reaction ->
                    ReactionOption(reaction,index,forcePopover,reduceMotion,reactionDescription(reaction),selection==reaction) {
                        onSelection(reaction);expanded=false
                    }
                }
                if(addsInsertButton) ReactionOption("⊕",limited.size,forcePopover,reduceMotion,insertDescription,false) {
                    onInsertTapped();expanded=false
                }
            }
        }
    }
}

@Composable
private fun ReactionOption(text:String,index:Int,forcePopover:Boolean,reduceMotion:Boolean,description:String,isSelected:Boolean,onClick:()->Unit) {
    var visible by remember { mutableStateOf(reduceMotion) }
    LaunchedEffect(index,forcePopover,reduceMotion) { if(!reduceMotion)delay(ReactionPickerModel.revealMillis(index,forcePopover));visible=true }
    val spec=if(reduceMotion)tween<Float>(0) else spring(dampingRatio=.4f,stiffness=246.7401f)
    val scale by animateFloatAsState(if(visible)1f else .01f,spec,label="reactionScale")
    val angle by animateFloatAsState(if(visible)0f else if(forcePopover)5f else 25f,spec,label="reactionAngle")
    Box(Modifier.size(60.dp,45.dp).clickable(enabled=visible,role=Role.Button,onClick=onClick)
        .semantics {contentDescription=description;selected=isSelected},contentAlignment=Alignment.Center) {
        Text(text,fontSize=26.sp,modifier=Modifier.graphicsLayer {scaleX=scale;scaleY=scale;rotationZ=angle;transformOrigin=TransformOrigin(0f,.5f)})
    }
}
