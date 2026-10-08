package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
@Composable fun TenKQrScannerGallery(onBack:()->Unit) {
 var scanning by remember {mutableStateOf(false)};var code by remember {mutableStateOf("")};var request by remember {mutableIntStateOf(0)}
 val dark=isSystemInDarkTheme();val bg=if(dark)Color.Black else Color(0xFFF2F2F7);val fg=if(dark)Color.White else Color.Black
 Box(Modifier.fillMaxSize().background(bg)) {
  Column(Modifier.fillMaxSize().safeDrawingPadding().padding(15.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
   Row(verticalAlignment=Alignment.CenterVertically){Text("QR Scanner",Modifier.weight(1f),fontSize=34.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
   TextButton({request++;scanning=true}){Text("Show Scanner")}
   Text("Scanned Code",fontSize=12.sp,color=Color.Gray)
   Text(code,fontFamily=FontFamily.Monospace,color=fg)
  }
  if(scanning)TenKQrScanner("preview:$request",{code=it},{scanning=false})
 }
}
