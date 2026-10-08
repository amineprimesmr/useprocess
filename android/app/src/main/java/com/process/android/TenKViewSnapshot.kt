package com.process.android
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.*
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.window.DialogWindowProvider
import kotlinx.coroutines.*
import kotlin.coroutines.resumeWithException
import kotlin.math.roundToInt

enum class ViewSnapshotMethod { WINDOW_PIXELS,SOFTWARE_VIEW }
data class ViewSnapshotImage(val bitmap:Bitmap,val visibleBounds:Rect,val method:ViewSnapshotMethod)
/** Each trigger change requests one capture; initial composition never captures. Returned bitmap belongs to host. */
@Composable fun TenKViewSnapshot(
 trigger:Boolean,onComplete:(ViewSnapshotImage)->Unit,onError:(Throwable)->Unit,modifier:Modifier=Modifier,
 contextKey:Any=Unit,method:ViewSnapshotMethod=ViewSnapshotMethod.WINDOW_PIXELS,content:@Composable ()->Unit,
) {
 val view=LocalView.current
 var bounds by remember {mutableStateOf<Rect?>(null)};val latestBounds by rememberUpdatedState(bounds)
 var previous by remember(contextKey){mutableStateOf(trigger)}
 val complete by rememberUpdatedState(onComplete);val failure by rememberUpdatedState(onError)
 LaunchedEffect(trigger,contextKey,method,view) {
  if(previous==trigger)return@LaunchedEffect;previous=trigger
  try {
   withFrameNanos {it}
   val window=view.snapshotWindow()?:error("No attached host window")
   check(window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE==0){"Secure windows cannot be captured"}
   check(view.isAttachedToWindow){"Snapshot view is detached"}
   val requested=latestBounds?:error("Snapshot view is not measured")
   val decor=window.decorView
   val crop=snapshotVisibleRect(requested.left,requested.top,requested.right,requested.bottom,decor.width,decor.height)?:error("Snapshot bounds are empty or too large")
   val rect=Rect(crop.left,crop.top,crop.right,crop.bottom)
   val result=when(method) {
    ViewSnapshotMethod.WINDOW_PIXELS->withTimeout(1500){copySnapshotWindow(window,rect)}
    ViewSnapshotMethod.SOFTWARE_VIEW->{val bitmap=Bitmap.createBitmap(crop.width,crop.height,Bitmap.Config.ARGB_8888);try {val origin=IntArray(2);decor.getLocationInWindow(origin);Canvas(bitmap).apply {translate((origin[0]-crop.left).toFloat(),(origin[1]-crop.top).toFloat());decor.draw(this)};bitmap}catch(e:Throwable){bitmap.recycle();throw e}}
   }
   if(!isActive){result.recycle();ensureActive()}
   complete(ViewSnapshotImage(result,rect,method))
  }catch(error:TimeoutCancellationException){ensureActive();failure(IllegalStateException("Snapshot timed out",error))}catch(error:CancellationException){throw error}catch(error:Exception){ensureActive();failure(error)}
 }
 Box(modifier.onGloballyPositioned {c->val b=c.boundsInWindow();bounds=Rect(b.left.roundToInt(),b.top.roundToInt(),b.right.roundToInt(),b.bottom.roundToInt())}){content()}
}
@OptIn(ExperimentalCoroutinesApi::class)
private suspend fun copySnapshotWindow(window:Window,rect:Rect):Bitmap=suspendCancellableCoroutine {continuation->
 val bitmap=Bitmap.createBitmap(rect.width(),rect.height(),Bitmap.Config.ARGB_8888)
 try {PixelCopy.request(window,rect,bitmap,{result->
  if(!continuation.isActive)bitmap.recycle()
  else if(result==PixelCopy.SUCCESS)continuation.resume(bitmap,onCancellation={bitmap.recycle()})
  else {bitmap.recycle();continuation.resumeWithException(IllegalStateException("PixelCopy failed: $result"))}
 },Handler(Looper.getMainLooper()))}catch(error:Exception){bitmap.recycle();if(continuation.isActive)continuation.resumeWithException(error)}
}
private fun View.snapshotWindow():Window? {
 var ancestor:ViewParent?=parent
 while(ancestor!=null){if(ancestor is DialogWindowProvider)return ancestor.window;ancestor=ancestor.parent}
 return context.snapshotActivity()?.window
}
private fun Context.snapshotActivity():Activity?=when(this){is Activity->this;is ContextWrapper->if(baseContext===this)null else baseContext.snapshotActivity();else->null}
