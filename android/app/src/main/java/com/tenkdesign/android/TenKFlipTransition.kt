package com.tenkdesign.android

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.roundToInt

/** Long-press > Edit reproduces the original trigger. PixelCopy snapshots the actual source.
 * Native Compose surface replaces Apple liquid glass; spring/perspective require comparison.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TenKFlipTransition(
    activity:Activity,
    modifier:Modifier=Modifier,
    sourceCornerRadius:Float=20f,
    destinationCornerRadius:Float=35f,
    contextMenuTitle:String="Edit",
    sourceBackground:Color=MaterialTheme.colorScheme.surfaceContainer,
    reduceMotion:Boolean=false,
    onCaptureFailure:(Throwable)->Unit,
    contextActions:@Composable ColumnScope.()->Unit={},
    content:@Composable ()->Unit,
    destination:@Composable (dismiss:()->Unit)->Unit,
) {
    val scope=rememberCoroutineScope()
    val density=LocalDensity.current.density
    var sourceBounds by remember {mutableStateOf<Rect?>(null)}
    var capturedBounds by remember {mutableStateOf(FlipRect(0f,0f,1f,1f))}
    var menu by remember {mutableStateOf(false)}
    var opening by remember {mutableStateOf(false)}
    var closing by remember {mutableStateOf(false)}
    var presented by remember {mutableStateOf(false)}
    var image by remember {mutableStateOf<Bitmap?>(null)}
    var operation by remember {mutableStateOf<Job?>(null)}
    val progress=remember {Animatable(0f)}
    val rotation=remember {Animatable(0f)}
    val captureFailure by rememberUpdatedState(onCaptureFailure)
    val animation=if(reduceMotion)tween<Float>(0)else spring(dampingRatio=.9f,stiffness=194.955f)
    fun dismiss() {
        if(!presented || closing)return
        closing=true
        operation?.cancel()
        operation=scope.launch {
            coroutineScope {
                launch {progress.animateTo(0f,animation)}
                launch {rotation.animateTo(360f,animation)}
            }
            presented=false;image=null;opening=false;closing=false
        }
    }
    fun open() {
        if(opening||presented)return
        val bounds=sourceBounds ?: return
        if(bounds.width()<=0||bounds.height()<=0)return
        menu=false;opening=true;closing=false
        operation=scope.launch {
            try {
                image=captureSource(activity,bounds)
                capturedBounds=FlipRect(bounds.left/density,bounds.top/density,bounds.width()/density,bounds.height()/density)
                delay(if(reduceMotion)0 else FlipTransitionModel.MENU_SETTLE_MILLIS)
                progress.snapTo(0f);rotation.snapTo(0f);presented=true
                coroutineScope {
                    launch {progress.animateTo(1f,animation)}
                    launch {rotation.animateTo(180f,animation)}
                }
                opening=false
            } catch(cancelled:CancellationException) {throw cancelled}
            catch(error:Exception) {opening=false;image=null;captureFailure(error)}
        }
    }
    Box(modifier.onGloballyPositioned {coordinates ->
        val bounds=coordinates.boundsInWindow()
        sourceBounds=Rect(bounds.left.roundToInt(),bounds.top.roundToInt(),bounds.right.roundToInt(),bounds.bottom.roundToInt())
    }) {
        Box(Modifier.graphicsLayer {alpha=if(presented)0f else 1f}
            .combinedClickable(enabled=!opening && !presented,onClick={},onLongClick={menu=true})
            .semantics {customActions=listOf(CustomAccessibilityAction(contextMenuTitle){open();true})}) {content()}
        DropdownMenu(menu,onDismissRequest={menu=false}) {
            DropdownMenuItem(text={Text(contextMenuTitle)},onClick={open()})
            contextActions()
        }
    }
    if(presented && image!=null) Dialog(onDismissRequest={dismiss()},properties=DialogProperties(usePlatformDefaultWidth=false,decorFitsSystemWindows=false)) {
        BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.35f*progress.value.coerceIn(0f,1f)))
            .clickable(interactionSource=remember{MutableInteractionSource()},indication=null){dismiss()}) {
            val target=FlipTransitionModel.target(maxWidth.value,maxHeight.value)
            val frame=FlipTransitionModel.frame(capturedBounds,target,progress.value)
            val showDestination=FlipTransitionModel.destinationVisible(progress.value)
            val shape=RoundedCornerShape(if(showDestination)destinationCornerRadius.dp else sourceCornerRadius.dp)
            Box(Modifier.offset {IntOffset((frame.x*density).roundToInt(),(frame.y*density).roundToInt())}
                .size(frame.width.dp,frame.height.dp)
                .graphicsLayer {rotationY=rotation.value;cameraDistance=8*density}
                .clip(shape).background(sourceBackground)
                .clickable(interactionSource=remember{MutableInteractionSource()},indication=null){},contentAlignment=Alignment.Center) {
                if(!showDestination) Image(image!!.asImageBitmap(),null,Modifier.fillMaxSize(),contentScale=ContentScale.Fit,alignment=Alignment.TopCenter)
                else {
                    val scale=FlipTransitionModel.destinationScale(frame,target)
                    Box(Modifier.requiredSize(target.width.dp,target.height.dp).graphicsLayer {scaleX=-scale;scaleY=scale}) {
                        destination {dismiss()}
                    }
                }
            }
        }
    }
}

private suspend fun captureSource(activity:Activity,bounds:Rect):Bitmap=suspendCancellableCoroutine {continuation ->
    val image=Bitmap.createBitmap(bounds.width(),bounds.height(),Bitmap.Config.ARGB_8888)
    try {
        PixelCopy.request(activity.window,bounds,image,{result ->
            if(!continuation.isActive)image.recycle()
            else if(result==PixelCopy.SUCCESS)continuation.resume(image)
            else {image.recycle();continuation.resumeWithException(IllegalStateException("Source capture failed ($result)"))}
        },Handler(Looper.getMainLooper()))
    } catch(error:Exception) {image.recycle();if(continuation.isActive)continuation.resumeWithException(error)}
}
