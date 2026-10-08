package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKViewSnapshotGallery(onBack:()->Unit) {
 var type by remember {mutableStateOf<String?>(null)};var trigger by remember {mutableStateOf(false)};var image by remember {mutableStateOf<ViewSnapshotImage?>(null)};var error by remember {mutableStateOf("")};var tab by remember {mutableStateOf("Home")}
 val dark=isSystemInDarkTheme();val bg=if(dark)Color.Black else Color.White;val fg=if(dark)Color.White else Color.Black
 Box(Modifier.fillMaxSize().background(bg).safeDrawingPadding()) {
  Column(Modifier.fillMaxSize().padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
   Row(verticalAlignment=Alignment.CenterVertically){Text(type?:"View Snapshot",Modifier.weight(1f),fontSize=28.sp,fontWeight=FontWeight.Bold,color=fg);TextButton({if(type==null)onBack()else{type=null;image=null;error=""}}){Text("Done")}}
   if(type==null)listOf("Normal View Example","Navigation Stack Example","TabView Example").forEach {name->TextButton({type=name}){Text(name)}}
   else if(type=="Normal View Example") {
    TextButton({trigger=!trigger}){Text("Snapshot")}
    TenKViewSnapshot(trigger,{image=it},{error=it.message?:"Capture failed"},contextKey=type!!) {
     Column(Modifier.background(Brush.verticalGradient(listOf(Color(0xFFFF6259),Color(0xFFFF3B30))),RoundedCornerShape(10.dp)).padding(10.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(10.dp)) {
      Text("◎",fontSize=22.sp,color=Color.White);Text("Hello World!",color=Color.White)
     }
    }
   } else TenKViewSnapshot(trigger,{image=it},{error=it.message?:"Capture failed"},Modifier.weight(1f).fillMaxWidth(),contextKey=type!!) {
    Column(Modifier.fillMaxSize().background(bg)) {
     TextButton({trigger=!trigger}){Text("Snapshot")}
     if(type=="Navigation Stack Example")Column(Modifier.weight(1f).verticalScroll(rememberScrollState())){repeat(20){Text("List Cell ${it+1}",Modifier.fillMaxWidth().padding(15.dp),color=fg);HorizontalDivider()}}
     else {Box(Modifier.weight(1f).fillMaxWidth(),contentAlignment=Alignment.Center){Text(tab,color=fg)};Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly){listOf("Home","Search","Settings").forEach {name->TextButton({tab=name}){Text(name)}}}}
    }
   }
   if(error.isNotEmpty())Text(error,color=MaterialTheme.colorScheme.error)
  }
  image?.let {result->Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.3f)).clickable {image=null}.padding(15.dp),contentAlignment=Alignment.Center){Image(result.bitmap.asImageBitmap(),"Captured component",Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)),contentScale=ContentScale.Fit)}}
 }
}
