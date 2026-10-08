package com.tenkdesign.android

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** WaveformScrubber by Balaji Venkatesh, 22 March 2025. Caller owns playback and seeking. */
data class WaveformConfig(
    val spacing:Dp=2.dp,val shapeWidth:Dp=2.dp,
    val activeTint:Color=Color.Black,val inactiveTint:Color=Color.Gray.copy(alpha=.7f),
)

/** Reads only an explicitly supplied local URI; never requests recording or starts playback. */
suspend fun loadLocalWaveform(context:Context,uri:Uri):WaveformAudio=withContext(Dispatchers.IO) {
    require(uri.scheme in listOf("content","file","android.resource")) {"Use a local audio URI"}
    val bytes=context.contentResolver.openInputStream(uri)?.use {input ->
        val output=java.io.ByteArrayOutputStream();val buffer=ByteArray(16*1024)
        while(true) {val count=input.read(buffer);if(count<0)break;require(output.size()+count<=WaveformWavReader.MAX_BYTES){"Audio exceeds 64 MiB"};output.write(buffer,0,count)}
        output.toByteArray()
    }?:error("Audio cannot be opened")
    WaveformWavReader.decode(bytes)
}

@Composable fun TenKWaveformScrubber(
    samples:FloatArray,progress:Float,onProgressChange:(Float)->Unit,
    modifier:Modifier=Modifier,config:WaveformConfig=WaveformConfig(),
    onGestureActive:(Boolean)->Unit={},accessibilityLabel:String="Audio position",
) {
    require(config.shapeWidth.value.isFinite()&&config.shapeWidth>0.dp&&config.spacing.value.isFinite()&&config.spacing>=0.dp)
    var widthPx by remember {mutableIntStateOf(0)}
    var gestureActive by remember {mutableStateOf(false)}
    val latestProgress by rememberUpdatedState(WaveformModel.progress(progress))
    val latestChange by rememberUpdatedState(onProgressChange)
    val latestGesture by rememberUpdatedState(onGestureActive)
    val density=LocalDensity.current
    val slot=with(density){(config.spacing+config.shapeWidth).toPx()}
    val count=(widthPx/slot).toInt().coerceIn(0,100_000)
    val peaks=remember(samples,count){WaveformModel.downsample(samples,count)}
    DisposableEffect(Unit) {onDispose {if(gestureActive)latestGesture(false)}}
    Canvas(modifier.height(60.dp).fillMaxWidth().onSizeChanged {widthPx=it.width}.semantics {
        contentDescription=accessibilityLabel
        progressBarRangeInfo=ProgressBarRangeInfo(latestProgress,0f..1f)
        setProgress {latestChange(WaveformModel.progress(it));true}
    }.pointerInput(widthPx) {
        var start=0f;var translation=0f
        fun finish(){if(gestureActive){gestureActive=false;latestGesture(false)}}
        try {
            detectHorizontalDragGestures(
                onDragStart={start=latestProgress;translation=0f;gestureActive=true;latestGesture(true)},
                onDragCancel={finish()},onDragEnd={finish()},
                onHorizontalDrag={change,amount->change.consume();translation+=amount;if(widthPx>0)latestChange(WaveformModel.progress(start+translation/widthPx))},
            )
        } finally {finish()}
    }) {
        val barWidth=config.shapeWidth.toPx()
        fun bars(color:Color) {peaks.forEachIndexed {index,sample ->
            val height=(sample*size.height).coerceAtLeast(1.dp.toPx())
            drawRect(color,Offset(index*slot+barWidth,(size.height-height)/2),Size(barWidth,height))
        }}
        bars(config.inactiveTint)
        clipRect(right=size.width*latestProgress){bars(config.activeTint)}
    }
}
