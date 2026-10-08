package com.process.android

import android.media.MediaPlayer
import androidx.compose.runtime.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.delay

@Composable internal fun rememberSettingsFeedback(soundEnabled:Boolean):()->Unit {
    val context=LocalContext.current;val haptic=LocalHapticFeedback.current;val lifecycle=LocalLifecycleOwner.current.lifecycle
    var consumedGeneration by remember {mutableIntStateOf(0)}
    var generation by remember {mutableIntStateOf(0)};var started by remember {mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))}
    DisposableEffect(lifecycle) {
        val observer=LifecycleEventObserver {_,_->started=lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)}
        lifecycle.addObserver(observer);onDispose {lifecycle.removeObserver(observer)}
    }
    LaunchedEffect(generation,soundEnabled,started) {
        if(generation==0||generation==consumedGeneration)return@LaunchedEffect
        consumedGeneration=generation
        if(!soundEnabled||!started)return@LaunchedEffect
        val player=runCatching {MediaPlayer.create(context,R.raw.referral_copy)}.getOrNull()?:return@LaunchedEffect
        try {
            player.start();delay(280)
            repeat(8){index->val volume=1f-(index+1)/8f;player.setVolume(volume,volume);delay(((index+1)*140/8-index*140/8).toLong())}
        } finally {runCatching {player.stop()};player.release()}
    }
    return {haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove);generation++}
}
