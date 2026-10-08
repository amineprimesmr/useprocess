package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay

/** StaggeredAnimation, Balaji Venkatesh,26/03/25. Native spring/blur require device comparison. */
data class StaggeredConfig(
    val delayMillis:Long=50,val maximumDelayMillis:Long=400,val blurRadius:Dp=6.dp,
    val offsetX:Dp=0.dp,val offsetY:Dp=100.dp,val scale:Float=.95f,
    val scaleAnchor:TransformOrigin=TransformOrigin.Center,
    val disappearInSameDirection:Boolean=false,val noOffsetDisappearAnimation:Boolean=false,
    val dampingRatio:Float=1f,val stiffness:Float=1500f,
) {
    fun delayFor(index:Int):Long {
        val cap=maximumDelayMillis.coerceIn(0,60_000);val step=delayMillis.coerceIn(0,60_000)
        return (index.coerceAtLeast(0).toLong()*step).coerceAtMost(cap)
    }
}

@Composable fun TenKStaggeredItem(
    visible:Boolean,index:Int,modifier:Modifier=Modifier,config:StaggeredConfig=StaggeredConfig(),reduceMotion:Boolean=false,
    content:@Composable ()->Unit,
) {
    val state=remember {MutableTransitionState(false)}
    LaunchedEffect(visible,index,config.delayMillis,config.maximumDelayMillis,reduceMotion) {
        if(!reduceMotion)delay(config.delayFor(index))
        state.targetState=visible
    }
    val spec:FiniteAnimationSpec<Float> = if(reduceMotion)snap() else spring(
        dampingRatio=if(config.dampingRatio.isFinite())config.dampingRatio.coerceIn(.1f,2f)else 1f,
        stiffness=if(config.stiffness.isFinite())config.stiffness.coerceIn(1f,10000f)else 1500f,
    )
    AnimatedVisibility(state,modifier,enter=EnterTransition.None,exit=ExitTransition.None) {
        val opacity by transition.animateFloat({spec},label="stagger.opacity") {if(it==EnterExitState.Visible)1f else 0f}
        val scale by transition.animateFloat({spec},label="stagger.scale") {if(it==EnterExitState.Visible||reduceMotion)1f else (if(config.scale.isFinite())config.scale else .95f).coerceIn(0f,4f)}
        val blur by transition.animateFloat({spec},label="stagger.blur") {if(it==EnterExitState.Visible||reduceMotion)0f else (if(config.blurRadius.value.isFinite())config.blurRadius.value else 6f).coerceIn(0f,100f)}
        fun offset(phase:EnterExitState,value:Float):Float=when {
            reduceMotion||phase==EnterExitState.Visible ->0f
            phase==EnterExitState.PreEnter ->value
            config.noOffsetDisappearAnimation ->0f
            config.disappearInSameDirection ->value
            else ->-value
        }
        val x by transition.animateFloat({spec},label="stagger.x") {offset(it,if(config.offsetX.value.isFinite())config.offsetX.value else 0f)}
        val y by transition.animateFloat({spec},label="stagger.y") {offset(it,if(config.offsetY.value.isFinite())config.offsetY.value else 0f)}
        Box(Modifier.graphicsLayer {alpha=opacity.coerceIn(0f,1f);scaleX=scale;scaleY=scale;translationX=x*density;translationY=y*density;transformOrigin=config.scaleAnchor}.blur(blur.coerceAtLeast(0f).dp).then(
            if(visible)Modifier else Modifier.clearAndSetSemantics {}.pointerInput(Unit) {awaitPointerEventScope {while(true)awaitPointerEvent(PointerEventPass.Initial).changes.forEach {it.consume()}}}
        )) {content()}
    }
}

@Composable fun TenKStaggeredColumn(
    visible:Boolean,itemCount:Int,modifier:Modifier=Modifier,config:StaggeredConfig=StaggeredConfig(),reduceMotion:Boolean=false,
    spacing:Dp=10.dp,content:@Composable (Int)->Unit,
) {
    require(itemCount>=0) {"itemCount must be nonnegative"}
    Column(modifier,verticalArrangement=Arrangement.spacedBy(spacing)) {
        repeat(itemCount) {index ->key(index) {TenKStaggeredItem(visible,index,config=config,reduceMotion=reduceMotion) {content(index)}}}
    }
}
