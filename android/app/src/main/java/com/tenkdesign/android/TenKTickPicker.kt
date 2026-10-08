package com.tenkdesign.android

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.snapping.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.*

enum class TickAlignment {TOP,BOTTOM,CENTER}
data class TickPickerConfig(
    val tickWidth:Dp=3.dp,val tickHeight:Dp=30.dp,val horizontalPadding:Dp=3.dp,
    val inactiveHeightProgress:Float=.55f,val interactionHeight:Dp=60.dp,
    val activeTint:Color=Color.Yellow,val inactiveTint:Color=Color.Black,
    val alignment:TickAlignment=TickAlignment.BOTTOM,
)

/** TickPicker by Balaji Venkatesh,21December2025. Count is inclusive: 0 through count. */
@Composable fun TenKTickPicker(
    count:Int,selection:Int,onSelection:(Int)->Unit,modifier:Modifier=Modifier,
    config:TickPickerConfig=TickPickerConfig(),reduceMotion:Boolean=false,accessibilityLabel:String="Tick value",
) {
    require(count in 0..10000)
    require(config.tickWidth.value.isFinite()&&config.tickWidth>0.dp&&config.tickHeight.value.isFinite()&&config.tickHeight>0.dp&&config.horizontalPadding.value.isFinite()&&config.horizontalPadding>=0.dp)
    require(config.interactionHeight.value.isFinite()&&config.interactionHeight>=config.tickHeight&&config.inactiveHeightProgress.isFinite()&&config.inactiveHeightProgress in 0f..1f)
    val bounded=selection.coerceIn(0,count)
    val list=rememberLazyListState(initialFirstVisibleItemIndex=bounded)
    var index by remember {mutableIntStateOf(bounded)};var range by remember {mutableStateOf(bounded..bounded)}
    var ready by remember {mutableStateOf(false)};var adjusting by remember {mutableStateOf(false)}
    val latestSelection by rememberUpdatedState(bounded);val callback by rememberUpdatedState(onSelection)
    fun nearest():Int {
        val info=list.layoutInfo;val center=(info.viewportStartOffset+info.viewportEndOffset)/2f
        return info.visibleItemsInfo.minByOrNull {abs(it.offset+it.size/2f-center)}?.index?.coerceIn(0,count)?:index.coerceIn(0,count)
    }
    LaunchedEffect(count) {list.scrollToItem(bounded);delay(50);ready=true}
    LaunchedEffect(bounded,count) {
        if(index!=bounded) {adjusting=true;index=bounded;range=bounded..bounded;try {list.scrollToItem(bounded)}finally {adjusting=false}}
    }
    LaunchedEffect(list,count) {
        snapshotFlow {list.isScrollInProgress to nearest()}.distinctUntilChanged().collect {(moving,next)->
            if(!ready||adjusting)return@collect
            if(moving) {
                range=min(index,next)..max(index,next)
                if(index!=next){index=next;if(next!=latestSelection)callback(next)}
            }else {
                index=next;range=next..next
                if(next!=latestSelection)callback(next)
                // Restore exact center after native fling settling, including at both ends.
                if(list.firstVisibleItemScrollOffset!=0){adjusting=true;try {if(reduceMotion)list.scrollToItem(next)else list.animateScrollToItem(next)}finally {adjusting=false}}
            }
        }
    }
    BoxWithConstraints(modifier.fillMaxWidth().height(config.interactionHeight).clearAndSetSemantics {
        contentDescription=accessibilityLabel;progressBarRangeInfo=ProgressBarRangeInfo(bounded.toFloat(),0f..count.toFloat(),(count-1).coerceAtLeast(0))
        setProgress {value->if(value.isFinite()){callback(value.roundToInt().coerceIn(0,count));true}else false}
    }) {
        val slot=config.tickWidth+config.horizontalPadding*2
        val padding=((maxWidth-slot)/2).coerceAtLeast(0.dp)
        LazyRow(state=list,flingBehavior=rememberSnapFlingBehavior(list,snapPosition=SnapPosition.Center),userScrollEnabled=ready,contentPadding=PaddingValues(horizontal=padding),modifier=Modifier.fillMaxSize(),verticalAlignment=Alignment.CenterVertically) {
            items(count+1,key={it}) {value->
                val inside=value in range
                val spec:FiniteAnimationSpec<Float> = if(inside||!ready||reduceMotion)snap()else tween(300,easing=CubicBezierEasing(.2f,.8f,.2f,1f))
                val fraction by animateFloatAsState(if(inside)1f else config.inactiveHeightProgress,spec,label="tick.height.$value")
                val tint=if(index==value)config.activeTint else config.inactiveTint.copy(alpha=config.inactiveTint.alpha*(if(inside)1f else .4f))
                val color by animateColorAsState(tint,if(inside||!ready||reduceMotion)snap()else tween(300),label="tick.color.$value")
                Box(Modifier.width(slot).height(config.tickHeight),contentAlignment=when(config.alignment){TickAlignment.TOP->Alignment.TopCenter;TickAlignment.BOTTOM->Alignment.BottomCenter;TickAlignment.CENTER->Alignment.Center}) {
                    Box(Modifier.width(config.tickWidth).height(config.tickHeight*fraction).background(color))
                }
            }
        }
    }
}
