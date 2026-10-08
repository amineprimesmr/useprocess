package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.nestedscroll.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*

class ProcessTabBarState internal constructor(private val density:Float) {
    private val model=ProcessTabCollapseModel()
    private var offset=0f
    var progress by mutableFloatStateOf(0f);private set
    var dragging by mutableStateOf(false);private set
    var hasScrollableContent by mutableStateOf(true)
    val nestedScrollConnection=object:NestedScrollConnection {
        override fun onPostScroll(consumed:Offset,available:Offset,source:NestedScrollSource):Offset {
            if(source==NestedScrollSource.UserInput && consumed.y!=0f) {
                dragging=true
                val next=(offset-consumed.y/density).coerceAtLeast(0f)
                progress=model.update(offset,next,true,hasScrollableContent);offset=next
            }
            return Offset.Zero
        }
        override suspend fun onPreFling(available:Velocity):Velocity {
            dragging=false;progress=model.endDrag(available.y/density,hasScrollableContent);return Velocity.Zero
        }
    }
    fun expand() {model.expand();progress=0f;dragging=false}
}

@Composable fun rememberProcessTabBarState():ProcessTabBarState {
    val density=LocalDensity.current.density
    return remember(density) {ProcessTabBarState(density)}
}

/** Four original tabs, optional separate meal scan action; host reserves bottom insets and content. */
@Composable fun ProcessTabBar(
    selected:ProcessMainSection,
    onSelect:(ProcessMainSection)->Unit,
    modifier:Modifier=Modifier,
    state:ProcessTabBarState=rememberProcessTabBarState(),
    onMealScan:(()->Unit)?=null,
    hidden:Boolean=false,
    profileSubrouteActive:Boolean=false,
    english:Boolean=false,
    dark:Boolean=isSystemInDarkTheme()
) {
    val palette=InputPalette(dark)
    val haptics=LocalHapticFeedback.current
    LaunchedEffect(selected) {state.expand()}
    val progress by animateFloatAsState(state.progress,if(state.dragging)snap() else spring(1f,631.65f),label="tabs.collapse")
    if(hidden||selected==ProcessMainSection.COACH||(selected==ProcessMainSection.PROFILE&&profileSubrouteActive))return
    Row(modifier.fillMaxWidth().padding(horizontal=20.dp).graphicsLayer {val scale=1-progress*.15f;scaleX=scale;scaleY=scale;transformOrigin=TransformOrigin(.5f,1f)}
        .pointerInput(state) {awaitEachGesture {awaitFirstDown(requireUnconsumed=false);state.expand()}},
        horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
        Row(Modifier.weight(1f).height(58.dp).clip(RoundedCornerShape(29.dp))
            .background(if(dark)Color(.09f,.09f,.10f,.96f) else Color.White.copy(alpha=.92f))
            .border(1.dp,palette.primary.copy(alpha=.08f),RoundedCornerShape(29.dp))
            .padding(4.dp).selectableGroup()) {
            ProcessMainSection.tabOrder.forEach {tab->
                val selectedFill by animateColorAsState(palette.primary.copy(alpha=if(tab==selected).12f else 0f),spring(.85f,631.65f),label="tabs.selected")
                Box(Modifier.weight(1f).height(50.dp).clip(RoundedCornerShape(25.dp)).background(selectedFill)
                    .selectable(selected=tab==selected,role=Role.Tab,onClick={state.expand();if(tab!=selected){haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove);onSelect(tab)}})
                    .semantics {contentDescription=tab.label(english)},contentAlignment=Alignment.Center) {
                    val tint=palette.primary.copy(alpha=if(tab==selected)1f else .6f)
                    if(tab==ProcessMainSection.PLAN||tab==ProcessMainSection.PROFILE)Image(painterResource(if(tab==ProcessMainSection.PLAN)R.drawable.tab_icon_home else R.drawable.tab_icon_streak),null,Modifier.size(24.dp),colorFilter=ColorFilter.tint(tint))
                    else TabVector(tab,tint)
                }
            }
        }
        if(onMealScan!=null) {
            Box(Modifier.size(62.dp).clip(CircleShape).background(if(dark)Color(.09f,.09f,.10f,.96f) else Color.White.copy(alpha=.92f))
                .border(1.dp,palette.primary.copy(alpha=.08f),CircleShape).clickable(role=Role.Button) {state.expand();haptics.performHapticFeedback(HapticFeedbackType.LongPress);onMealScan()}
                .semantics {contentDescription=if(english)"Scan a meal" else "Scanner un repas"},contentAlignment=Alignment.Center) {TabVector(ProcessMainSection.SCAN,palette.primary)}
        }
    }
}

/** Fallback vectors for SF Symbols; native optical matching remains a separate visual check. */
@Composable private fun TabVector(tab:ProcessMainSection,tint:Color) {
    Canvas(Modifier.size(24.dp)) {
        val u=size.width/24;val stroke=Stroke(1.8f*u,cap=StrokeCap.Round,join=StrokeJoin.Round)
        fun line(x1:Float,y1:Float,x2:Float,y2:Float)=drawLine(tint,Offset(x1*u,y1*u),Offset(x2*u,y2*u),stroke.width,StrokeCap.Round)
        when(tab) {
            ProcessMainSection.FOOD->{line(5f,3f,5f,8f);line(8f,3f,8f,21f);line(11f,3f,11f,8f);line(5f,8f,11f,8f);line(18f,3f,18f,21f);drawPath(Path().apply{moveTo(18*u,3*u);quadraticTo(13*u,6*u,15*u,13*u);lineTo(18*u,13*u)},tint,style=stroke)}
            ProcessMainSection.ROUTINE->{listOf(5f,12f,19f).forEach {y->line(10f,y,21f,y);line(2f,y,4f,y+2);line(4f,y+2,7f,y-2)}}
            else->{line(3f,8f,3f,3f);line(3f,3f,8f,3f);line(16f,3f,21f,3f);line(21f,3f,21f,8f);line(21f,16f,21f,21f);line(21f,21f,16f,21f);line(8f,21f,3f,21f);line(3f,21f,3f,16f)}
        }
    }
}
