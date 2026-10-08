package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** AnimatedKeyPad, Balaji Venkatesh,16–17/02/25. Host owns all money actions. */
@Composable fun TenKAnimatedKeypad(
    value:AnimatedKeypadValue,onValueChange:(AnimatedKeypadValue)->Unit,onContinue:(Int)->Unit,
    modifier:Modifier=Modifier,currency:String="$",title:String="Send Money",continueLabel:String="Continue",
    deleteLabel:String="Delete last digit",limitLabel:String="😅 Max Length Reached!",reduceMotion:Boolean=false,
    recipient:@Composable ()->Unit={},
) {
    val currentValue by rememberUpdatedState(value);val changed by rememberUpdatedState(onValueChange)
    val duration=if(reduceMotion)0 else 250
    val ease=CubicBezierEasing(.42f,0f,.58f,1f)
    BoxWithConstraints(modifier.fillMaxSize().background(Color.Black)) {
    val minimumHeight=maxHeight
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min=minimumHeight).padding(15.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
        Text(title,Modifier.fillMaxWidth().padding(start=5.dp),color=Color.White,fontSize=34.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold)
        Box(Modifier.fillMaxWidth().weight(1f),contentAlignment=Alignment.Center) {recipient()}
        Column(Modifier.fillMaxWidth().padding(bottom=10.dp),horizontalAlignment=Alignment.CenterHorizontally) {
            Row(Modifier.height(50.dp).clearAndSetSemantics {contentDescription=currency+value.formatted},verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(2.dp)) {
                Text(currency,color=Color.White,fontSize=40.sp,fontWeight=FontWeight.Black)
                AnimatedVisibility(value.digits.isEmpty(),enter=fadeIn(tween(duration)),exit=fadeOut(tween(duration))+shrinkHorizontally(tween(duration))) {Text("0",color=Color.White,fontSize=40.sp,fontWeight=FontWeight.Black)}
                repeat(9) {index ->
                    var previous by remember {mutableStateOf("")}
                    val digit=value.digits.getOrNull(index)?.toString()
                    SideEffect {if(digit!=null)previous=digit}
                    AnimatedVisibility(digit!=null,enter=slideInVertically(tween(duration,easing=ease)){it}+fadeIn(tween(duration))+expandHorizontally(tween(duration)),exit=slideOutVertically(tween(duration,easing=ease)){-it}+fadeOut(tween(duration))+shrinkHorizontally(tween(duration))) {
                        Text(digit?:previous,color=Color.White,fontSize=40.sp,fontWeight=FontWeight.Black,letterSpacing=0.sp)
                    }
                    val comma=index<value.digits.lastIndex&&(value.digits.length-index-1)%3==0
                    AnimatedVisibility(comma,enter=fadeIn(tween(duration))+expandHorizontally(tween(duration)),exit=fadeOut(tween(duration))+shrinkHorizontally(tween(duration))) {Text(",",color=Color.White,fontSize=40.sp,fontWeight=FontWeight.Black)}
                }
            }
            Box(Modifier.height(30.dp),contentAlignment=Alignment.Center) {if(value.atLimit)Text(limitLabel,color=Color.Red,fontSize=12.sp,fontWeight=FontWeight.SemiBold)}
        }
        Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
            repeat(4) {row ->Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                repeat(3) {column ->
                    val number=if(row<3)row*3+column+1 else if(column==1)0 else -1
                    if(row==3&&column==0)Spacer(Modifier.weight(1f).height(70.dp))
                    else if(row==3&&column==2)RepeatingDeleteKey(deleteLabel,Modifier.weight(1f),duration) {changed(currentValue.deleteLast())}
                    else KeypadDigitButton(number.toString(),Modifier.weight(1f),duration) {changed(currentValue.append(number))}
                }
            }}
        }
        Button(onClick={onContinue(currentValue.amount)},modifier=Modifier.fillMaxWidth().padding(horizontal=15.dp),shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=Color.White,contentColor=Color.Black)) {Text(continueLabel,fontWeight=FontWeight.SemiBold,modifier=Modifier.padding(vertical=4.dp))}
    }
    }
}
@Composable private fun KeypadDigitButton(label:String,modifier:Modifier,duration:Int,onClick:()->Unit) {
    val source=remember {MutableInteractionSource()};val pressed by source.collectIsPressedAsState()
    val alpha by animateFloatAsState(if(pressed).2f else 0f,tween(duration),label="key.press")
    Box(modifier.height(70.dp).padding(horizontal=5.dp).background(Color.Gray.copy(alpha=alpha),RoundedCornerShape(15.dp)).clickable(source,indication=null,role=Role.Button,onClick=onClick),contentAlignment=Alignment.Center) {Text(label,color=Color.White,fontSize=22.sp,fontWeight=FontWeight.Bold)}
}
@Composable private fun RepeatingDeleteKey(label:String,modifier:Modifier,duration:Int,onDelete:()->Unit) {
    val scope=rememberCoroutineScope();val currentDelete by rememberUpdatedState(onDelete)
    val timeout=LocalViewConfiguration.current.longPressTimeoutMillis
    val owner=LocalLifecycleOwner.current
    var repeatJob by remember {mutableStateOf<Job?>(null)};var pressed by remember {mutableStateOf(false)}
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver {_,event ->if(event==Lifecycle.Event.ON_STOP){repeatJob?.cancel();pressed=false}}
        owner.lifecycle.addObserver(observer);onDispose {owner.lifecycle.removeObserver(observer);repeatJob?.cancel()}
    }
    val alpha by animateFloatAsState(if(pressed).2f else 0f,tween(duration),label="delete.press")
    Box(modifier.height(70.dp).padding(horizontal=5.dp).background(Color.Gray.copy(alpha=alpha),RoundedCornerShape(15.dp)).semantics {role=Role.Button;contentDescription=label;onClick {currentDelete();true}}.pointerInput(timeout) {
        awaitEachGesture {
            awaitFirstDown();pressed=true;var repeated=false
            repeatJob=scope.launch {delay(timeout);repeated=true;while(true){currentDelete();delay(100)}}
            try {val up=waitForUpOrCancellation();if(up!=null&&!repeated&&owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))currentDelete()}
            finally {repeatJob?.cancel();repeatJob=null;pressed=false}
        }
    },contentAlignment=Alignment.Center) {Text("⌫",color=Color.White,fontSize=26.sp)}
}
