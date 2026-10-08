package com.process.android

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

/** Original BackdropCarousel by Balaji Venkatesh, 3 January 2025. */
data class BackdropCarouselImage(val id:String,val resource:Int,val description:String)
@Composable fun TenKBackdropCarousel(
    images:List<BackdropCarouselImage>,modifier:Modifier=Modifier,contextKey:Any="default",
    onSelection:(String)->Unit={},header:@Composable ()->Unit={}
) {
    require(images.map {it.id}.distinct().size==images.size){"Image IDs must be unique"}
    val selection by rememberUpdatedState(onSelection)
    key(contextKey,images.map {it.id}) {
        val pager=rememberPagerState(pageCount={images.size});val scroll=rememberScrollState()
        LaunchedEffect(pager) {snapshotFlow{pager.settledPage}.collect {page->images.getOrNull(page)?.let {selection(it.id)}}}
        Box(modifier.background(Brush.verticalGradient(listOf(Color.Black,Color(0xFF262626))))) {
            val progress=CarouselGeometry.progress(pager.currentPage,pager.currentPageOffsetFraction,images.size)
            // Original reverses the stack: the outgoing image fades over the incoming image.
            Box(Modifier.fillMaxWidth().height(555.dp).offset(y=(-scroll.value/ androidx.compose.ui.platform.LocalDensity.current.density).dp)
                .clipToBounds()
                .drawWithContent {drawContext.canvas.saveLayer(androidx.compose.ui.geometry.Rect(androidx.compose.ui.geometry.Offset.Zero,size),Paint());drawContent();drawRect(Brush.verticalGradient(0f to Color.Black,.2f to Color.Black,.4f to Color.Black,.6f to Color.Black,.8f to Color.Black.copy(alpha=.5f),1f to Color.Transparent),blendMode=BlendMode.DstIn);drawContext.canvas.restore()}) {
                Box(Modifier.fillMaxSize().blur(30.dp)) {
                    images.indices.reversed().forEach {i->Image(painterResource(images[i].resource),null,Modifier.fillMaxSize().graphicsLayer{alpha=CarouselGeometry.backdropOpacity(i,progress)},contentScale=ContentScale.Crop)}
                }
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.25f)))
            }
            Column(Modifier.fillMaxWidth().verticalScroll(scroll).padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
                Box(Modifier.fillMaxWidth().height(85.dp)){header()}
                if(images.isNotEmpty())HorizontalPager(pager,Modifier.fillMaxWidth().height(380.dp),pageSpacing=6.dp,key={images[it].id}) {i->
                    Image(painterResource(images[i].resource),images[i].description,Modifier.fillMaxSize().shadow(5.dp,RoundedCornerShape(10.dp)).clip(RoundedCornerShape(10.dp)),contentScale=ContentScale.Crop)
                }
            }
        }
    }
}
