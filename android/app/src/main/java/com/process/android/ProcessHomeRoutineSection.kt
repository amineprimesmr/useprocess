package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.snapping.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
@Composable internal fun ProcessHomeRoutineSection(snapshot:ProcessHomeSnapshot,onOpenExercise:(RoutineStep)->Unit,onStartRoutine:(String)->Unit,onComplete:(RoutineCompletion)->Unit,english:Boolean,reduceMotion:Boolean) {
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val latest by rememberUpdatedState(snapshot);val list=rememberLazyListState()
 Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
  Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
   Text(if(english)"Lymphatic circuit"else"Circuit lymphatique",Modifier.weight(1f),fontSize=17.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=p.primary)
   Box(Modifier.clip(CircleShape).background(p.primary).clickable {if(latest.contextKey==snapshot.contextKey)onStartRoutine(snapshot.contextKey)}.padding(horizontal=12.dp,vertical=6.dp)){Text(if(english)"▶ Start"else"▶ Lancer",fontSize=14.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.background)}
  }
  LazyRow(state=list,flingBehavior=rememberSnapFlingBehavior(list,snapPosition=SnapPosition.Start),horizontalArrangement=Arrangement.spacedBy(12.dp),contentPadding=PaddingValues(vertical=8.dp),modifier=Modifier.height(288.dp)) {
   items(ProcessRoutineCatalog.steps,key={it.id}) {step->
    val context=LocalContext.current;val image=remember(step.imageResource){context.resources.getIdentifier(step.imageResource,"drawable",context.packageName)}
    ProcessRoutineHoldCard(step.title(english),step.id in snapshot.completedRoutineIds,true,{onOpenExercise(step)},{if(latest.contextKey==snapshot.contextKey&&step.id !in latest.completedRoutineIds)onComplete(RoutineCompletion(snapshot.contextKey,step.id))},english=english,reduceMotion=reduceMotion) {
     Box(Modifier.size(156.dp,272.dp).clip(RoundedCornerShape(22.dp)).background(p.card)) {
      if(image!=0)Image(painterResource(image),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop,alignment=Alignment.TopCenter)
      Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent,Color.Black.copy(alpha=.1f),Color.Black.copy(alpha=.85f)))))
      Text(step.durationLabel,fontSize=11.sp,fontWeight=FontWeight.Bold,color=Color.White,modifier=Modifier.align(Alignment.TopEnd).padding(10.dp).background(Color.Black.copy(alpha=.45f),CircleShape).padding(horizontal=8.dp,vertical=4.dp))
      Text(step.title(english),fontSize=15.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=Color.White,modifier=Modifier.align(Alignment.BottomStart).padding(horizontal=12.dp).padding(bottom=14.dp))
     }
    }
   }
  }
 }
}
