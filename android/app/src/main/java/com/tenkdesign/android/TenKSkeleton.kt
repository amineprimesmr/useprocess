package com.tenkdesign.android

import android.content.Context
import android.graphics.BlendMode
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.SystemClock
import android.view.View
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

/** Shape skeleton primitive from SkeletonView.swift. Automatic content redaction is not included. */
@Composable
fun TenKSkeleton(
    modifier:Modifier=Modifier,
    shape:Shape=RoundedCornerShape(5.dp),
    color:Color=Color.Gray.copy(alpha=.3f),
    active:Boolean=true,
    reduceMotion:Boolean=false,
) {
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    var frame by remember {mutableLongStateOf(0L)}
    var resumed by remember {mutableStateOf(false)}
    LaunchedEffect(lifecycle,active,reduceMotion) {
        if(active && !reduceMotion)lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            resumed=true
            val start=SystemClock.uptimeMillis()
            try {while(true)withFrameNanos {frame=SystemClock.uptimeMillis()-start}}
            finally {resumed=false}
        } else resumed=false
    }
    AndroidView(factory={SkeletonCanvasView(it)},modifier=modifier.clip(shape).clearAndSetSemantics {},update={view ->
        view.setFrame(color.toArgb(),frame,active && resumed && !reduceMotion)
    })
}

private class SkeletonCanvasView(context:Context):View(context) {
    private val base=Paint(Paint.ANTI_ALIAS_FLAG)
    private val shimmer=Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color=android.graphics.Color.GRAY
        if(Build.VERSION.SDK_INT>=29)blendMode=BlendMode.SOFT_LIGHT
    }
    private val bounds=RectF()
    private val band=RectF()
    private var geometry=SkeletonModel.geometry(0f)
    private var elapsed=0L
    private var moving=false
    init {setLayerType(LAYER_TYPE_SOFTWARE,null);importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO}
    fun setFrame(color:Int,time:Long,active:Boolean) {base.color=color;elapsed=time;moving=active;invalidate()}
    override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int) {
        geometry=SkeletonModel.geometry(w/resources.displayMetrics.density)
        shimmer.maskFilter=BlurMaskFilter(geometry.blurRadius*resources.displayMetrics.density,BlurMaskFilter.Blur.NORMAL)
        bounds.set(0f,0f,w.toFloat(),h.toFloat())
    }
    override fun onDraw(canvas:Canvas) {
        val layer=canvas.saveLayer(bounds,null)
        canvas.drawRect(bounds,base)
        if(moving) {
            val density=resources.displayMetrics.density
            val x=(geometry.startX+(geometry.endX-geometry.startX)*SkeletonModel.fraction(elapsed))*density
            val width=geometry.bandWidth*density
            band.set(x,-height/2f,x+width,height*1.5f)
            canvas.save();canvas.rotate(5f,x+width/2,height/2f)
            canvas.drawRect(band,shimmer);canvas.restore()
        }
        canvas.restoreToCount(layer)
    }
}
