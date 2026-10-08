package com.tenkdesign.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

enum class ConfirmationResult {CANCELLED,CONFIRMED}
data class ConfirmationAction(val title:String="Delete",val background:Color=Color.Red,val foreground:Color=Color.White)

/** AnimatedDeleteButton, Balaji Venkatesh,31October2025. Original true means confirmed despite its isCancelled parameter name. */
@Composable fun TenKAnimatedConfirmationButton(
    onResult:(ConfirmationResult)->Unit,modifier:Modifier=Modifier,
    sourceRadius:Dp=30.dp,destinationRadius:Dp=45.dp,action:ConfirmationAction=ConfirmationAction(),
    cancelTitle:String="Cancel",accessibilityLabel:String="Open confirmation",reduceMotion:Boolean=false,
    label:@Composable ()->Unit,content:@Composable ColumnScope.()->Unit,
) {
    require(sourceRadius.value.isFinite()&&sourceRadius>=0.dp&&destinationRadius.value.isFinite()&&destinationRadius>=0.dp)
    val layer=rememberGraphicsLayer();val scope=rememberCoroutineScope();val density=LocalDensity.current
    val hardwareSnapshot=LocalView.current.isHardwareAccelerated
    var bounds by remember {mutableStateOf(Rect.Zero)};var presented by remember {mutableStateOf(false)}
    var closing by remember {mutableStateOf(false)};var measuredHeight by remember {mutableIntStateOf(0)}
    val progress=remember {Animatable(0f)};val sourceFade=remember {Animatable(0f)}
    val callback by rememberUpdatedState(onResult)
    val geometry:AnimationSpec<Float> = if(reduceMotion)snap()else tween(300,easing=CubicBezierEasing(.22f,.85f,.25f,1f))
    fun dismiss(result:ConfirmationResult) {
        if(!presented||closing)return
        closing=true
        scope.launch {
            coroutineScope {
                launch {progress.animateTo(0f,geometry)}
                launch {sourceFade.animateTo(0f,if(reduceMotion)snap()else tween(150,delayMillis=80))}
            }
            presented=false;closing=false;measuredHeight=0;callback(result)
        }
    }
    Box(modifier.onGloballyPositioned {if(!presented)bounds=it.boundsInWindow()}.graphicsLayer {alpha=if(presented)0f else 1f}.clip(RoundedCornerShape(sourceRadius)).clickable(enabled=!presented,role=Role.Button) {
        if(bounds.width>0&&bounds.height>0&&(!hardwareSnapshot||(layer.size.width>0&&layer.size.height>0))){closing=false;presented=true}
    }.semantics {contentDescription=accessibilityLabel}.drawWithContent {
        val hardware=drawContext.canvas.nativeCanvas.isHardwareAccelerated
        if(hardwareSnapshot&&hardware) {
            if(!presented)layer.record {this@drawWithContent.drawContent()}
            drawLayer(layer)
        }else drawContent()
    }) {label()}
    if(presented)Dialog(onDismissRequest={dismiss(ConfirmationResult.CANCELLED)},properties=DialogProperties(usePlatformDefaultWidth=false,decorFitsSystemWindows=false,dismissOnClickOutside=false)) {
        val dialogView=LocalView.current
        SideEffect {(dialogView.parent as? DialogWindowProvider)?.window?.let {it.setDimAmount(0f);it.setLayout(android.view.ViewGroup.LayoutParams.MATCH_PARENT,android.view.ViewGroup.LayoutParams.MATCH_PARENT)}}
        BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.4f*progress.value))) {
            val widthPx=with(density){maxWidth.toPx()-20.dp.toPx()}
            val heightPx=measuredHeight.toFloat()
            val targetLeft=with(density){10.dp.toPx()};val targetTop=with(density){maxHeight.toPx()-10.dp.toPx()}-heightPx
            val p=progress.value
            val x=bounds.center.x-widthPx/2+(targetLeft-(bounds.center.x-widthPx/2))*p
            val y=bounds.center.y-heightPx/2+(targetTop-(bounds.center.y-heightPx/2))*p
            val currentWidth=bounds.width+(widthPx-bounds.width)*p
            val currentHeight=bounds.height+(heightPx-bounds.height)*p
            val radius=with(density){sourceRadius.toPx()+(destinationRadius-sourceRadius).toPx()*p}
            Box(Modifier.width(with(density){widthPx.toDp()}).onSizeChanged {measuredHeight=it.height}.offset {IntOffset(x.roundToInt(),y.roundToInt())}.drawWithContent {
                val left=(size.width-currentWidth)/2;val top=(size.height-currentHeight)/2
                val path=Path().apply {addRoundRect(RoundRect(left,top,left+currentWidth,top+currentHeight,CornerRadius(radius)))}
                clipPath(path){this@drawWithContent.drawContent()}
            }) {
                if(hardwareSnapshot)Canvas(Modifier.matchParentSize().graphicsLayer {alpha=1f-sourceFade.value}.blur((sourceFade.value*10).dp)) {
                    if(drawContext.canvas.nativeCanvas.isHardwareAccelerated&&sourceFade.value<1f&&layer.size.width>0&&layer.size.height>0)translate((size.width-currentWidth)/2,(size.height-currentHeight)/2){scale(currentWidth/layer.size.width,currentHeight/layer.size.height,pivot=Offset.Zero){drawLayer(layer)}}
                }
                else Box(Modifier.matchParentSize().clearAndSetSemantics {}.graphicsLayer {alpha=1f-sourceFade.value}.blur((sourceFade.value*10).dp)) {
                    // Software canvases cannot draw RenderNode. Re-render the pure label slot at source size.
                    Box(Modifier.size(with(density){bounds.width.toDp()},with(density){bounds.height.toDp()}).graphicsLayer {
                        transformOrigin=TransformOrigin(0f,0f);scaleX=currentWidth/bounds.width;scaleY=currentHeight/bounds.height
                        translationX=(widthPx-currentWidth)/2;translationY=(heightPx-currentHeight)/2
                    }) {label()}
                }
                Column(Modifier.fillMaxWidth().graphicsLayer {alpha=p}.blur(((1f-p)*10).dp).background(MaterialTheme.colorScheme.background,RoundedCornerShape(destinationRadius)).padding(20.dp).then(if(p<.999f||closing)Modifier.clearAndSetSemantics {} else Modifier),verticalArrangement=Arrangement.spacedBy(10.dp)) {
                    content()
                    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
                    Row(horizontalArrangement=Arrangement.spacedBy(6.dp)) {
                        Button(onClick={dismiss(ConfirmationResult.CANCELLED)},enabled=p>=.999f&&!closing,modifier=Modifier.weight(1f),shape=CircleShape,contentPadding=PaddingValues(vertical=11.dp),colors=ButtonDefaults.buttonColors(containerColor=Color.Gray.copy(alpha=.3f),contentColor=MaterialTheme.colorScheme.onBackground)){Text(cancelTitle,fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.Medium)}
                        Button(onClick={dismiss(ConfirmationResult.CONFIRMED)},enabled=p>=.999f&&!closing,modifier=Modifier.weight(1f),shape=CircleShape,contentPadding=PaddingValues(vertical=11.dp),colors=ButtonDefaults.buttonColors(containerColor=action.background,contentColor=action.foreground)){Text(action.title,fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.Medium)}
                    }
                    }
                }
            }
            LaunchedEffect(measuredHeight) {
                if(measuredHeight>0&&!closing&&progress.value==0f)coroutineScope {
                    launch {progress.animateTo(1f,geometry)}
                    launch {sourceFade.animateTo(1f,if(reduceMotion)snap()else tween(150))}
                }
            }
        }
    }
}
