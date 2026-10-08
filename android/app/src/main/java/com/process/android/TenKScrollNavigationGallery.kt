package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable fun TenKScrollNavigationGallery(onBack:()->Unit) {
 val scroll=rememberScrollState();var tab by remember {mutableIntStateOf(0)};val names=listOf("For You","Products","More","Bag","Search")
 val icons=listOf(Icons.Default.Favorite,Icons.Default.Phone,Icons.Default.MoreVert,Icons.Default.ShoppingCart,Icons.Default.Search)
 val dark=isSystemInDarkTheme();val bg=if(dark)Color.Black else Color.White;val fg=if(dark)Color.White else Color.Black
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(bg)) {
  Row(Modifier.padding(horizontal=15.dp),verticalAlignment=Alignment.CenterVertically){Text("Apple Store scroll",Modifier.weight(1f),fontSize=24.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  TenKScrollAwareNavigation(scroll,Modifier.weight(1f).fillMaxWidth(),contextKey=tab,navigation={
   Column(Modifier.fillMaxWidth().background(bg.copy(alpha=.97f)).padding(horizontal=15.dp,vertical=8.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
    Text("Original demo offer: From $899, get 10% off on your first purchase!\nUse code: WELCOME10",Modifier.fillMaxWidth(),fontSize=12.sp,lineHeight=16.sp,color=fg,textAlign=androidx.compose.ui.text.style.TextAlign.Center)
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly){names.forEachIndexed {index,name->Column(Modifier.weight(1f).clip(RoundedCornerShape(20.dp)).selectable(tab==index,role=Role.Tab){tab=index}.padding(vertical=8.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(3.dp)) {
     val tint=if(tab==index)Color(0xFF007AFF)else Color.Gray
     Icon(icons[index],null,Modifier.size(24.dp),tint=tint);Text(name,fontSize=10.sp,color=tint,letterSpacing=0.sp)
    }}}
   }
  }) {
   if(tab==0)Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(15.dp).padding(bottom=125.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){repeat(50){i->Box(Modifier.fillMaxWidth().height(50.dp).background(fg.copy(alpha=.08f)),contentAlignment=Alignment.Center){Text("${i+1}",color=fg)}}}
   else Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Text(names[tab],color=fg)}
  }
 }
}
