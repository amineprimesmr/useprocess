package com.process.android
import android.content.Context
import android.graphics.*
import android.view.View
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.*
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

/** Original narrow angular highlight,4.8seconds,2.75dp stroke,30fps maximum; no external glow. */
@Composable fun ProcessTutorialBorder(modifier:Modifier=Modifier,cornerRadius:Dp=30.dp,active:Boolean=true,reduceMotion:Boolean=rememberProcessReducedMotion()) {
 require(cornerRadius.value.isFinite()&&cornerRadius>=0.dp)
 val lifecycle=LocalLifecycleOwner.current.lifecycle;var phase by remember {mutableFloatStateOf(0f)}
 LaunchedEffect(active,reduceMotion,lifecycle) {
  if(!active||reduceMotion)phase=0f
  else lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
   var last=0L
   while(true)withFrameNanos {time->if(time-last>=33_333_333L){phase=(time%4_800_000_000L)/4_800_000_000f;last=time}}
  }
 }
 AndroidView(factory={TutorialBorderView(it)},modifier=modifier,update={it.update(cornerRadius.value,phase)})
}
private class TutorialBorderView(context:Context):View(context) {
 private val paint=Paint(Paint.ANTI_ALIAS_FLAG);private val rect=RectF();private val matrix=Matrix()
 private var shader:SweepGradient?=null;private var radius=30f;private var phase=0f
 private val stops=floatArrayOf(0f,.42f,.46f,.49f,.50f,.505f,.51f,.54f,.58f,1f)
 private val colors=intArrayOf(Color.TRANSPARENT,Color.TRANSPARENT,Color.argb(89,199,250,255),Color.argb(235,255,255,255),Color.WHITE,Color.rgb(199,250,255),Color.argb(235,255,255,255),Color.argb(89,199,250,255),Color.TRANSPARENT,Color.TRANSPARENT)
 init {importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO}
 fun update(radius:Float,phase:Float){this.radius=radius*resources.displayMetrics.density;this.phase=phase;invalidate()}
 override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int){super.onSizeChanged(w,h,oldw,oldh);val line=2.75f*resources.displayMetrics.density;paint.style=Paint.Style.STROKE;paint.strokeWidth=line;rect.set(line/2,line/2,w-line/2,h-line/2);shader=SweepGradient(w/2f,h/2f,colors,stops);paint.shader=shader}
 override fun onDraw(canvas:Canvas){super.onDraw(canvas);matrix.setRotate(phase*360,width/2f,height/2f);shader?.setLocalMatrix(matrix);val r=(radius-paint.strokeWidth/2).coerceAtLeast(0f);canvas.drawRoundRect(rect,r,r,paint)}
}
