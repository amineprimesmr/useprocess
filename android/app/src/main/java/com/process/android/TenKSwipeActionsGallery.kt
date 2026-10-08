package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKSwipeActionsGallery(onBack:()->Unit) {
 val coordinator=rememberSwipeActionCoordinator("original-messages");val dark=isSystemInDarkTheme();val bg=if(dark)Color(0xFF1C1C1E)else Color.White;val fg=if(dark)Color.White else Color.Black
 var lastAction by remember {mutableStateOf("")}
 val names=listOf("iJustine","Jenna Ezarik","Emily","Juliet","Rebeca");val messages=listOf("Hi TenK !!!","Nothing!","Binge Watching","404 Page not Found","Do not Disturb.");val images=listOf(R.drawable.swipe_pic1,R.drawable.swipe_pic2,R.drawable.swipe_pic3,R.drawable.swipe_pic4,R.drawable.swipe_pic5)
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(bg)) {
  Row(Modifier.padding(15.dp),verticalAlignment=Alignment.CenterVertically){Text("Custom Swipe Actions",Modifier.weight(1f),fontSize=28.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  Column(Modifier.fillMaxSize().background(Color.Gray.copy(alpha=.1f)).verticalScroll(rememberScrollState()).padding(15.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
   Text("Messages",fontSize=11.sp,color=Color.Gray)
   names.forEachIndexed {index,name->
    TenKSwipeActions("message:$index",coordinator,listOf(
     TenKSwipeAction("share","Partager $name",Color(0xFF007AFF),onAction={lastAction="Aperçu : partager $name";true}){SwipeTransferGlyph(false)},
     TenKSwipeAction("archive","Archiver $name",Color(0xFFAF52DE),onAction={lastAction="Aperçu : archiver $name";false}){SwipeTransferGlyph(true)},
     TenKSwipeAction("delete","Supprimer $name",Color(0xFFFF3B30),onAction={lastAction="Aperçu : supprimer $name";false}){Icon(Icons.Default.Delete,null,Modifier.size(20.dp))}
    ),Modifier.fillMaxWidth()) {
     Row(Modifier.fillMaxWidth().background(bg,RoundedCornerShape(10.dp)).padding(horizontal=15.dp,vertical=12.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
      Image(painterResource(images[index]),null,Modifier.size(45.dp).clip(CircleShape),contentScale=ContentScale.Crop)
      Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)){Text(name,fontSize=16.sp,letterSpacing=0.sp,color=fg);Text(messages[index],fontSize=11.sp,letterSpacing=0.sp,color=Color.Gray)}
      Icon(Icons.Default.KeyboardArrowRight,null,Modifier.size(12.dp),tint=Color.Gray)
     }
    }
   }
   Text("Aperçu avec les portraits originaux. Aucun message envoyé, archivé ou supprimé.",fontSize=12.sp,color=Color.Gray)
   if(lastAction.isNotEmpty())Text(lastAction,color=fg)
  }
 }
}

@Composable private fun SwipeTransferGlyph(down:Boolean) {
 Canvas(Modifier.size(20.dp)) {
  val w=size.width;val h=size.height;val stroke=1.8.dp.toPx()
  drawRoundRect(Color.White,androidx.compose.ui.geometry.Offset(w*.15f,h*.45f),androidx.compose.ui.geometry.Size(w*.7f,h*.5f),androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()),style=androidx.compose.ui.graphics.drawscope.Stroke(stroke))
  val tip=if(down)h*.68f else h*.05f;val tail=if(down)h*.05f else h*.65f;val side=if(down)tip-h*.23f else tip+h*.23f
  drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*.5f,tail),androidx.compose.ui.geometry.Offset(w*.5f,tip),stroke)
  drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*.28f,side),androidx.compose.ui.geometry.Offset(w*.5f,tip),stroke)
  drawLine(Color.White,androidx.compose.ui.geometry.Offset(w*.72f,side),androidx.compose.ui.geometry.Offset(w*.5f,tip),stroke)
 }
}
