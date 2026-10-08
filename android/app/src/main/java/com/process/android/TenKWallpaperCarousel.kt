package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription

/** Original iOS26LSCarousel by Balaji Venkatesh, 4 September 2025. */
data class CarouselWallpaper(val id:String,val title:String,val resource:Int)
@Composable fun TenKWallpaperCarousel(
 wallpapers:List<CarouselWallpaper>,modifier:Modifier=Modifier,contextKey:Any="default",reduceMotion:Boolean=false,
 customizeLabel:String="Customize",secondaryLabel:String="Add",onSelect:(CarouselWallpaper)->Unit={},onCustomize:(CarouselWallpaper)->Unit={},onSecondary:()->Unit={}
) {
 require(wallpapers.map{it.id}.distinct().size==wallpapers.size){"Wallpaper IDs must be unique"}
 val selected by rememberUpdatedState(onSelect)
 key(contextKey,wallpapers.map{it.id}) {
  val pager=rememberPagerState(pageCount={wallpapers.size});val density=LocalDensity.current
  LaunchedEffect(pager){snapshotFlow{pager.settledPage}.collect{wallpapers.getOrNull(it)?.let(selected)}}
  BoxWithConstraints(modifier.background(Color.Black)) {
   val viewportWidth=maxWidth;val viewportHeight=maxHeight
   val cardHeight=CarouselGeometry.wallpaperHeight(viewportHeight.value).dp
   val padding=((viewportWidth-273.dp)/2).coerceAtLeast(0.dp)
   val progress=CarouselGeometry.progress(pager.currentPage,pager.currentPageOffsetFraction,wallpapers.size)
   if(wallpapers.isNotEmpty()&&cardHeight>0.dp)Column(Modifier.fillMaxSize(),verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally) {
    Box(Modifier.fillMaxWidth().height(50.dp).clipToBounds()) {
     if(reduceMotion)Text(wallpapers[pager.currentPage].title,Modifier.align(Alignment.Center),color=Color.White,fontSize=22.sp,fontWeight=FontWeight.Medium)
     else Row(Modifier.wrapContentWidth(Alignment.Start,unbounded=true).offset(x=-(viewportWidth*progress))) {
      wallpapers.forEach {Box(Modifier.width(viewportWidth).height(50.dp),contentAlignment=Alignment.Center){Text(it.title,color=Color.White,fontSize=22.sp,fontWeight=FontWeight.Medium)}}
     }
    }
    Spacer(Modifier.height(15.dp))
    HorizontalPager(pager,Modifier.fillMaxWidth().height(cardHeight),pageSize=PageSize.Fixed(273.dp),pageSpacing=15.dp,contentPadding=PaddingValues(horizontal=padding),key={wallpapers[it].id}) {i->
     Image(painterResource(wallpapers[i].resource),wallpapers[i].title,Modifier.fillMaxSize().clip(RoundedCornerShape(40.dp)),contentScale=ContentScale.Crop)
    }
    Spacer(Modifier.height(25.dp))
    // The source button background samples the same moving wallpaper strip.
    Box(Modifier.fillMaxWidth().height(60.dp)) {
     val maskWidth=285.dp;val maskLeft=(viewportWidth-maskWidth)/2+33.dp
     Box(Modifier.fillMaxSize().clipToBounds()
      .drawWithContent {
       drawContext.canvas.saveLayer(androidx.compose.ui.geometry.Rect(androidx.compose.ui.geometry.Offset.Zero,size),Paint())
       drawContent()
       val shape=Path().apply {
        addRoundRect(androidx.compose.ui.geometry.RoundRect(with(density){maskLeft.toPx()},1.9.dp.toPx(),with(density){(maskLeft+220.dp).toPx()},56.9.dp.toPx(),androidx.compose.ui.geometry.CornerRadius(27.5.dp.toPx())))
        addOval(androidx.compose.ui.geometry.Rect(with(density){(maskLeft+230.dp).toPx()},1.9.dp.toPx(),with(density){(maskLeft+285.dp).toPx()},56.9.dp.toPx()))
       }
       // Clear outside both button shapes, then apply the source vertical fade.
       val outside=Path.combine(PathOperation.Difference,Path().apply{addRect(androidx.compose.ui.geometry.Rect(androidx.compose.ui.geometry.Offset.Zero,size))},shape)
       drawPath(outside,Color.Transparent,blendMode=BlendMode.Clear)
       drawRect(Brush.verticalGradient(0f to Color.White,.33f to Color.White.copy(alpha=.5f),.67f to Color.Transparent,1f to Color.Transparent),blendMode=BlendMode.DstIn)
       drawContext.canvas.restore()
      }) {
      Row(Modifier.wrapContentSize(Alignment.TopStart,unbounded=true)
       .offset(x=padding-288.dp*progress,y=190.dp-(viewportHeight+cardHeight)/2).blur(10.dp),horizontalArrangement=Arrangement.spacedBy(15.dp)) {
       wallpapers.forEach {Image(painterResource(it.resource),null,Modifier.size(273.dp,cardHeight).clip(RoundedCornerShape(40.dp)),contentScale=ContentScale.Crop)}
      }
     }
     Row(Modifier.align(Alignment.Center).offset(x=33.dp),horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
      val current=wallpapers[pager.settledPage]
      WallpaperReflectionButton(220.dp,customizeLabel,{onCustomize(current)}){Text(customizeLabel,color=Color.White,fontWeight=FontWeight.Medium)}
      WallpaperReflectionButton(55.dp,secondaryLabel,onSecondary){Text("×",color=Color.White,fontSize=27.sp,fontWeight=FontWeight.SemiBold)}
     }
    }
   }
  }
 }
}
@Composable private fun WallpaperReflectionButton(width:Dp,label:String,onClick:()->Unit,content:@Composable BoxScope.()->Unit) {
 Box(Modifier.width(width).height(55.dp).clip(CapsuleShape).background(Color.Black).background(Color.White.copy(alpha=.05f)).border(1.dp,Color.White.copy(alpha=.1f),CapsuleShape)
  .clickable(onClick=onClick).semantics {contentDescription=label},contentAlignment=Alignment.Center,content=content)
}
private val CapsuleShape=RoundedCornerShape(50)
