package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKAnimatedConfirmationGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var result by remember {mutableStateOf<ConfirmationResult?>(null)}
 Column(modifier.fillMaxSize().padding(15.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
  Text("Animated Delete Button",fontSize=26.sp,lineHeight=32.sp)
  Text("Démonstration — aucune donnée supprimée",color=Color.Gray)
  TenKAnimatedConfirmationButton({result=it},reduceMotion=reduceMotion,label={Text("Delete Account?",Modifier.fillMaxWidth().background(Color.Red).padding(vertical=11.dp),color=Color.White,textAlign=androidx.compose.ui.text.style.TextAlign.Center)}) {
   Column(verticalArrangement=Arrangement.spacedBy(15.dp),modifier=Modifier.padding(bottom=10.dp)) {
    Text("ⓘ",fontSize=32.sp,color=Color.Red)
    Text("Are you sure?",fontSize=22.sp,lineHeight=27.sp,fontWeight=FontWeight.Bold)
    Text("Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s.",color=Color.Gray)
   }
  }
  result?.let {Text(if(it==ConfirmationResult.CONFIRMED)"Confirmation reçue — aucune suppression"else"Annulé")}
 }
}
