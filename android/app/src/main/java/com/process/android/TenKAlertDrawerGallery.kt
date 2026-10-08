package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKAlertDrawerGallery(onBack:()->Unit) {
 val state=rememberAlertDrawerState("original-alert");var center by remember {mutableStateOf(false)};val dark=isSystemInDarkTheme();val bg=if(dark)Color(0xFF1C1C1E)else Color.White;val fg=if(dark)Color.White else Color.Black
 TenKAlertDrawer(state,"Continue","Cancel",{false},{true},Modifier.safeDrawingPadding().background(bg),drawerContent={
  Column(verticalArrangement=Arrangement.spacedBy(15.dp)) {
   Icon(Icons.Default.Info,null,Modifier.size(34.dp),tint=Color(0xFFFF3B30))
   Text("Are you sure?",fontSize=22.sp,fontWeight=FontWeight.Bold,color=fg)
   Text("You haven't backed up your wallet yet.\nIf you remove it, you could lose access forever. We suggest tapping Cancel and backing up your wallet first with a valid recovery method.",fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,color=Color.Gray)
  }
 }) {
  Column(Modifier.fillMaxSize().padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
   Row(verticalAlignment=Alignment.CenterVertically){Text("Alert Drawer",Modifier.weight(1f),fontSize=34.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
   Row(Modifier.fillMaxWidth().background(Color.Gray.copy(alpha=.1f),RoundedCornerShape(10.dp)).padding(15.dp),verticalAlignment=Alignment.CenterVertically){Text("Move to Center",Modifier.weight(1f),color=fg);Switch(center,{center=it})}
   Text("Original demonstration text. No wallet is connected and no data can be removed.",fontSize=12.sp,color=Color.Gray)
   if(!center)Spacer(Modifier.weight(1f))
   TenKDrawerSourceButton("Continue",state,Modifier.fillMaxWidth())
  }
 }
}
