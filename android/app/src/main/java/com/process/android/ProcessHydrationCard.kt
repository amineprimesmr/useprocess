package com.process.android

import android.content.Context
import android.hardware.*
import android.media.MediaPlayer
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.graphics.nativeCanvas
import android.graphics.Paint
import android.graphics.Typeface
import java.text.NumberFormat
import androidx.compose.ui.platform.*
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*

@Composable
fun ProcessHydrationCard(milliliters: Int, onChange: (Int)->Unit, modifier: Modifier=Modifier, targetMilliliters: Int=2000) {
    val context=LocalContext.current
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    val haptics=LocalHapticFeedback.current
    val motion=remember { WaterMotion() }
    var roll by remember { mutableFloatStateOf(0f) }
    var pitch by remember { mutableFloatStateOf(0f) }
    var phase by remember { mutableFloatStateOf(0f) }
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    val dark=isSystemInDarkTheme()
    val watermark=NumberFormat.getNumberInstance().apply { maximumFractionDigits=1 }.format(targetMilliliters.coerceAtLeast(1)/1000.0)+"L"
    val fill by animateFloatAsState(HydrationGeometry.fill(milliliters,targetMilliliters),spring(.74f,HydrationGeometry.stiffness(.92f)),label="water.fill")
    val bottleScale=remember { Animatable(1f) }
    val plusScale=remember { Animatable(1f) }
    var previous by remember { mutableIntStateOf(milliliters) }
    LaunchedEffect(milliliters) {
        if(milliliters>previous) {
            motion.pour(); phase=motion.phase
            coroutineScope {
                launch { bottleScale.animateTo(1.07f,spring(.48f,HydrationGeometry.stiffness(.32f))); bottleScale.animateTo(1f,spring(.74f,HydrationGeometry.stiffness(.64f))) }
                launch { plusScale.animateTo(1.18f,spring(.48f,HydrationGeometry.stiffness(.32f))); plusScale.animateTo(1f,spring(.74f,HydrationGeometry.stiffness(.64f))) }
            }
        }
        previous=milliliters
    }
    DisposableEffect(context,lifecycle) {
        val manager=context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor=manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        val listener=object:SensorEventListener {
            override fun onAccuracyChanged(sensor:Sensor?,accuracy:Int) {}
            override fun onSensorChanged(event:SensorEvent) {
                // Android +Y points to the top of the screen; match iOS gravity signs.
                val g=SensorManager.GRAVITY_EARTH
                motion.gravity(-event.values[0]/g,-event.values[1]/g,-event.values[2]/g)
                roll=motion.roll; pitch=motion.pitch; phase=motion.phase
            }
        }
        fun start() { if(sensor!=null) manager.registerListener(listener,sensor,50_000) }
        fun stop() { manager.unregisterListener(listener); motion.reset(); roll=0f; pitch=0f; phase=0f; player?.release(); player=null }
        val observer=LifecycleEventObserver { _,event ->
            when(event) { Lifecycle.Event.ON_RESUME -> start(); Lifecycle.Event.ON_PAUSE -> stop(); else -> Unit }
        }
        lifecycle.addObserver(observer)
        if(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) start()
        onDispose { lifecycle.removeObserver(observer); stop() }
    }
    Row(modifier.height(248.dp).padding(start=26.dp,end=4.dp),horizontalArrangement=Arrangement.spacedBy(8.dp)) {
        Box(Modifier.width((248*.315f).dp).height(248.dp).clipToBounds().scale(bottleScale.value).semantics {
            contentDescription="Gourde"; stateDescription="$milliliters sur $targetMilliliters millilitres"
        }) {
            Box(Modifier.requiredSize(248.dp).align(Alignment.Center)) {
                Image(painterResource(R.drawable.hydration_bottle),null,Modifier.fillMaxSize())
                Canvas(Modifier.fillMaxSize()) {
                    val scale=size.width/248f
                    scale(scale,scale,pivot=Offset.Zero) {
                        val left=248f*.348f; val right=248f*.652f; val top=248f*.238f; val bottom=248f*.978f
                        val radius=(right-left)*.24f
                        val mask=Path().apply { addRoundRect(RoundRect(Rect(left,top,right,bottom),CornerRadius(radius))) }
                        val points=HydrationGeometry.surface(fill,roll,pitch,phase)
                        val water=Path().apply {
                            moveTo(left+radius,bottom); lineTo(right-radius,bottom)
                            quadraticTo(right,bottom,right,bottom-radius); lineTo(right,points.last().y)
                            points.asReversed().forEachIndexed { i,p ->
                                if(i==0) lineTo(p.x,p.y) else { val next=points[points.size-i]; quadraticTo((p.x+next.x)/2,(p.y+next.y)/2,p.x,p.y) }
                            }
                            lineTo(left,points.first().y); quadraticTo(left,bottom,left+radius,bottom); close()
                        }
                        clipPath(mask) {
                            drawContext.canvas.nativeCanvas.drawText(watermark,124f,136.4f,Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                color=android.graphics.Color.WHITE; alpha=if(dark) 122 else 199
                                textSize=52f; textAlign=Paint.Align.CENTER
                                typeface=Typeface.create("sans-serif-rounded",Typeface.BOLD)
                            })
                            drawPath(water,Brush.verticalGradient(0f to Color(.55f,.97f,1f,.28f),.22f to Color(.05f,.82f,1f,.38f),.55f to Color(0f,.48f,1f,.52f),.82f to Color(0f,.22f,.88f,.62f),1f to Color(0f,.10f,.62f,.72f),startY=0f,endY=248f))
                        }
                    }
                }
            }
        }
        Box(Modifier.padding(top=(248*.238f-4).dp)) {
            IconButton(onClick={
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                player?.release(); player=MediaPlayer.create(context,R.raw.pouring_water)?.apply { setOnCompletionListener { it.release(); if(player===it) player=null }; start() }
                onChange((milliliters.coerceAtLeast(0).toLong()+500).coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
            },modifier=Modifier.size(36.dp).scale(plusScale.value).background(MaterialTheme.colorScheme.surface.copy(alpha=.65f),CircleShape).semantics { contentDescription="Ajouter 500 millilitres d’eau" }) {
                Image(painterResource(R.drawable.hydration_drop),null,Modifier.size(22.dp))
            }
        }
    }
}
