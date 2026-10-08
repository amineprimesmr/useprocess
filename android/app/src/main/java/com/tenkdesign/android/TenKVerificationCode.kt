package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*

/** Controlled input. Validation is cancelled and its result discarded on value, length or context change. */
@Composable fun TenKVerificationCode(
 value:String,onValueChange:(String)->Unit,
 modifier:Modifier=Modifier,length:VerificationCodeLength=VerificationCodeLength.SIX,
 style:VerificationCodeStyle=VerificationCodeStyle.ROUNDED,
 contextKey:Any=Unit,enabled:Boolean=true,autoFocus:Boolean=false,reduceMotion:Boolean=false,
 borderWidth:Dp=1.2.dp,label:String="Verification code",
 onStateChange:(VerificationCodeState)->Unit={},
 validate:suspend (String)->VerificationCodeState={VerificationCodeState.TYPING}
) {
 val normalized=normalizedVerificationCode(value,length)
 var state by remember(contextKey,length) {mutableStateOf(VerificationCodeState.TYPING)}
 var focused by remember {mutableStateOf(false)}
 val focus=remember {FocusRequester()};val manager=LocalFocusManager.current
 val latestValidate by rememberUpdatedState(validate);val latestState by rememberUpdatedState(onStateChange)
 val shake=remember {Animatable(0f)}
 LaunchedEffect(contextKey,length,normalized,enabled) {
  shake.snapTo(0f);state=VerificationCodeState.TYPING;latestState(state)
  if(!enabled)return@LaunchedEffect
  val result=try {latestValidate(normalized)}catch(e:CancellationException){throw e}catch(_:Exception){VerificationCodeState.INVALID}
  currentCoroutineContext().ensureActive();state=result;latestState(result)
  if(result==VerificationCodeState.INVALID&&!reduceMotion) {
   for(x in listOf(10f,-10f,10f,-5f,5f,0f))shake.animateTo(x,tween(60,easing=LinearEasing))
  }
 }
 LaunchedEffect(contextKey,autoFocus,enabled) {if(autoFocus&&enabled)focus.requestFocus()}
 BasicTextField(
  value=normalized,onValueChange={onValueChange(normalizedVerificationCode(it,length))},enabled=enabled,
  singleLine=true,textStyle=TextStyle(color=Color.Transparent),cursorBrush=SolidColor(Color.Transparent),
  keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.NumberPassword,imeAction=ImeAction.Done),
  keyboardActions=KeyboardActions(onDone={manager.clearFocus()}),
  modifier=modifier.offset {IntOffset(shake.value.dp.roundToPx(),0)}.focusRequester(focus).onFocusChanged {focused=it.isFocused}
   .semantics {contentDescription=label;stateDescription=when(state){VerificationCodeState.TYPING->"Typing";VerificationCodeState.VALID->"Valid";VerificationCodeState.INVALID->"Invalid"}},
  decorationBox={inner ->
   Box {
    // Keep the real editor and its editing/accessibility semantics in the layout.
    Box(Modifier.size(1.dp).alpha(.01f)){inner()}
    Row(horizontalArrangement=Arrangement.spacedBy(if(style==VerificationCodeStyle.ROUNDED)6.dp else 10.dp),modifier=Modifier.clearAndSetSemantics {}) {
     repeat(length.digits) {index ->
      val target=when(state){VerificationCodeState.VALID->Color(0xFF34C759);VerificationCodeState.INVALID->Color(0xFFFF3B30);VerificationCodeState.TYPING->if(focused&&normalized.length==index)MaterialTheme.colorScheme.onSurface else Color(0xFF8E8E93)}
      val color by animateColorAsState(target,tween(if(reduceMotion)0 else 200,easing=FastOutSlowInEasing),label="code border")
      val frame=if(style==VerificationCodeStyle.ROUNDED)Modifier.size(50.dp).border(borderWidth,color,RoundedCornerShape(10.dp))else Modifier.size(40.dp,50.dp)
      Box(frame,contentAlignment=Alignment.Center) {
       if(style==VerificationCodeStyle.UNDERLINED)Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(1.dp).background(color))
       AnimatedContent(normalized.getOrNull(index)?.toString().orEmpty(),transitionSpec={
        (fadeIn(tween(if(reduceMotion)0 else 200))+scaleIn(tween(if(reduceMotion)0 else 200),initialScale=.9f)) togetherWith fadeOut(tween(if(reduceMotion)0 else 200))
       },label="code digit") {digit -> Text(digit,fontSize=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp)}
      }
     }
    }
   }
  }
 )
}
