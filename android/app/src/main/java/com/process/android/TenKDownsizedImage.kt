package com.process.android
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream

internal fun downsizedDimensions(width:Int,height:Int,target:IntSize):IntSize {
 require(width>0&&height>0&&target.width>0&&target.height>0)
 val scale=minOf(target.width.toDouble()/width,target.height.toDouble()/height)
 return IntSize((width*scale).toInt().coerceAtLeast(1),(height*scale).toInt().coerceAtLeast(1))
}
/** Source revision must change when source bytes change; size is in physical pixels, not dp. */
@Composable fun TenKDownsizedImage(
 id:String,sourceRevision:String,source:Bitmap?,size:IntSize,cache:TenKImageCache,modifier:Modifier=Modifier,
 onError:(Throwable)->Unit={},content:@Composable (ImageBitmap)->Unit,
) {
 require(size.width>0&&size.height>0&&size.width.toLong()*size.height<=16_000_000)
 val key=TenKImageCache.imageKey(id,sourceRevision,size.width,size.height)
 var rendered by remember(cache,key,source){mutableStateOf<ImageBitmap?>(null)}
 var failure by remember(cache,key,source){mutableStateOf(false)}
 val report by rememberUpdatedState(onError)
 LaunchedEffect(cache,key,source) {
  try {
   val bitmap=withContext(Dispatchers.IO) {
    val bytes=cache.get(key)
    val cached=bytes?.let {
     val bounds=BitmapFactory.Options().apply {inJustDecodeBounds=true};BitmapFactory.decodeByteArray(it,0,it.size,bounds)
     if(bounds.outWidth in 1..size.width&&bounds.outHeight in 1..size.height)BitmapFactory.decodeByteArray(it,0,it.size)else null
    }
    if(cached!=null)return@withContext cached
    if(bytes!=null)cache.remove(key)
    val original=source?:throw IllegalArgumentException("Image source unavailable")
    check(!original.isRecycled)
    val dimensions=downsizedDimensions(original.width,original.height,size)
    val resized=withContext(Dispatchers.Default){Bitmap.createScaledBitmap(original,dimensions.width,dimensions.height,true)}
    currentCoroutineContext().ensureActive()
    val encoded=ByteArrayOutputStream().use {stream->check(resized.compress(if(resized.hasAlpha())Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG,100,stream));stream.toByteArray()}
    currentCoroutineContext().ensureActive();cache.put(key,encoded,1)
    resized
   }
   ensureActive();rendered=bitmap.asImageBitmap()
  }catch(error:CancellationException){throw error}catch(error:Exception){ensureActive();failure=true;report(error)}
 }
 Box(modifier,contentAlignment=Alignment.Center) {
  rendered?.let {content(it)}?:if(failure)Text("Image unavailable")else CircularProgressIndicator()
 }
}
