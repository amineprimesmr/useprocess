package com.tenkdesign.android

import android.content.Context
import android.graphics.*
import android.view.View
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.*
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

/** BorderBeamEffect, Balaji Venkatesh,30April2026. Software masks retain a blur fallback on API28. */
@Composable fun TenKBorderBeam(
    modifier:Modifier=Modifier,border:Color=Color.White,beam:List<Color> = emptyList(),
    beamBlur:Dp=15.dp,cornerRadius:Dp=20.dp,hideFadeBorder:Boolean=true,
    enabled:Boolean=true,reduceMotion:Boolean=false,content:@Composable BoxScope.()->Unit,
) {
    require(beamBlur.value.isFinite()&&beamBlur>=0.dp&&cornerRadius.value.isFinite()&&cornerRadius>=0.dp)
    val phase=remember {Animatable(0f)};val lifecycle=LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(enabled,reduceMotion,lifecycle) {
        if(!enabled||reduceMotion)phase.snapTo(0f)
        else lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {while(true){phase.snapTo(0f);phase.animateTo(1f,tween(2500,easing=LinearEasing))}}
    }
    val beamArgb=remember(beam){beam.map {it.toArgb()}.toIntArray()}
    Box(modifier) {
        if(enabled)AndroidView(factory={BorderBeamView(it)},modifier=Modifier.matchParentSize(),update={it.update(border.toArgb(),beamArgb,beamBlur.value,cornerRadius.value,hideFadeBorder,phase.value)})
        content()
    }
}

private class BorderBeamView(context:Context):View(context) {
    private val basePaint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val fillPaint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val cutoutPaint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val maskPaint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect=RectF();private val expanded=RectF();private val layerBounds=RectF()
    private val rotation=Matrix()
    private val cutoutMode=PorterDuffXfermode(PorterDuff.Mode.DST_OUT)
    private val maskMode=PorterDuffXfermode(PorterDuff.Mode.DST_IN)
    private var sweep:SweepGradient?=null
    private var border=android.graphics.Color.WHITE
    private var colors=intArrayOf()
    private var blur=15f;private var radius=20f;private var drawRadius=20f
    private var hideFade=true;private var phase=0f
    init {setLayerType(LAYER_TYPE_SOFTWARE,null);importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO}
    fun update(border:Int,colors:IntArray,blur:Float,radius:Float,hideFade:Boolean,phase:Float) {
        val density=resources.displayMetrics.density
        val pxBlur=blur*density;val pxRadius=radius*density
        val changed=this.border!=border||!this.colors.contentEquals(colors)||this.blur!=pxBlur||this.radius!=pxRadius
        this.border=border;this.colors=colors;this.blur=pxBlur;this.radius=pxRadius;this.hideFade=hideFade;this.phase=phase
        if(changed||sweep==null)rebuild()
        invalidate()
    }
    override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int){super.onSizeChanged(w,h,oldw,oldh);rebuild()}
    /** Geometry,shaders,masks and blend modes change only with style/size,never every frame. */
    private fun rebuild() {
        if(width<=0||height<=0)return
        val density=resources.displayMetrics.density;val inset=.5f*density
        rect.set(inset,inset,width-inset,height-inset)
        expanded.set(rect);expanded.inset(-blur*2,-blur*2)
        layerBounds.set(-blur*2,-blur*2,width+blur*2,height+blur*2)
        drawRadius=radius.coerceAtMost(minOf(rect.width(),rect.height())/2)
        val transparent=border and 0x00ffffff
        sweep=SweepGradient(width/2f,height/2f,intArrayOf(transparent,transparent,border,transparent,transparent),floatArrayOf(0f,140f/360f,205f/360f,270f/360f,1f))
        basePaint.color=border;basePaint.alpha=(android.graphics.Color.alpha(border)*.3f).toInt();basePaint.style=Paint.Style.STROKE;basePaint.strokeWidth=.6f*density
        strokePaint.style=Paint.Style.STROKE;strokePaint.strokeWidth=.6f*density;strokePaint.shader=sweep
        if(colors.isNotEmpty()) {
            val shades=if(colors.size==1)intArrayOf(colors[0],colors[0])else colors
            fillPaint.shader=LinearGradient(0f,0f,width.toFloat(),height.toFloat(),shades,null,Shader.TileMode.CLAMP)
        }else fillPaint.shader=null
        cutoutPaint.color=android.graphics.Color.BLACK;cutoutPaint.maskFilter=if(blur>0f)BlurMaskFilter(blur,BlurMaskFilter.Blur.NORMAL)else null;cutoutPaint.xfermode=cutoutMode
        maskPaint.shader=sweep;maskPaint.maskFilter=if(blur>0f)BlurMaskFilter(blur/1.5f,BlurMaskFilter.Blur.NORMAL)else null;maskPaint.xfermode=maskMode
    }
    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        if(width<=0||height<=0||sweep==null)return
        rotation.setRotate(phase*360,width/2f,height/2f);sweep?.setLocalMatrix(rotation)
        if(!hideFade)canvas.drawRoundRect(rect,drawRadius,drawRadius,basePaint)
        if(colors.isNotEmpty()&&blur>0f) {
            val layer=canvas.saveLayer(layerBounds,null)
            canvas.drawRoundRect(rect,drawRadius,drawRadius,fillPaint)
            canvas.drawRoundRect(rect,drawRadius,drawRadius,cutoutPaint)
            canvas.drawRoundRect(expanded,drawRadius,drawRadius,maskPaint)
            canvas.restoreToCount(layer)
        }
        canvas.drawRoundRect(rect,drawRadius,drawRadius,strokePaint)
    }
}
