package com.tenkdesign.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*

/** Original design by Balaji Venkatesh; native Compose adaptation, visual parity pending. */
data class TypewriterConfig(
    val typingDuration:Double=.8,val dismissDuration:Double=.4,val textWaitDelay:Double=1.1,
    val nextContentDelay:Double=.4,val initialDelay:Double=.8,val typingPause:Double=1.0,
    val dismissPause:Double=0.0,val fade:Boolean=false,val fontSize:TextUnit=25.sp,
    val indicatorWidth:Dp=20.dp,val indicatorHeight:Dp=2.5.dp
)

@Composable
fun TenKTypewriter(texts:List<String>,modifier:Modifier=Modifier,config:TypewriterConfig=TypewriterConfig()) {
    if(texts.isEmpty()) return
    require(config.typingDuration>0 && config.dismissDuration>0 && config.textWaitDelay>=0 && config.nextContentDelay>=0 && config.initialDelay>=0)
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    val haptics=LocalHapticFeedback.current
    var seconds by remember { mutableDoubleStateOf(-config.initialDelay) }
    LaunchedEffect(lifecycle,texts,config) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            seconds=-config.initialDelay
            val start=withFrameNanos { it }
            while(isActive) withFrameNanos { seconds=(it-start)/1_000_000_000.0-config.initialDelay }
        }
    }
    val duration=config.typingDuration+config.textWaitDelay+config.dismissDuration+config.nextContentDelay
    val index=if(seconds<0) 0 else (seconds/duration).toLong().mod(texts.size)
    val phase=if(seconds<0) -1.0 else seconds%duration
    val text=texts[index]
    val graphemes=remember(text) { Regex("\\X").findAll(text).map { it.value }.toList() }
    val progress=when {
        phase<0->0f
        phase<config.typingDuration->TypewriterTiming.progress(phase,config.typingDuration,graphemes.size,config.typingPause)
        phase<config.typingDuration+config.textWaitDelay->1f
        else->1f-TypewriterTiming.progress(phase-config.typingDuration-config.textWaitDelay,config.dismissDuration,graphemes.size,config.dismissPause)
    }
    val color=MaterialTheme.colorScheme.onSurface
    val styled=buildAnnotatedString {
        graphemes.forEachIndexed { i,g -> withStyle(SpanStyle(color=color.copy(alpha=TypewriterTiming.opacity(progress,i,graphemes.size,config.fade)))) { append(g) } }
    }
    var textWidth by remember(text) { mutableFloatStateOf(0f) }
    val revealed=(progress*graphemes.size).toInt()
    LaunchedEffect(index,revealed) { if(phase>=0 && revealed>0) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
    Row(modifier,verticalAlignment=androidx.compose.ui.Alignment.Bottom) {
        Text(styled,fontSize=config.fontSize,fontWeight=FontWeight.Bold,maxLines=1,
            onTextLayout={textWidth=it.size.width.toFloat()},
            modifier=Modifier.graphicsLayer { translationX=textWidth*(1-progress)*.5f })
        Box(Modifier.graphicsLayer { translationX=-textWidth*(1-progress)*.5f }.size(config.indicatorWidth,config.indicatorHeight).alpha(TypewriterTiming.indicator(seconds+config.initialDelay)).background(color))
    }
}
