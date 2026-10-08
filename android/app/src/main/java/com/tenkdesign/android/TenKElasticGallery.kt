package com.tenkdesign.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKElasticGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var selected by remember {mutableStateOf("Play")}
 Column(modifier.padding(15.dp),verticalArrangement=Arrangement.spacedBy(25.dp)) {
  Text("Demo",color=Color.Gray)
  TenKElasticSegmentedControl(listOf("Play","News","Library","Search"),selected,{selected=it},reduceMotion=reduceMotion){Text(it,fontSize=16.sp,lineHeight=21.sp,letterSpacing=0.sp,fontWeight=FontWeight.Medium)}
 }
}
