package com.process.android

import android.content.Context
import android.os.SystemClock
import android.util.Rational
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.io.File
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal enum class FaceCameraError { UNAVAILABLE,CAPTURE_FAILED,INVALID_PHOTO,DETECTION_FAILED }

/** Owns only its use cases; disposing never unbinds another feature's camera. */
internal class ProcessFaceCameraSession(
 private val context:Context,private val owner:LifecycleOwner,private val view:PreviewView,
 private val contextKey:String,private val onReady:(Boolean)->Unit,private val onObservation:(FaceCaptureObservation)->Unit,
 private val onError:(FaceCameraError)->Unit,private val onPhoto:(FacePhotoCapture)->Unit,
) {
 private val closed=AtomicBoolean(false)
 private val main=ContextCompat.getMainExecutor(context)
 private val executor=Executors.newSingleThreadExecutor {work->Thread(work,"process-face-preview").apply {priority=Thread.MIN_PRIORITY}}
 private val detector=FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST).setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE).setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE).setMinFaceSize(.1f).build())
 private val preview=Preview.Builder().build()
 private val capture=ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).setTargetResolution(android.util.Size(1280,960)).build()
 private val analysis=ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).setTargetResolution(android.util.Size(640,480)).build()
 private var provider:ProcessCameraProvider?=null
 private var observation:FaceCaptureObservation?=null
 private var taking=false
 private var lastAnalyzed=0L
 init {
  analysis.setAnalyzer(executor){analyze(it)}
  preview.setSurfaceProvider(view.surfaceProvider)
  val future=ProcessCameraProvider.getInstance(context)
  future.addListener({if(!closed.get())try {
   val cameraProvider=future.get();provider=cameraProvider
   if(!cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA))throw IllegalStateException("Front camera unavailable")
   val rotation=view.display?.rotation?:android.view.Surface.ROTATION_0
   capture.targetRotation=rotation;analysis.targetRotation=rotation
   val group=UseCaseGroup.Builder().addUseCase(preview).addUseCase(capture).addUseCase(analysis)
    .setViewPort(ViewPort.Builder(Rational(view.width.coerceAtLeast(1),view.height.coerceAtLeast(1)),rotation).setScaleType(ViewPort.FILL_CENTER).build()).build()
   cameraProvider.bindToLifecycle(owner,CameraSelector.DEFAULT_FRONT_CAMERA,group)
   onReady(true)
  }catch(_:Exception){if(!closed.get()){onReady(false);onError(FaceCameraError.UNAVAILABLE)}}},main)
 }
 @androidx.annotation.OptIn(ExperimentalGetImage::class)
 private fun analyze(proxy:ImageProxy) {
  val time=SystemClock.elapsedRealtime()
  if(closed.get()||time-lastAnalyzed<100){proxy.close();return}
  lastAnalyzed=time
  val image=proxy.image
  if(image==null){proxy.close();return}
  val crop=proxy.cropRect;val upright=FaceCaptureRect(crop.left,crop.top,crop.right,crop.bottom).rotated(proxy.width,proxy.height,proxy.imageInfo.rotationDegrees)
  val plane=proxy.planes[0];val buffer=plane.buffer.duplicate();var sum=0L;var count=0
  val sx=maxOf(1,crop.width()/64);val sy=maxOf(1,crop.height()/64)
  for(y in crop.top until crop.bottom step sy)for(x in crop.left until crop.right step sx) {
   val index=y*plane.rowStride+x*plane.pixelStride
   if(index in 0 until buffer.limit()){sum+=buffer.get(index).toInt() and 255;count++}
  }
  val luminance=if(count==0)0f else (sum.toFloat()/count/255f)
  try {
   detector.process(InputImage.fromMediaImage(image,proxy.imageInfo.rotationDegrees)).addOnSuccessListener(main){faces->
    if(!closed.get()) {
     val face=faces.singleOrNull();val box=face?.boundingBox
     val result=FaceCaptureObservation(faces.size,if(box==null)0f else box.width().toFloat()*box.height()/maxOf(1,upright.width*upright.height),
      if(box==null).5f else (box.exactCenterX()-upright.left)/maxOf(1,upright.width),if(box==null).5f else (box.exactCenterY()-upright.top)/maxOf(1,upright.height),face?.headEulerAngleY?:0f,face?.headEulerAngleX?:0f,luminance,time)
     observation=result;onObservation(result)
    }
   }.addOnFailureListener(main){if(!closed.get()){observation=null;onObservation(FaceCaptureObservation(-1))}}.addOnCompleteListener {proxy.close()}
  }catch(_:Exception){proxy.close();main.execute {if(!closed.get()){observation=null;onObservation(FaceCaptureObservation(-1))}}}
 }
 fun takePhoto():Boolean {
  val current=observation?:return false
  if(closed.get()||taking||!current.canCapture(SystemClock.elapsedRealtime()))return false
  taking=true
  val directory=File(context.cacheDir,"process-face-captures").apply {mkdirs()}
  val file=File(directory,"capture-${UUID.randomUUID()}.jpg")
  val metadata=ImageCapture.Metadata().apply {isReversedHorizontal=true}
  val options=ImageCapture.OutputFileOptions.Builder(file).setMetadata(metadata).build()
  try {capture.takePicture(options,main,object:ImageCapture.OnImageSavedCallback {
   override fun onImageSaved(output:ImageCapture.OutputFileResults) {
    taking=false
    if(closed.get()){file.delete();return}
    if(file.length()==0L){file.delete();onError(FaceCameraError.CAPTURE_FAILED);return}
    verifySavedPhoto(file)
   }
   override fun onError(exception:ImageCaptureException) {taking=false;file.delete();if(!closed.get())onError(FaceCameraError.CAPTURE_FAILED)}
  })}catch(_:Exception){taking=false;file.delete();onError(FaceCameraError.CAPTURE_FAILED);return false}
  return true
 }
 private fun verifySavedPhoto(file:File) {
  taking=true
  executor.execute {
   if(closed.get()){file.delete();return@execute}
   try {
    val bitmap=android.graphics.ImageDecoder.decodeBitmap(android.graphics.ImageDecoder.createSource(file)){decoder,_,_->decoder.allocator=android.graphics.ImageDecoder.ALLOCATOR_SOFTWARE;decoder.setTargetSize(64,64)}
    var light=0.0
    for(y in 0 until bitmap.height)for(x in 0 until bitmap.width){val pixel=bitmap.getPixel(x,y);light+=(.2126*android.graphics.Color.red(pixel)+.7152*android.graphics.Color.green(pixel)+.0722*android.graphics.Color.blue(pixel))/255.0}
    val luminance=(light/(bitmap.width*bitmap.height)).toFloat();bitmap.recycle()
    val input=InputImage.fromFilePath(context,android.net.Uri.fromFile(file))
    detector.process(input).addOnSuccessListener(main){faces->
     taking=false
     if(closed.get()){file.delete();return@addOnSuccessListener}
     val face=faces.singleOrNull();val box=face?.boundingBox
     val result=FaceCaptureObservation(faces.size,if(box==null)0f else box.width().toFloat()*box.height()/maxOf(1,input.width*input.height),if(box==null).5f else box.exactCenterX()/input.width,if(box==null).5f else box.exactCenterY()/input.height,face?.headEulerAngleY?:0f,face?.headEulerAngleX?:0f,luminance,SystemClock.elapsedRealtime())
     if(result.hint()!=FaceCaptureHint.READY){file.delete();onError(FaceCameraError.INVALID_PHOTO)}
     else onPhoto(FacePhotoCapture(file,contextKey,Instant.now(),result,mirrored=true))
    }.addOnFailureListener(main){taking=false;file.delete();if(!closed.get())onError(FaceCameraError.DETECTION_FAILED)}
   }catch(_:Exception){file.delete();main.execute{taking=false;if(!closed.get())onError(FaceCameraError.DETECTION_FAILED)}}
  }
 }
 fun close() {
  if(!closed.compareAndSet(false,true))return
  observation=null;runCatching {analysis.clearAnalyzer();provider?.unbind(preview,capture,analysis)};runCatching {detector.close()};executor.shutdown()
 }
}
