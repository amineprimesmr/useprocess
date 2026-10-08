package com.process.android

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

/** Active Type 3 from ScrollInteraction, Balaji Venkatesh, 9 October 2024. */
data class ScrollInteractionImage(val id:String,val resource:Int,val description:String)
@Composable fun TenKScrollInteraction(images:List<ScrollInteractionImage>,modifier:Modifier=Modifier,contextKey:Any="default",reduceMotion:Boolean=false,onSelection:(String)->Unit={}) {
    require(images.map {it.id}.distinct().size==images.size){"Image IDs must be unique"}
    val selection by rememberUpdatedState(onSelection)
    key(contextKey,images.map {it.id}) {
        val pager=rememberPagerState(pageCount={images.size});val density=LocalDensity.current
        LaunchedEffect(pager){snapshotFlow{pager.settledPage}.collect {images.getOrNull(it)?.let {image->selection(image.id)}}}
        BoxWithConstraints(modifier.height(330.dp)) {
            if(images.isNotEmpty())HorizontalPager(pager,Modifier.fillMaxSize(),pageSize=PageSize.Fixed(220.dp),pageSpacing=12.dp,contentPadding=PaddingValues(horizontal=((maxWidth-220.dp)/2).coerceAtLeast(0.dp)),beyondViewportPageCount=2,key={images[it].id}) {i->
                val relative=i-pager.currentPage-pager.currentPageOffsetFraction
                val transform=CarouselGeometry.scrollTransform(relative*232f,relative,reduceMotion)
                Image(painterResource(images[i].resource),images[i].description,Modifier.fillMaxSize().zIndex(-i.toFloat())
                    .graphicsLayer {
                        transformOrigin=TransformOrigin(.5f,1f);scaleX=transform.scale;scaleY=transform.scale
                        translationX=with(density){transform.translationX.dp.toPx()};translationY=with(density){transform.translationY.dp.toPx()}
                    }.graphicsLayer{transformOrigin=TransformOrigin(1f,1f);rotationZ=transform.rotation}
                    .blur(transform.blur.dp).clip(RoundedCornerShape(25.dp)),contentScale=ContentScale.Crop)
            }
        }
    }
}
