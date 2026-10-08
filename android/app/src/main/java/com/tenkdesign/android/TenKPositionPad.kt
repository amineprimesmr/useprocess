package com.tenkdesign.android

// Android adaptation of TenKPositionalPadSliderPhotosStylePositionPad.
// Original Swift component by Balaji Venkatesh, 27/03/26.
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp

/** Normalized host-owned x/y, no snapping of the stored value. Idle rendering snaps to the active dot. */
@Composable fun TenKPositionPad(
    position:PadPosition,onPositionChange:(PadPosition)->Unit,modifier:Modifier=Modifier,
    config:PositionPadConfig=PositionPadConfig(),tint:Color=Color.White,reduceMotion:Boolean=false,
    label:String="Position",horizontalLabel:String="Horizontal",verticalLabel:String="Vertical"
) {
    val density=LocalDensity.current.density
    val latestChange by rememberUpdatedState(onPositionChange)
    var dragging by remember {mutableStateOf(false)};var firstDrag by remember {mutableStateOf(false)}
    var localPosition by remember {mutableStateOf(PositionPadModel.clamp(position))}
    val sourceLocation=PositionPadModel.location(if(dragging)localPosition else position,config)
    val targetIndicator=PositionPadModel.indicator(sourceLocation,dragging,config)
    val spec:AnimationSpec<Float> = if(reduceMotion||(dragging&&!firstDrag))snap() else tween(200,easing=CubicBezierEasing(.42f,0f,.58f,1f))
    val indicatorX by animateFloatAsState(targetIndicator.x,spec,label="pad.x")
    val indicatorY by animateFloatAsState(targetIndicator.y,spec,label="pad.y")
    val diameter by animateFloatAsState(if(dragging)config.touchPointSize else config.circleSize*3,spec,label="pad.indicator")
    // One Canvas; per-dot animations follow the source's initial/end transition only.
    val dots=(0 until config.count).flatMap {row->(0 until config.count).map {column->
        val dot=PositionPadModel.dot(row,column,sourceLocation,dragging,config)
        val scale by animateFloatAsState(dot.scale,spec,label="pad.dot.scale.$row.$column")
        val opacity by animateFloatAsState(dot.opacity,spec,label="pad.dot.opacity.$row.$column")
        PadDot(scale,opacity)
    }}
    val normalized=PositionPadModel.clamp(position)
    Canvas(modifier.size(config.size.dp).semantics {
        contentDescription=label;stateDescription="$horizontalLabel ${(normalized.x*100).toInt()}%, $verticalLabel ${(normalized.y*100).toInt()}%"
        fun move(dx:Float,dy:Float):Boolean {latestChange(PositionPadModel.clamp(PadPosition(normalized.x+dx,normalized.y+dy)));return true}
        val step=1f/(config.count-1)
        customActions=listOf(
            CustomAccessibilityAction("$horizontalLabel +") {move(step,0f)},CustomAccessibilityAction("$horizontalLabel −") {move(-step,0f)},
            CustomAccessibilityAction("$verticalLabel +") {move(0f,step)},CustomAccessibilityAction("$verticalLabel −") {move(0f,-step)}
        )
    }.pointerInput(config,density) {
        fun change(point:Offset) {
            localPosition=PositionPadModel.position(PadPosition(point.x/density,point.y/density),config)
            latestChange(localPosition)
        }
        awaitEachGesture {
            val down=awaitFirstDown(requireUnconsumed=false);down.consume();firstDrag=true;dragging=true;change(down.position)
            try {
                while(true) {
                    val event=awaitPointerEvent();val pointer=event.changes.firstOrNull {it.id==down.id}?:break
                    if(!pointer.pressed)break
                    firstDrag=false;change(pointer.position);pointer.consume()
                }
            } finally {dragging=false;firstDrag=false}
        }
    }) {
        for(row in 0 until config.count)for(column in 0 until config.count) {
            val dot=dots[row*config.count+column]
            drawCircle(tint.copy(alpha=(tint.alpha*dot.opacity).coerceIn(0f,1f)),radius=config.circleSize.dp.toPx()/2*dot.scale,center=Offset((column+.5f)*config.itemSize*density,(row+.5f)*config.itemSize*density))
        }
        drawCircle(tint,radius=diameter.dp.toPx()/2,center=Offset(indicatorX*density,indicatorY*density))
    }
}
