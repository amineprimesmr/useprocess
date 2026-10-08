package com.process.android
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.*
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*

/** Mount only when the host requested scanning. Returned text is data; no URL is opened automatically. */
@Composable fun TenKQrScanner(contextKey:String,onScan:(String)->Unit,onClose:()->Unit,modifier:Modifier=Modifier,isActive:Boolean=true) {
 require(contextKey.isNotBlank())
 key(contextKey) {
  val context=LocalContext.current;val owner=LocalLifecycleOwner.current;val life by owner.lifecycle.currentStateAsState()
  val prefs=remember(context){context.getSharedPreferences("tenk-qr-camera-permission",Context.MODE_PRIVATE)}
  fun permission()=if(ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)QrCameraPermission.GRANTED else if(prefs.getBoolean("requested",false))QrCameraPermission.DENIED else QrCameraPermission.UNREQUESTED
  var access by remember {mutableStateOf(permission())};var ready by remember {mutableStateOf(false)};var error by remember {mutableStateOf<String?>(null)};var closing by remember {mutableStateOf(false)};var attempt by remember {mutableIntStateOf(0)}
  val scan by rememberUpdatedState(onScan);val haptic=LocalHapticFeedback.current
  val launcher=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){access=permission()}
  LaunchedEffect(life){if(life.isAtLeast(Lifecycle.State.RESUMED))access=permission()}
  val view=remember(context){PreviewView(context).apply {implementationMode=PreviewView.ImplementationMode.COMPATIBLE;scaleType=PreviewView.ScaleType.FILL_CENTER}}
  var size by remember {mutableStateOf(IntSize.Zero)}
  val active=isActive&&life.isAtLeast(Lifecycle.State.RESUMED)&&!closing&&error==null
  LaunchedEffect(contextKey,attempt,view,size,access,active) {
   ready=false
   if(!active||access!=QrCameraPermission.GRANTED||size.width<=0||size.height<=0)return@LaunchedEffect
   // Opening changes viewport each frame. Bind once geometry has stopped changing.
   delay(150)
   val camera=TenKQrCameraSession(context,owner,view,{ready=it},{error="Camera or QR detection unavailable"},codeResult@{code->
    if(closing||!isActive||!owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))return@codeResult
    try {scan(code);haptic.performHapticFeedback(HapticFeedbackType.LongPress);closing=true}
    catch(_:Exception){error="Unable to deliver scanned code"}
   })
   try {awaitCancellation()}finally {camera.close()}
  }
  TenKQrScannerScreen(access,ready,error,onPermission={
   if(access==QrCameraPermission.DENIED)context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
   else {prefs.edit().putBoolean("requested",true).apply();launcher.launch(Manifest.permission.CAMERA)}
  },onRetry={error=null;attempt++},onClose=onClose,onDismissRequest={closing=true},modifier=modifier,isClosing=closing) {
   AndroidView(factory={view},modifier=Modifier.fillMaxSize().onSizeChanged {size=it})
  }
 }
}
