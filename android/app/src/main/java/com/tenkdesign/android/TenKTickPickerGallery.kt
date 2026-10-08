package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
@Composable fun TenKTickPickerGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var selection by remember {mutableIntStateOf(5)};var alignment by remember {mutableStateOf(TickAlignment.BOTTOM)}
 val ink=if(isSystemInDarkTheme())Color.White else Color.Black
 Column(modifier.fillMaxSize().padding(top=15.dp),horizontalAlignment=Alignment.CenterHorizontally) {
  Text("Tick Picker",fontSize=28.sp,lineHeight=34.sp,color=ink)
  Row(Modifier.padding(horizontal=15.dp).padding(top=20.dp,bottom=30.dp),horizontalArrangement=Arrangement.spacedBy(6.dp)) {
   TickAlignment.entries.forEach {item->FilterChip(alignment==item,{alignment=item},label={Text(item.name.lowercase().replaceFirstChar {it.uppercase()})})}
  }
  Box(Modifier.size(8.dp).background(ink.copy(alpha=.2f),CircleShape))
  TenKTickPicker(100,selection,{selection=it},config=TickPickerConfig(tickWidth=2.dp,alignment=alignment,inactiveTint=ink),reduceMotion=reduceMotion)
  Row(verticalAlignment=Alignment.Bottom,horizontalArrangement=Arrangement.spacedBy(2.dp)){Text("${50+selection}",fontFamily=FontFamily.Monospace,fontWeight=FontWeight.SemiBold,color=ink);Text("CM",fontSize=12.sp,fontFamily=FontFamily.Monospace,color=ink)}
 }
}
