package com.process.android

import android.os.Build
import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.graphics.Shader
import androidx.annotation.RequiresApi
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.nestedscroll.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*
import kotlin.math.*

/** Original GooeyRefreshable by Balaji Venkatesh,11July2026. Host owns the actual refresh. */
@Composable fun TenKGooeyRefresh(
 onRefresh:suspend ()->Unit,modifier:Modifier=Modifier,contextKey:Any="default",enabled:Boolean=true,isActive:Boolean=true,
 reduceMotion:Boolean=false,refreshLabel:String="Refresh",onFailure:(Throwable)->Unit={},content:@Composable BoxScope.()->Unit
) {
 val action by rememberUpdatedState(onRefresh);val failed by rememberUpdatedState(onFailure)
 val lifecycle=LocalLifecycleOwner.current.lifecycle
 val stage by lifecycle.currentStateFlow.collectAsState()
 val active=enabled&&isActive&&stage.isAtLeast(Lifecycle.State.RESUMED)
 key(contextKey) {
  val density=LocalDensity.current;val scope=rememberCoroutineScope()
  var pull by remember{mutableFloatStateOf(0f)};var busy by remember{mutableStateOf(false)};var job by remember{mutableStateOf<Job?>(null)}
  val latestActive by rememberUpdatedState(active)
  suspend fun closeIndicator() {
   if(reduceMotion)pull=0f else animate(pull,0f,animationSpec=tween(200)){value,_->pull=value}
  }
  fun refresh() {
   if(busy||!latestActive)return
   busy=true;pull=GooeyRefreshGeometry.threshold
   job?.cancel();job=scope.launch {
    try {action();currentCoroutineContext().ensureActive()}
    catch(e:CancellationException){throw e}
    catch(t:Exception){if(latestActive)failed(t)}
    finally {busy=false;if(currentCoroutineContext().isActive)closeIndicator()else pull=0f}
   }
  }
  LaunchedEffect(active){if(!active){job?.cancel();job=null;busy=false;pull=0f}}
  val connection=remember(density,scope) {object:NestedScrollConnection {
   override fun onPreScroll(available:Offset,source:NestedScrollSource):Offset {
    if(!latestActive||busy||source!=NestedScrollSource.UserInput||available.y>=0f||pull<=0f)return Offset.Zero
    val old=pull;pull=(pull+available.y/density.density).coerceAtLeast(0f)
    return Offset(0f,(pull-old)*density.density)
   }
   override fun onPostScroll(consumed:Offset,available:Offset,source:NestedScrollSource):Offset {
    if(!latestActive||busy||source!=NestedScrollSource.UserInput||available.y<=0f)return Offset.Zero
    job?.cancel();pull=(pull+available.y/density.density*.5f).coerceAtMost(96f)
    return Offset(0f,available.y)
   }
   override suspend fun onPreFling(available:Velocity):Velocity {
    if(!latestActive||busy||pull<=0f)return Velocity.Zero
    if(pull>=GooeyRefreshGeometry.threshold)refresh()else {job?.cancel();job=scope.launch{closeIndicator()}}
    return Velocity(0f,available.y)
   }
  }}
  Box(modifier.nestedScroll(connection).semantics {
   customActions=listOf(CustomAccessibilityAction(refreshLabel){if(latestActive&&!busy){refresh();true}else false})
  }) {
   content()
   val progress=GooeyRefreshGeometry.progress(pull)
   if(progress>0f&&active)GooeyRefreshIndicator(progress,busy,reduceMotion,refreshLabel,Modifier.align(Alignment.TopCenter))
  }
 }
}
@Composable private fun GooeyRefreshIndicator(progress:Float,busy:Boolean,reduceMotion:Boolean,label:String,modifier:Modifier) {
 val density=LocalDensity.current;val hardware=LocalView.current.isHardwareAccelerated
 val effect=remember(GooeyRefreshGeometry.blur(progress),density,hardware) {if(Build.VERSION.SDK_INT>=33&&hardware&&progress<1f)GooeyThreshold.effect(GooeyRefreshGeometry.blur(progress)*density.density)else null}
 var rotation by remember{mutableFloatStateOf(0f)}
 LaunchedEffect(busy,reduceMotion){if(busy&&!reduceMotion){var start=0L;while(isActive)withFrameNanos{time->if(start==0L)start=time;rotation=((time-start)%1_000_000_000L)/1_000_000_000f*360f}}else rotation=0f}
 Box(modifier.size(140.dp,110.dp).semantics {contentDescription=label;if(busy)progressBarRangeInfo=ProgressBarRangeInfo.Indeterminate}) {
  Canvas(Modifier.fillMaxSize().graphicsLayer {renderEffect=effect}) {
   val x=size.width/2;val y=(33+60*progress).dp.toPx();val radius=GooeyRefreshGeometry.indicatorSize(progress).dp.toPx()/2
   drawRoundRect(Color.Black,Offset(x-50.dp.toPx(),0f),Size(100.dp.toPx(),33.dp.toPx()),CornerRadius(16.5.dp.toPx()))
   if(effect==null&&progress<1f) {
    // Explicit software/older-API geometry fallback; not proof of the threshold shader.
    val neck=(1-progress)*16.dp.toPx()
    val bridge=Path().apply{moveTo(x-30.dp.toPx(),25.dp.toPx());cubicTo(x-neck,40.dp.toPx(),x-neck,y-radius,x-radius*.6f,y);lineTo(x+radius*.6f,y);cubicTo(x+neck,y-radius,x+neck,40.dp.toPx(),x+30.dp.toPx(),25.dp.toPx());close()}
    drawPath(bridge,Color.Black)
   }
   drawCircle(Color.Black,radius,Offset(x,y))
  }
  Canvas(Modifier.fillMaxSize()) {
   val x=size.width/2;val y=(33+60*progress).dp.toPx();val alpha=GooeyRefreshGeometry.spinnerOpacity(progress)
   repeat(12){i->val angle=Math.toRadians((i*30f+rotation).toDouble());val inner=7.dp.toPx();val outer=11.dp.toPx()
    drawLine(Color.White.copy(alpha=alpha*(.25f+.75f*i/11f)),Offset(x+cos(angle).toFloat()*inner,y+sin(angle).toFloat()*inner),Offset(x+cos(angle).toFloat()*outer,y+sin(angle).toFloat()*outer),2.dp.toPx(),StrokeCap.Round)
   }
  }
 }
}
@RequiresApi(33) private object GooeyThreshold {
 private val threshold by lazy {
  val shader=RuntimeShader("""uniform shader content; half4 main(float2 p) {half4 c=content.eval(p);half a=smoothstep(0.48,0.52,c.a);return half4(0.0,0.0,0.0,a);}""")
  RenderEffect.createRuntimeShaderEffect(shader,"content")
 }
 fun effect(blur:Float):androidx.compose.ui.graphics.RenderEffect {
  val effect=if(blur>.01f)RenderEffect.createChainEffect(threshold,RenderEffect.createBlurEffect(blur,blur,Shader.TileMode.DECAL))else threshold
  return effect.asComposeRenderEffect()
 }
}
