package com.tenkdesign.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import kotlin.math.*

/** ElasticSegmentedControl, Balaji Venkatesh,18 July2026. Native translucent surface approximates Apple glass. */
data class ElasticSegmentedConfig(val activeTint:Color=Color.White,val inactiveTint:Color=Color.Gray,val capsuleTint:Color=Color(0xff007aff),val backgroundTint:Color=Color.Gray.copy(alpha=.18f))
@Composable fun <T:Any> TenKElasticSegmentedControl(
    tabs:List<T>,selection:T,onSelection:(T)->Unit,modifier:Modifier=Modifier,
    config:ElasticSegmentedConfig=ElasticSegmentedConfig(),reduceMotion:Boolean=false,
    labelDescription:(T)->String={it.toString()},label:@Composable (T)->Unit,
) {
    require(tabs.isNotEmpty()&&tabs.distinct().size==tabs.size)
    var offset by remember {mutableFloatStateOf(0f)};var dragging by remember {mutableStateOf(false)}
    val latestSelection by rememberUpdatedState(selection);val callback by rememberUpdatedState(onSelection)
    val haptics=LocalHapticFeedback.current
    fun select(index:Int){val value=tabs[index];if(value!=latestSelection){callback(value);haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}}
    val spec:FiniteAnimationSpec<Float> = if(reduceMotion)snap()else tween(200,easing=CubicBezierEasing(.2f,.8f,.2f,1f))
    BoxWithConstraints(modifier.fillMaxWidth().clip(CircleShape).background(config.backgroundTint).padding(5.dp)) {
        val slot=maxWidth/tabs.size
        val selected=tabs.indexOf(selection).coerceAtLeast(0)
        val position by animateFloatAsState(selected.toFloat(),spec,label="elastic.position")
        val extension by animateFloatAsState(offset,if(dragging)snap()else spec,label="elastic.extension")
        fun indicator(size:Size):Path {
            val width=size.width/tabs.size;val left=position*width+min(extension,0f);val right=position*width+width+max(extension,0f)
            val shrink=if(size.width>0)(abs(extension)/(size.width*.7f))*.2f else 0f
            val h=size.height*(1f-shrink).coerceAtLeast(0f);val top=(size.height-h)/2
            return Path().apply {addRoundRect(RoundRect(left,top,right,top+h,CornerRadius(h/2)))}
        }
        Box(Modifier.fillMaxWidth().height(35.dp).pointerInput(tabs,selection) {
            awaitEachGesture {
                val down=awaitFirstDown(requireUnconsumed=false);down.consume();val start=down.position
                var latest=start;dragging=true
                try {
                    while(true){
                        val event=awaitPointerEvent();val change=event.changes.firstOrNull {it.id==down.id}?:break
                        latest=change.position
                        if(change.isConsumed)break
                        if(!change.pressed){
                            val slotPx=size.width.toFloat()/tabs.size;val current=tabs.indexOf(latestSelection).coerceAtLeast(0)*slotPx
                            select(ElasticSegmentedModel.dropIndex(if(abs(latest.x-start.x)<5.dp.toPx())latest.x else current+offset,slotPx,tabs.size,abs(latest.x-start.x)>=5.dp.toPx()));change.consume();break
                        }
                        offset=ElasticSegmentedModel.acceptedOffset(offset,latest.x-start.x,tabs.indexOf(latestSelection).coerceAtLeast(0)*size.width.toFloat()/tabs.size,size.width.toFloat(),tabs.size)
                        change.consume()
                    }
                }finally {dragging=false;offset=0f}
            }
        }) {
            Canvas(Modifier.fillMaxSize()){drawPath(indicator(size),Brush.verticalGradient(listOf(config.capsuleTint,config.capsuleTint.copy(alpha=.84f))))}
            Row(Modifier.fillMaxSize()) {tabs.forEachIndexed {index,tab->
                Box(Modifier.width(slot).fillMaxHeight().clip(CircleShape).semantics {
                    role=Role.RadioButton;contentDescription=labelDescription(tab);this.selected=tab==selection
                    onClick {select(index);true}
                },contentAlignment=Alignment.Center){CompositionLocalProvider(LocalContentColor provides config.inactiveTint){label(tab)}}
            }}
            Row(Modifier.fillMaxSize().clearAndSetSemantics {}.drawWithContent {clipPath(indicator(size)){this@drawWithContent.drawContent()}}) {tabs.forEach {tab->Box(Modifier.width(slot).fillMaxHeight().clip(CircleShape),contentAlignment=Alignment.Center){CompositionLocalProvider(LocalContentColor provides config.activeTint){label(tab)}}}}
        }
    }
}
