package com.tenkdesign.android

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.*

/** Source rotation/offset/stacking and reflection curve retained.
 * Compose projection approximates the original anchor-Z perspective; physical comparison pending.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TenKCoverFlow(
    itemCount:Int,
    activeIndex:Int?,
    onActiveIndexChange:(Int)->Unit,
    modifier:Modifier=Modifier,
    config:CoverFlowConfig=CoverFlowConfig(),
    reduceMotion:Boolean=false,
    content:@Composable (Int)->Unit,
) {
    if(itemCount<=0)return
    val width=config.cardWidth.coerceAtLeast(1f)
    val active=(activeIndex ?: 0).coerceIn(0,itemCount-1)
    val state=rememberLazyListState(initialFirstVisibleItemIndex=active)
    val callback by rememberUpdatedState(onActiveIndexChange)
    var emitted by remember {mutableIntStateOf(active)}
    val density=LocalDensity.current.density
    LaunchedEffect(state,itemCount) {
        snapshotFlow {
            val layout=state.layoutInfo
            val center=(layout.viewportStartOffset+layout.viewportEndOffset)/2f
            layout.visibleItemsInfo.minByOrNull {abs(it.offset+it.size/2f-center)}?.index
        }.distinctUntilChanged().collect {index ->if(index!=null && index<itemCount && index!=emitted){emitted=index;callback(index)}}
    }
    LaunchedEffect(active,itemCount) {
        if(active!=emitted) {
            emitted=active
            if(reduceMotion)state.scrollToItem(active)else state.animateScrollToItem(active)
        }
    }
    BoxWithConstraints(modifier) {
        val side=((maxWidth.value-width)/2).coerceAtLeast(0f).dp
        LazyRow(state=state,contentPadding=PaddingValues(horizontal=side),flingBehavior=rememberSnapFlingBehavior(state),modifier=Modifier.fillMaxSize()) {
            items((0 until itemCount).toList(),key={it}) {index ->
                val layer=rememberGraphicsLayer()
                val paint=remember {Paint()}
                val stops=remember(config.reflectionFade,config.reflectionDim) {
                    Array(65) {i->val p=i/64f;p to Color.White.copy(alpha=(1-p).pow(config.reflectionFade.coerceAtLeast(0f))*config.reflectionDim.coerceIn(0f,1f))}
                }
                Box(Modifier.width(width.dp).fillMaxHeight().zIndex(CoverFlowModel.zIndex(index,active))
                    .semantics {selected=index==active}
                    .graphicsLayer {
                        val layout=state.layoutInfo;val item=layout.visibleItemsInfo.firstOrNull {it.index==index}
                        val center=(layout.viewportStartOffset+layout.viewportEndOffset)/2f
                        val p=if(item!=null)(item.offset+item.size/2f-center)/(width*density)else (index-active).toFloat()
                        val t=CoverFlowModel.transform(p,config)
                        rotationY=t.rotation;transformOrigin=TransformOrigin(t.anchorX,.5f)
                        val radians=t.rotation*PI/180
                        translationX=t.offset*density-t.anchorZ*density*sin(radians).toFloat()
                        cameraDistance=width*density
                        val depth=t.anchorZ*(1-cos(radians).toFloat())
                        val projection=width/(width-depth).coerceAtLeast(width*.2f)
                        scaleX=projection;scaleY=projection;clip=false
                    }.drawWithContent {
                        layer.record {this@drawWithContent.drawContent()}
                        drawLayer(layer)
                        val gap=config.reflectionGap.coerceAtLeast(0f)*density
                        val top=size.height+gap
                        val canvas=drawContext.canvas
                        canvas.saveLayer(Rect(0f,top,size.width,top+size.height),paint)
                        translate(top=2*size.height+gap) {scale(1f,-1f,pivot=Offset.Zero){drawLayer(layer)}}
                        drawRect(Brush.verticalGradient(*stops,startY=top,endY=top+size.height),topLeft=Offset(0f,top),size=androidx.compose.ui.geometry.Size(size.width,size.height),blendMode=BlendMode.DstIn)
                        canvas.restore()
                    }) {content(index)}
            }
        }
    }
}
