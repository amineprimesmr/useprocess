package com.process.android

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.*
import kotlinx.coroutines.*

/** onContinue must return true only after the host takes ownership of the local photo. */
@Composable fun ProcessFaceCapture(
 contextKey:String,onBack:()->Unit,onContinue:(FacePhotoCapture)->Boolean,
 modifier:Modifier=Modifier,english:Boolean=false,isActive:Boolean=true,
) {
 require(contextKey.isNotBlank())
 key(contextKey) {
  val context=LocalContext.current;val lifecycleOwner=LocalLifecycleOwner.current
  val lifecycle by lifecycleOwner.lifecycle.currentStateAsState()
  val prefs=remember(context){context.getSharedPreferences("process-face-capture-permission",Context.MODE_PRIVATE)}
  fun permission()=if(ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)FaceCameraPermission.GRANTED else if(prefs.getBoolean("requested",false))FaceCameraPermission.DENIED else FaceCameraPermission.UNREQUESTED
  var access by remember {mutableStateOf(permission())}
  var ready by remember {mutableStateOf(false)};var observation by remember {mutableStateOf(FaceCaptureObservation(0))}
  var busy by remember {mutableStateOf(false)};var flash by remember {mutableStateOf(false)};var error by remember {mutableStateOf<String?>(null)}
  var photo by remember {mutableStateOf<FacePhotoCapture?>(null)};var accepted by remember {mutableStateOf(false)}
  var camera by remember {mutableStateOf<ProcessFaceCameraSession?>(null)}
  val callback by rememberUpdatedState(onContinue)
  val active=isActive&&lifecycle.isAtLeast(Lifecycle.State.RESUMED)
  val launcher=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){access=permission()}
  LaunchedEffect(lifecycle){if(lifecycle.isAtLeast(Lifecycle.State.RESUMED))access=permission()}
  val activity=remember(context){context.findCaptureActivity()}
  DisposableEffect(activity,flash,active) {
   val window=activity?.window;val original=window?.attributes?.screenBrightness
   if(window!=null&&flash&&active)window.attributes=window.attributes.apply {screenBrightness=1f}
   onDispose {if(window!=null&&original!=null)window.attributes=window.attributes.apply {screenBrightness=original}}
  }
  DisposableEffect(contextKey){onDispose {if(!accepted)photo?.file?.delete()}}
  val view=remember(context){PreviewView(context).apply {implementationMode=PreviewView.ImplementationMode.COMPATIBLE;scaleType=PreviewView.ScaleType.FILL_CENTER}}
  var size by remember {mutableStateOf(IntSize.Zero)}
  DisposableEffect(contextKey,view,size,access,active,photo!=null) {
   ready=false;observation=FaceCaptureObservation(0);if(photo==null)busy=false
   val session=if(active&&access==FaceCameraPermission.GRANTED&&photo==null&&size.width>0&&size.height>0)ProcessFaceCameraSession(context,lifecycleOwner,view,contextKey,{ready=it},{observation=it},{failure->busy=false;error=when(failure){FaceCameraError.UNAVAILABLE->if(english)"Camera unavailable. Close and reopen this screen."else"Caméra indisponible. Ferme puis rouvre cet écran.";FaceCameraError.CAPTURE_FAILED->if(english)"Photo capture failed. Please try again."else"La capture a échoué. Réessaie.";FaceCameraError.INVALID_PHOTO->if(english)"Photo framing or lighting changed. Please try again."else"Le cadrage ou la lumière a changé. Reprends la photo.";FaceCameraError.DETECTION_FAILED->if(english)"Photo verification failed. Please try again."else"La vérification de la photo a échoué. Réessaie."}},{captured->photo=captured;busy=false;flash=false;error=null})else null
   camera=session
   onDispose {session?.close();if(camera===session)camera=null}
  }
  val file=photo?.file
  val bitmap by produceState<Bitmap?>(null,file) {
   value=if(file==null)null else withContext(Dispatchers.IO) {try{ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)){decoder,info,_->decoder.allocator=ImageDecoder.ALLOCATOR_SOFTWARE;val factor=maxOf(info.size.width,info.size.height)/1024f;if(factor>1)decoder.setTargetSize((info.size.width/factor).toInt(),(info.size.height/factor).toInt())}}catch(_:Exception){null}}
  }
  ProcessFaceCaptureScreen(FaceCaptureViewState(access,observation.hint(),ready,busy,photo!=null,flash,error),
   onBack={flash=false;onBack()},onPermission={
    if(access==FaceCameraPermission.DENIED)context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    else {prefs.edit().putBoolean("requested",true).apply();launcher.launch(Manifest.permission.CAMERA)}
   },onFlash={flash=!flash},onCapture={
    error=null
    if(camera?.takePhoto()==true)busy=true else error=if(english)"Hold your position and try again."else"Garde ta position puis réessaie."
   },onRetake={photo?.file?.delete();photo=null;accepted=false;busy=false;error=null},onContinue={
    val current=photo
    if(current!=null&&!accepted&&!busy&&current.contextKey==contextKey) {
     busy=true
     try {if(callback(current)){accepted=true;flash=false}else error=if(english)"Unable to continue. Please try again."else"Impossible de continuer. Réessaie."}
     catch(_:Exception){error=if(english)"Unable to continue. Please try again."else"Impossible de continuer. Réessaie."}
     finally {busy=false}
    }
   },modifier=modifier,english=english) {
    if(file!=null)bitmap?.let {Image(it.asImageBitmap(),if(english)"Captured photo"else"Photo capturée",Modifier.fillMaxSize(),contentScale=ContentScale.Crop)}
    else AndroidView(factory={view},modifier=Modifier.fillMaxSize().onSizeChanged {size=it})
   }
 }
}
private fun Context.findCaptureActivity():Activity?=when(this){is Activity->this;is ContextWrapper->if(baseContext===this)null else baseContext.findCaptureActivity();else->null}
