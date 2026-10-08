package com.process.android
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import kotlinx.coroutines.delay

@Composable fun TenKQrScannerScreen(
 permission:QrCameraPermission,ready:Boolean,error:String?,onPermission:()->Unit,onRetry:()->Unit,onClose:()->Unit,onDismissRequest:()->Unit={},
 modifier:Modifier=Modifier,isClosing:Boolean=false,reduceMotion:Boolean=rememberProcessReducedMotion(),preview:@Composable ()->Unit,
) {
 var expanded by remember {mutableStateOf(false)};var closing by remember {mutableStateOf(false)};val close by rememberUpdatedState(onClose);var didClose by remember {mutableStateOf(false)};val shouldClose=closing||isClosing
 val progress=remember {Animatable(0f)}
 LaunchedEffect(Unit){if(!reduceMotion)delay(50);expanded=true}
 LaunchedEffect(expanded,shouldClose,reduceMotion){progress.animateTo(if(expanded&&!shouldClose)1f else 0f,if(reduceMotion)snap()else tween(350));if(shouldClose&&!didClose){didClose=true;close()}}
 val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
 fun requestClose(){closing=true;onDismissRequest()}
 BackHandler {requestClose()}
 val amount=progress.value
 BoxWithConstraints(modifier.fillMaxSize().safeDrawingPadding()) {
  val square=minOf(maxWidth-30.dp,maxHeight-20.dp).coerceAtLeast(120.dp)
  val width=120.dp+(square-120.dp)*amount;val height=36.dp+(square-36.dp)*amount
  Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.35f*amount)).clickable(interactionSource=remember{androidx.compose.foundation.interaction.MutableInteractionSource()},indication=null){requestClose()}.semantics {contentDescription="Close QR scanner"})
  Box(Modifier.align(Alignment.TopCenter).padding(top=10.dp).size(width,height).clip(RoundedCornerShape(30.dp)).background(Color.Black).pointerInput(Unit){detectTapGestures {}},contentAlignment=Alignment.Center) {
   if(amount>0f) {
    if(permission==QrCameraPermission.GRANTED&&error==null)Box(Modifier.fillMaxSize().padding(80.dp).alpha(amount)) {
     Box(Modifier.fillMaxSize().clip(RoundedCornerShape(30.dp)).border(2.dp,Color.White,RoundedCornerShape(30.dp))) {
      preview()
      if(ready&&life.isAtLeast(Lifecycle.State.RESUMED)&&!shouldClose) {
       var fraction=.5f
       if(!reduceMotion){val transition=rememberInfiniteTransition(label="qr sweep");val value by transition.animateFloat(0f,1f,infiniteRepeatable(tween(850,delayMillis=100,easing=FastOutSlowInEasing),RepeatMode.Reverse),label="qr line");fraction=value}
       Canvas(Modifier.fillMaxSize().clearAndSetSemantics {}) {val y=(size.height-2.5.dp.toPx())*fraction;drawLine(Color.White,androidx.compose.ui.geometry.Offset(0f,y),androidx.compose.ui.geometry.Offset(size.width,y),2.5.dp.toPx())}
      }
     }
     Text("Scan your QR code",Modifier.align(Alignment.BottomCenter).offset(y=25.dp),fontSize=11.sp,letterSpacing=0.sp,color=Color.White.copy(alpha=.6f),maxLines=1)
    }
    else Column(Modifier.alpha(amount).padding(20.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(4.dp)) {
     QrPermissionGlyph()
     Text(if(error!=null)error else if(permission==QrCameraPermission.DENIED)"Permission denied"else"Camera access required",fontSize=12.sp,letterSpacing=0.sp,color=if(permission==QrCameraPermission.DENIED||error!=null)Color(0xFFFF3B30)else Color.White)
     TextButton(if(error!=null)onRetry else onPermission){Text(if(error!=null)"Try again"else if(permission==QrCameraPermission.DENIED)"Go to Settings"else"Allow camera",fontSize=12.sp,letterSpacing=0.sp,color=Color.White)}
    }
   }
  }
 }
}

@Composable private fun QrPermissionGlyph() {
 Canvas(Modifier.size(45.dp).clearAndSetSemantics {}) {
  val w=size.width;val h=size.height;val stroke=2.2.dp.toPx()
  drawRoundRect(Color.White,androidx.compose.ui.geometry.Offset(w*.14f,h*.25f),androidx.compose.ui.geometry.Size(w*.72f,h*.52f),androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()),style=androidx.compose.ui.graphics.drawscope.Stroke(stroke))
  drawCircle(Color.White,w*.15f,androidx.compose.ui.geometry.Offset(w*.5f,h*.51f),style=androidx.compose.ui.graphics.drawscope.Stroke(stroke))
  drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*.3f,h*.22f),androidx.compose.ui.geometry.Offset(w*.45f,h*.22f),stroke)
  for(x in listOf(.02f,.98f))for(y in listOf(.06f,.94f)){val sx=if(x<.5f)1 else -1;val sy=if(y<.5f)1 else -1;drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*x,h*y),androidx.compose.ui.geometry.Offset(w*(x+.14f*sx),h*y),stroke);drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*x,h*y),androidx.compose.ui.geometry.Offset(w*x,h*(y+.14f*sy)),stroke)}
 }
}
