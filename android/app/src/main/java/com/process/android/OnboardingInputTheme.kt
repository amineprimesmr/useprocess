package com.process.android

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.delay

internal data class InputPalette(val dark: Boolean) {
    val background = if (dark) Color.Black else Color(.968f, .972f, .988f)
    val primary = if (dark) Color.White else Color.Black
    val muted = primary.copy(alpha = if (dark) .52f else .68f)
    val body = primary.copy(alpha = if (dark) .78f else .88f)
    val track = if (dark) Color(18,18,20) else Color(229,229,234)
    val selected = if (dark) Color(35,35,37) else Color.White
}

/** Host passes content in full-screen coordinates; source content offset = 150 + 60 dp. */
@Composable internal fun InputUnitToggle(left: String, right: String, isLeft: Boolean, onChange: (Boolean)->Unit, palette: InputPalette) {
    val haptics = LocalHapticFeedback.current
    Row(Modifier.fillMaxWidth().padding(horizontal=40.dp).height(56.dp).clip(RoundedCornerShape(28.dp))
        .background(palette.track).padding(4.dp).selectableGroup(),horizontalArrangement=Arrangement.spacedBy(4.dp)) {
        listOf(left to true, right to false).forEach { (label, value) ->
            val fill by animateColorAsState(if(isLeft==value)palette.selected else Color.Transparent,spring(.7f,438.65f),label="onboarding.unit")
            Box(Modifier.weight(1f).height(48.dp).clip(RoundedCornerShape(24.dp)).background(fill)
                .selectable(selected=isLeft==value,role=Role.RadioButton,onClick={onChange(value);haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}),contentAlignment=Alignment.Center) {
                Text(label,fontSize=18.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
            }
        }
    }
}

@Composable internal fun InputKeyboardLifecycle(requester: FocusRequester, delayMs: Long, autoFocus: Boolean) {
    val owner=LocalLifecycleOwner.current
    val manager=LocalFocusManager.current
    LaunchedEffect(owner, autoFocus) {
        if(autoFocus) { delay(delayMs); if(owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) requester.requestFocus() }
    }
    DisposableEffect(owner,manager) {
        val observer=LifecycleEventObserver { _,event -> if(event==Lifecycle.Event.ON_PAUSE) manager.clearFocus() }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer);manager.clearFocus() }
    }
}
