package com.process.android
import android.content.Context
import android.os.SystemClock
import android.util.Rational
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Owns only preview/analysis; no image file,URI navigation or network submission. */
internal class TenKQrCameraSession(context:Context,owner:LifecycleOwner,view:PreviewView,onReady:(Boolean)->Unit,private val onError:()->Unit,private val onCode:(String)->Unit) {
 private val closed=AtomicBoolean(false);private val gate=QrCodeDelivery()
 private val main=ContextCompat.getMainExecutor(context)
 private val worker=Executors.newSingleThreadExecutor {job->Thread(job,"tenk-qr-analysis").apply {priority=Thread.MIN_PRIORITY}}
 private val detector=BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build())
 private val preview=Preview.Builder().build()
 private val analysis=ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).setTargetResolution(android.util.Size(1280,720)).build()
 private var provider:ProcessCameraProvider?=null;private var lastFrame=0L
 init {
  analysis.setAnalyzer(worker){analyze(it)};preview.setSurfaceProvider(view.surfaceProvider)
  val future=ProcessCameraProvider.getInstance(context)
  future.addListener({if(!closed.get())try {
   val p=future.get();provider=p
   check(p.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA))
   val rotation=view.display?.rotation?:android.view.Surface.ROTATION_0;analysis.targetRotation=rotation
   val group=UseCaseGroup.Builder().addUseCase(preview).addUseCase(analysis).setViewPort(ViewPort.Builder(Rational(view.width.coerceAtLeast(1),view.height.coerceAtLeast(1)),rotation).setScaleType(ViewPort.FILL_CENTER).build()).build()
   p.bindToLifecycle(owner,CameraSelector.DEFAULT_BACK_CAMERA,group);onReady(true)
  }catch(_:Exception){if(!closed.get()){onReady(false);onError()}}},main)
 }
 @androidx.annotation.OptIn(ExperimentalGetImage::class)
 private fun analyze(proxy:ImageProxy) {
  val now=SystemClock.elapsedRealtime()
  if(closed.get()||now-lastFrame<100){proxy.close();return};lastFrame=now
  val image=proxy.image;if(image==null){proxy.close();return}
  try {
   detector.process(InputImage.fromMediaImage(image,proxy.imageInfo.rotationDegrees))
    .addOnSuccessListener(main){codes->if(!closed.get())gate.accept(codes.firstOrNull {it.format==Barcode.FORMAT_QR_CODE&&it.rawValue!=null}?.rawValue)?.let {if(!closed.get())onCode(it)}}
    .addOnFailureListener(main){if(!closed.get())onError()}
    .addOnCompleteListener {proxy.close()}
  }catch(_:Exception){proxy.close();main.execute {if(!closed.get())onError()}}
 }
 fun close(){if(!closed.compareAndSet(false,true))return;gate.close();runCatching {analysis.clearAnalyzer();provider?.unbind(preview,analysis)};runCatching {detector.close()};worker.shutdown()}
}
