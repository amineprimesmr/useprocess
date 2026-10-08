package com.process.android
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.launch
@Composable fun TenKTimedPagingGallery(onBack:()->Unit) {
 val pager=rememberPagerState {5};val dragging by pager.interactionSource.collectIsDraggedAsState();var manualPaused by remember {mutableStateOf(false)}
 var automaticScroll by remember {mutableStateOf(false)}
 val scope=rememberCoroutineScope();val colors=listOf(Color(0xFFFF3B30),Color(0xFF007AFF),Color(0xFF34C759),Color(0xFFFFCC00),Color(0xFFAF52DE))
 val dark=isSystemInDarkTheme();val surface=if(dark)Color(0xFF1C1C1E)else Color.White;val fg=if(dark)Color.White else Color.Black
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(if(dark)Color.Black else Color(0xFFF2F2F7)).padding(15.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
  Row(verticalAlignment=Alignment.CenterVertically){Text("Timed Indicators",Modifier.weight(1f),fontSize=30.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  Text("DEMO",fontSize=12.sp,color=Color.Gray)
  Column(Modifier.fillMaxWidth().background(surface,RoundedCornerShape(25.dp)).padding(vertical=20.dp),verticalArrangement=Arrangement.spacedBy(15.dp),horizontalAlignment=Alignment.CenterHorizontally) {
   HorizontalPager(pager,Modifier.height(220.dp),contentPadding=PaddingValues(horizontal=20.dp),pageSpacing=10.dp) {index->Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(colors[index].copy(alpha=.8f),colors[index])),RoundedCornerShape(30.dp)))}
   TenKTimedPagingIndicator(5,2000,manualPaused||dragging||(pager.isScrollInProgress&&!automaticScroll),pager.settledPage,{next->scope.launch {automaticScroll=true;try {pager.animateScrollToPage(next,animationSpec=tween(300))} finally {automaticScroll=false}}},activeTint=fg,inactiveTint=Color.Gray.copy(alpha=.6f))
  }
  Text("OPTIONS",fontSize=12.sp,color=Color.Gray)
  Row(Modifier.fillMaxWidth().background(surface,RoundedCornerShape(25.dp)).padding(horizontal=15.dp,vertical=10.dp),verticalAlignment=Alignment.CenterVertically){Text("Paused",Modifier.weight(1f),color=fg);Switch(manualPaused,{manualPaused=it})}
 }
}
