package com.tenkdesign.android

import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.*

/** Native Canvas port of BTSlider, original source by Balaji Venkatesh, 05/09/26.
 * Clock typography/material and SF bed/alarm symbols require physical parity verification.
 */
@Composable
fun TenKSleepSlider(
    range:SleepRange,
    onChange:(SleepRange)->Unit,
    modifier:Modifier=Modifier,
    circleSize:Float=320f,
    knobSize:Float=52f,
    knobPadding:Float=15f,
    minimumProgress:Double=.1,
    selectionTint:Color=Color(.17f,.17f,.18f),
    backgroundTint:Color=Color.Black,
    knobTint:Color=Color.Gray,
    startDescription:String="Bedtime",
    endDescription:String="Wake up",
    onInteractionChange:(Boolean)->Unit={},
    centerContent:(@Composable ()->Unit)?=null,
    reduceMotion:Boolean=false,
) {
    val dimension=circleSize.coerceIn(160f,600f)
    val knob=knobSize.coerceIn(24f,dimension/3)
    val ringWidth=(knob-knobPadding).coerceIn(12f,knob)
    val radius=(dimension-knob)/2
    val current by rememberUpdatedState(range)
    val update by rememberUpdatedState(onChange)
    val interaction by rememberUpdatedState(onInteractionChange)
    val draw=remember {SleepSliderDrawing()}
    val animatedTint by animateColorAsState(selectionTint,tween(if(reduceMotion)0 else 200,easing=CubicBezierEasing(.42f,0f,.58f,1f)),label="sleepSelectionTint")
    Box(modifier.size(dimension.dp)) {
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics {}.pointerInput(dimension,knob,minimumProgress) {
            awaitEachGesture {
                val down=awaitFirstDown(requireUnconsumed=false)
                val center=Offset(size.width/2f,size.height/2f)
                val r=radius.dp.toPx()
                fun point(value:Double)=center+Offset((cos(value*2*PI-PI/2)*r).toFloat(),(sin(value*2*PI-PI/2)*r).toFloat())
                val startDistance=(down.position-point(current.start)).getDistance()
                val endDistance=(down.position-point(current.end)).getDistance()
                if(min(startDistance,endDistance)>max(ringWidth/2,22f).dp.toPx())return@awaitEachGesture
                val isStart=startDistance<endDistance
                var dragging=false
                try {
                    while(true) {
                        val event=awaitPointerEvent()
                        val change=event.changes.firstOrNull{it.id==down.id} ?: break
                        if(!change.pressed)break
                        if(!dragging && (change.position-down.position).getDistance()>=5.dp.toPx()) {dragging=true;interaction(true)}
                        if(dragging) {
                            change.consume()
                            val offset=change.position-center
                            update(SleepSliderModel.move(current,isStart,SleepSliderModel.progressAt(offset.x.toDouble(),offset.y.toDouble()),minimumProgress))
                        }
                    }
                } finally {if(dragging)interaction(false)}
            }
        }) {
            drawIntoCanvas {c -> draw.render(c.nativeCanvas,density,dimension,knob,ringWidth,current,animatedTint.toArgb(),backgroundTint.toArgb(),knobTint.toArgb(),centerContent==null)}
        }
        if(centerContent!=null) Box(Modifier.align(Alignment.Center).size((dimension-2*knob).dp).clip(CircleShape),contentAlignment=Alignment.Center) {centerContent()}
        listOf(true,false).forEach {start ->
            val value=SleepSliderModel.wrap(if(start)range.start else range.end)
            val label=if(start)startDescription else endDescription
            Box(Modifier.offset {
                IntOffset(((dimension/2+cos(value*2*PI-PI/2)*radius-22)*density).roundToInt(),((dimension/2+sin(value*2*PI-PI/2)*radius-22)*density).roundToInt())
            }.size(44.dp).semantics {
                contentDescription=label
                stateDescription=SleepSliderModel.time(value)
                progressBarRangeInfo=ProgressBarRangeInfo(value.toFloat(),0f..1f)
                setProgress {target ->update(SleepSliderModel.move(current,start,target.toDouble(),minimumProgress));true}
                customActions=listOf(
                    CustomAccessibilityAction("−15 min"){update(SleepSliderModel.move(current,start,value-15.0/1440,minimumProgress));true},
                    CustomAccessibilityAction("+15 min"){update(SleepSliderModel.move(current,start,value+15.0/1440,minimumProgress));true})
            })
        }
    }
}

/** Reused native draw objects keep dragging free of per-frame Path/Paint allocations. */
private class SleepSliderDrawing {
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val arc=Path()
    private val mask=Path()
    private val rect=RectF()
    private val normal=Typeface.create("sans-serif",Typeface.NORMAL)
    private val bold=Typeface.create("sans-serif",Typeface.BOLD)
    private fun fill(color:Int) {paint.color=color;paint.style=Paint.Style.FILL;paint.strokeWidth=0f}
    fun render(canvas:android.graphics.Canvas,density:Float,dimension:Float,knob:Float,line:Float,range:SleepRange,selection:Int,background:Int,ink:Int,drawClock:Boolean) {
        canvas.save();canvas.scale(density,density)
        val mid=dimension/2;val radius=(dimension-knob)/2
        fill(background);paint.style=Paint.Style.STROKE;paint.strokeWidth=knob;canvas.drawCircle(mid,mid,radius,paint)
        if(drawClock) {fill(0xff2c2c2e.toInt());canvas.drawCircle(mid,mid,(dimension-2*knob)/2,paint)}
        rect.set(mid-radius,mid-radius,mid+radius,mid+radius)
        arc.reset();arc.addArc(rect,(SleepSliderModel.wrap(range.start)*360-90).toFloat(),SleepSliderModel.sweep(range).toFloat())
        paint.style=Paint.Style.STROKE;paint.strokeWidth=line;paint.strokeCap=Paint.Cap.ROUND;paint.getFillPath(arc,mask)
        fill(selection);canvas.drawPath(mask,paint)
        canvas.save();canvas.clipPath(mask)
        fill(background)
        repeat((dimension/3).toInt()) {index ->
            canvas.save();canvas.rotate(index*360f/(dimension/3).toInt()-90,mid,mid)
            rect.set(mid+radius-knob/8,mid-1,mid+radius+knob/8,mid+1);canvas.drawRoundRect(rect,1f,1f,paint);canvas.restore()
        }
        canvas.restore()
        if(drawClock) {
        val clockRadius=(dimension-2*knob)/2
        fill(0xff808080.toInt())
        repeat(60) {index ->
            canvas.save();canvas.rotate(index*6f,mid,mid)
            rect.set(mid-1,mid-clockRadius+5,mid+1,mid-clockRadius+5+if(index%5==0)6 else 3);canvas.drawRoundRect(rect,1f,1f,paint);canvas.restore()
        }
        paint.textAlign=Paint.Align.CENTER
        repeat(12) {index ->
            val hour=index*2;val suffix=if(hour==0||hour==6)"AM"else if(hour==12||hour==18)"PM"else ""
            paint.textSize=if(suffix.isEmpty())12f else 14f;paint.typeface=if(suffix.isEmpty())normal else bold
            paint.color=if(suffix.isEmpty())0xff808080.toInt() else 0xffeeeeee.toInt()
            val text="${if(hour%12==0)12 else hour%12}$suffix"
            val distance=clockRadius-27;val angle=index*PI/6-PI/2
            canvas.drawText(text,(mid+cos(angle)*distance).toFloat(),(mid+sin(angle)*distance).toFloat()-(paint.ascent()+paint.descent())/2,paint)
        }
        paint.textSize=16f;paint.color=0xff5856d6.toInt();canvas.drawText("☾",mid,mid-clockRadius+56,paint)
        paint.color=0xffffcc00.toInt();canvas.drawText("☀",mid,mid+clockRadius-42,paint)
        }
        listOf(range.start to true,range.end to false).forEach {(value,start) ->
            val angle=value*2*PI-PI/2;val x=(mid+cos(angle)*radius).toFloat();val y=(mid+sin(angle)*radius).toFloat()
            fill(selection);canvas.drawCircle(x,y,line/2,paint)
            fill(ink);paint.strokeWidth=1.5f;paint.style=Paint.Style.STROKE
            // Native line symbols replace Apple-only SF Symbols; supplied layout stays source-sized.
            if(start) {
                canvas.drawLine(x-7,y-6,x-7,y+6,paint);canvas.drawLine(x+7,y-2,x+7,y+6,paint)
                rect.set(x-7,y-2,x+7,y+3);canvas.drawRect(rect,paint);canvas.drawCircle(x-3.5f,y-4,1.5f,paint)
            } else {
                canvas.drawCircle(x,y,6f,paint);canvas.drawLine(x,y,x,y-4,paint);canvas.drawLine(x,y,x+3,y,paint)
                canvas.drawLine(x-5,y-8,x-8,y-5,paint);canvas.drawLine(x+5,y-8,x+8,y-5,paint)
            }
        }
        canvas.restore()
    }
}
