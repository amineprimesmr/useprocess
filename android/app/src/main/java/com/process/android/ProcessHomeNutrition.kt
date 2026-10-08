package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlin.math.roundToInt
@Composable internal fun ProcessHomeNutrition(snapshot:ProcessHomeSnapshot,onWaterChange:(String,Int)->Unit,onOpenFood:()->Unit,tutorial:HomeTutorialState?,english:Boolean,reduceMotion:Boolean) {
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val latest by rememberUpdatedState(snapshot)
 val hydration:@Composable ()->Unit={ProcessHydrationCard(snapshot.effectiveWaterMl,{newValue->if(latest.contextKey==snapshot.contextKey)onWaterChange(snapshot.contextKey,newValue)},targetMilliliters=snapshot.targetWaterMl)}
 val meals:@Composable ()->Unit={ProcessHomeMealsCard(snapshot.meals,onOpenFood,english=english)}
 Column(verticalArrangement=Arrangement.spacedBy(18.dp)) {
  if(tutorial?.progress?.active!=true)Text(if(english)"Debloat nutrition"else"Alimentation debloat",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=p.primary,letterSpacing=0.sp)
  when(tutorial?.progress?.takeIf {it.active}?.step) {
   HomeTutorialStep.HYDRATION->HomeFocus(tutorial,HomeTutorialStep.HYDRATION,english,reduceMotion,hydration)
   HomeTutorialStep.NUTRITION->HomeFocus(tutorial,HomeTutorialStep.NUTRITION,english,reduceMotion,meals)
   else->Row(Modifier.fillMaxWidth().height(248.dp),horizontalArrangement=Arrangement.spacedBy(12.dp),verticalAlignment=Alignment.CenterVertically) {hydration();Box(Modifier.weight(1f)){meals()}}
  }
 }
}
@Composable fun ProcessHomeMealsCard(meals:List<HomeMealTile>,onOpenFood:()->Unit,modifier:Modifier=Modifier,english:Boolean=false) {
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val entries=meals.take(3);val context=LocalContext.current
 val scores=entries.mapNotNull {it.score};val average=if(scores.isNotEmpty()&&scores.size==entries.size)scores.average().roundToInt()else null
 val title=if(english)"Today's meals"else"Repas de la journée"
 Column(modifier.fillMaxWidth().height(248.dp).clip(RoundedCornerShape(26.dp)).background(p.card).clickable(role=Role.Button,onClick=onOpenFood).semantics {contentDescription=title+(average?.let {", score $it"}?:"")},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(10.dp)) {
  Text(title,fontSize=17.sp,lineHeight=21.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=p.primary,textAlign=androidx.compose.ui.text.style.TextAlign.Center,modifier=Modifier.padding(horizontal=12.dp).padding(top=12.dp))
  Box(Modifier.fillMaxWidth().height(132.dp),contentAlignment=Alignment.Center) {
   entries.forEachIndexed {index,entry->
    val image=remember(entry.imageResource){entry.imageResource?.let {context.resources.getIdentifier(it,"drawable",context.packageName)}?.takeIf {it!=0}}
    Box(Modifier.size(96.dp).offset(x=when(index){0->(-48).dp;1->0.dp;else->48.dp},y=when(index){0->10.dp;1->(-6).dp;else->14.dp}).scale(if(index==1)1.06f else .92f).zIndex(if(index==1)2f else 1f),contentAlignment=Alignment.Center) {
     if(image!=null)Image(painterResource(image),null,Modifier.fillMaxSize(),contentScale=ContentScale.Fit)else Text("✦",fontSize=28.sp,color=p.accent)
    }
   }
  }
  if(average!=null)Text("$average",fontSize=13.sp,fontWeight=FontWeight.Bold,color=p.primary,modifier=Modifier.background(p.strongCard,CircleShape).padding(horizontal=12.dp,vertical=6.dp))
 }
}
