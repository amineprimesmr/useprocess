package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.*
@Composable fun TenKBorderBeamGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var enabled by remember {mutableStateOf(true)};var colors by remember {mutableStateOf(true)};var button by remember {mutableStateOf(false)}
 val palette=listOf(Color.Green,Color.Blue,Color(0xffff2d55),Color(0xffff9500),Color(0xff5856d6))
 Column(modifier.fillMaxSize().background(Color.Black).padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
  Text("Border Effect",fontSize=28.sp,lineHeight=34.sp,color=Color.White)
  listOf("Show Colors" to colors,"Enable Main Border" to enabled,"Enable Button Border" to button).forEachIndexed {index,pair->Row(verticalAlignment=Alignment.CenterVertically){Text(pair.first,Modifier.weight(1f),color=Color.White);Switch(pair.second,{when(index){0->colors=it;1->enabled=it;else->button=it}})}}
  Spacer(Modifier.height(15.dp))
  TenKBorderBeam(Modifier.fillMaxWidth().background(Color.Gray.copy(alpha=.1f),RoundedCornerShape(20.dp)),beam=if(colors)palette else emptyList(),enabled=enabled,reduceMotion=reduceMotion) {
   Column(Modifier.fillMaxWidth().padding(15.dp),verticalArrangement=Arrangement.spacedBy(25.dp)) {
    Text("Ask Anything...",Modifier.padding(top=8.dp),color=Color.Gray)
    Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
     Text("Name/Model Name",fontSize=12.sp,color=Color.White.copy(alpha=.8f),modifier=Modifier.background(Color.White.copy(alpha=.12f),CircleShape).padding(horizontal=15.dp,vertical=8.dp))
     Spacer(Modifier.weight(1f));Text("+",color=Color.White)
     TenKBorderBeam(Modifier.size(35.dp).background(Color.Black,CircleShape),beam=palette,enabled=button,reduceMotion=reduceMotion){Text("↑",color=Color.White,modifier=Modifier.align(Alignment.Center))}
    }
   }
  }
 }
}
