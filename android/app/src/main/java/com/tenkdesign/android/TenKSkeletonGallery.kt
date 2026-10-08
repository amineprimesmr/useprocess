package com.tenkdesign.android

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.process.android.R

/** Original Skeleton sample (12–13/04/25). Card values are sample content from the catalog. */
@Composable
fun TenKSkeletonGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    var loaded by remember {mutableStateOf(false)}
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
        Row(verticalAlignment=Alignment.CenterVertically) {
            Text("Skeleton Effect",fontSize=28.sp,fontWeight=FontWeight.Bold,modifier=Modifier.weight(1f))
            TextButton(onClick={loaded=!loaded}) {Text("Tap")}
        }
        Crossfade(loaded,animationSpec=tween(if(reduceMotion)0 else 500),label="skeletonCardLoad") {ready ->
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).background(MaterialTheme.colorScheme.surface),verticalArrangement=Arrangement.spacedBy(15.dp)) {
                if(ready) Image(painterResource(R.drawable.skeleton_wwdc),null,Modifier.fillMaxWidth().height(220.dp),contentScale=ContentScale.Crop)
                else TenKSkeleton(Modifier.fillMaxWidth().height(220.dp),shape=RoundedCornerShape(0.dp),reduceMotion=reduceMotion)
                Column(Modifier.padding(horizontal=15.dp).padding(top=15.dp,bottom=25.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
                    if(ready) Text("World Wide Developer Conference 2025",fontWeight=FontWeight.SemiBold)
                    else TenKSkeleton(Modifier.fillMaxWidth().height(20.dp),reduceMotion=reduceMotion)
                    if(ready) Text("From June 9th 2025",fontSize=16.sp,color=MaterialTheme.colorScheme.onSurfaceVariant,modifier=Modifier.padding(end=30.dp))
                    else TenKSkeleton(Modifier.fillMaxWidth().padding(end=30.dp).height(15.dp),reduceMotion=reduceMotion)
                    if(ready) Text("Be there for the reveal of the latest Apple tools, frameworks, and features. Learn to elevate your apps and games through video sessions hosted by Apple engineers and designers.",fontSize=12.sp,color=Color.Gray,maxLines=3,modifier=Modifier.height(50.dp))
                    else TenKSkeleton(Modifier.fillMaxWidth().height(50.dp),reduceMotion=reduceMotion)
                }
            }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).background(MaterialTheme.colorScheme.surface).padding(15.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            if(loaded) Box(Modifier.size(60.dp).clip(CircleShape).background(Brush.verticalGradient(listOf(Color(.4f,.35f,.95f),Color(.3f,.25f,.75f)))),contentAlignment=Alignment.Center) {Text("K",fontSize=28.sp,fontWeight=FontWeight.Bold,color=Color.White)}
            else TenKSkeleton(Modifier.size(60.dp),shape=CircleShape,reduceMotion=reduceMotion)
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                if(loaded) {Text("TenK",fontSize=20.sp,fontWeight=FontWeight.Bold);Text("Hello </> from SwiftUI!",fontSize=16.sp,color=Color.Gray)}
                else {TenKSkeleton(Modifier.fillMaxWidth().height(15.dp),reduceMotion=reduceMotion);TenKSkeleton(Modifier.fillMaxWidth().padding(end=50.dp).height(15.dp),reduceMotion=reduceMotion)}
            }
        }
    }
}
