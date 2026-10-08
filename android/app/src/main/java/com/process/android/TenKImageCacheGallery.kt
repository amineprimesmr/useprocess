package com.process.android
import android.graphics.BitmapFactory
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKImageCacheGallery(onBack:()->Unit) {
 val context=LocalContext.current;val density=LocalDensity.current
 val cache=remember(context){TenKImageCache(context.cacheDir,"original-catalog-preview")};val photos=remember(context){listOf(R.drawable.cache_pic1,R.drawable.cache_pic2,R.drawable.cache_pic3).map {BitmapFactory.decodeResource(context.resources,it)}}
 val dark=isSystemInDarkTheme();val bg=if(dark)Color.Black else Color(0xFFF2F2F7);val fg=if(dark)Color.White else Color.Black
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(bg).padding(15.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
  Row(verticalAlignment=Alignment.CenterVertically){Text("Downsized Image View",Modifier.weight(1f),fontSize=28.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  Row(Modifier.fillMaxWidth().background(if(dark)Color(0xFF1C1C1E)else Color.White,RoundedCornerShape(12.dp)).padding(15.dp),horizontalArrangement=Arrangement.spacedBy(8.dp)) {
   photos.forEachIndexed {index,bitmap->BoxWithConstraints(Modifier.weight(1f).height(150.dp)) {
    val size=with(density){IntSize(maxWidth.roundToPx(),150.dp.roundToPx())}
    TenKDownsizedImage("Pic${index+1}","original-archive-2024",bitmap,size,cache,Modifier.fillMaxSize()) {Image(it,"Original picture ${index+1}",Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)),contentScale=ContentScale.Crop)}
   }}
  }
 }
}
