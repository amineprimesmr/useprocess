package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.snapping.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.selection.*
import androidx.compose.foundation.shape.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*

/** Live DebloatFoodHubView port. All navigation and plan writes remain explicit host actions. */
@Composable fun ProcessFoodHub(
 onFood:(DebloatFood)->Unit,onRecipe:(FoodHubMeal)->Unit,onAllFoods:()->Unit,onHydration:()->Unit,onScan:()->Unit,
 modifier:Modifier=Modifier,configuredSlots:List<String> = emptyList(),todayMeals:List<ProcessRecipe> = emptyList(),
 assessmentFor:(ProcessRecipe)->RecipeAssessment?={null},english:Boolean=false,dark:Boolean=isSystemInDarkTheme(),
 avatar:(@Composable ()->Unit)?=null,
) {
 val p=ProcessSurfacePalette(dark);val haptic=LocalHapticFeedback.current
 var query by rememberSaveable {mutableStateOf("")};var selected by rememberSaveable {mutableStateOf("breakfast")}
 val slot=FoodHubModel.effectiveSlot(selected,configuredSlots)
 val foods=remember(query,english){FoodHubModel.foods(query,english)}
 fun tap(action:()->Unit){haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove);action()}
 Column(modifier.fillMaxSize().background(p.background)) {
  Column(Modifier.padding(start=20.dp,end=20.dp,top=10.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
   Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.SpaceBetween) {
    Box(Modifier.size(48.dp).clip(CircleShape).background(p.card),contentAlignment=Alignment.Center) {if(avatar!=null)avatar()else Icon(Icons.Default.Face,null,Modifier.size(18.dp),tint=p.secondary)}
    FoodHubIcon("drop",if(english)"Open hydration"else"Ouvrir l’hydratation",Modifier.size(44.dp).clip(CircleShape).background(p.card).clickable(role=Role.Button){tap(onHydration)}.padding(11.dp),tint=p.primary)
   }
   Text(if(english)"What are you craving\ntoday?"else"Qu'est-ce qu'on mange\naujourd'hui ?",color=p.primary,fontSize=24.sp,lineHeight=29.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold)
  }
  Row(Modifier.padding(start=20.dp,end=20.dp,top=20.dp,bottom=14.dp),horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
   Row(Modifier.weight(1f).background(p.card,CircleShape).padding(horizontal=16.dp,vertical=13.dp),horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
    Icon(Icons.Default.Search,null,Modifier.size(20.dp),tint=p.secondary)
    val hint=if(english)"Search a food…"else"Rechercher un aliment…"
    BasicTextField(query,{query=it},Modifier.weight(1f).semantics {contentDescription=hint},singleLine=true,textStyle=TextStyle(color=p.primary,fontSize=17.sp,lineHeight=22.sp),cursorBrush=SolidColor(p.primary),decorationBox={inner->Box {if(query.isEmpty())Text(hint,color=p.secondary,fontSize=17.sp,lineHeight=22.sp,maxLines=1);inner()}})
    if(query.isNotEmpty())FoodHubIcon("clear",if(english)"Clear search"else"Effacer la recherche",Modifier.size(20.dp).clickable(role=Role.Button){query=""},tint=p.secondary)
   }
   FoodHubIcon("camera",if(english)"Scan a food"else"Scanner un aliment",Modifier.size(48.dp).clip(CircleShape).background(p.card).clickable(role=Role.Button){tap(onScan)}.padding(14.dp),tint=p.primary)
  }
  LazyColumn(Modifier.weight(1f),contentPadding=PaddingValues(top=12.dp,bottom=40.dp),verticalArrangement=Arrangement.spacedBy(38.dp)) {
   item("foods") {
    Column(verticalArrangement=Arrangement.spacedBy(14.dp)) {
     Row(Modifier.padding(horizontal=20.dp).clickable(role=Role.Button){tap(onAllFoods)},verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(4.dp)) {
      Text(if(english)"Debloat Foods"else"Aliments Debloat",fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=p.primary)
      FoodHubIcon("chevron",null,Modifier.size(14.dp),tint=p.secondary)
     }
     val state=rememberLazyListState()
     LaunchedEffect(query){state.scrollToItem(0)}
     LazyRow(state=state,flingBehavior=rememberSnapFlingBehavior(state,SnapPosition.Start),contentPadding=PaddingValues(start=4.dp,end=20.dp),horizontalArrangement=Arrangement.spacedBy(14.dp)) {
      items(foods,key={it.id}) {food->
       Column(Modifier.width(72.dp).clickable(role=Role.Button){tap {onFood(food)}},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(68.dp).background(p.card,RoundedCornerShape(20.dp)),contentAlignment=Alignment.Center) {
         FoodHubAssets.images[food.id]?.let {Image(painterResource(it),null,Modifier.size(68.dp).padding(10.dp),contentScale=ContentScale.Fit)}?:Text(FoodHubAssets.emoji[food.id]?:when(food.category){FoodCategory.legumes->"🥦";FoodCategory.fruits->"🍎";FoodCategory.potassium->"🍌";FoodCategory.magnesium->"🌰";FoodCategory.protein->"🍳";FoodCategory.herbs->"🌿";FoodCategory.drinks->"🥤";FoodCategory.avoidSodium->"🧂";FoodCategory.avoidOther->"🍟"},fontSize=30.sp)
        }
        Text(FoodCopy.name(food,english),fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=p.secondary,textAlign=TextAlign.Center,maxLines=2,overflow=TextOverflow.Ellipsis)
       }
      }
      item("all") {Column(Modifier.width(72.dp).clickable(role=Role.Button){tap(onAllFoods)},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
       Box(Modifier.size(68.dp).background(p.card,RoundedCornerShape(20.dp)),contentAlignment=Alignment.Center) {FoodHubIcon("grid",null,tint=p.primary)}
       Text(if(english)"All\nFoods"else"Tous les\naliments",fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=p.secondary,textAlign=TextAlign.Center)
      }}
     }
     if(foods.isEmpty())Text(if(english)"No matching food"else"Aucun aliment trouvé",Modifier.padding(horizontal=20.dp),color=p.secondary,fontSize=13.sp)
    }
   }
   item("meals") {
    Column(verticalArrangement=Arrangement.spacedBy(14.dp)) {
     Row(Modifier.padding(horizontal=20.dp).horizontalScroll(rememberScrollState()).selectableGroup(),horizontalArrangement=Arrangement.spacedBy(18.dp)) {
      FoodHubModel.slots(configuredSlots).forEach {item->Text(FoodHubModel.title(item,english),Modifier.selectable(selected=item==slot,role=Role.Tab){tap {selected=item}},fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=if(item==slot)p.primary else p.secondary.copy(alpha=p.secondary.alpha*.55f))}
     }
     key(slot) {
      val state=rememberLazyListState()
      LazyRow(state=state,flingBehavior=rememberSnapFlingBehavior(state,SnapPosition.Start),contentPadding=PaddingValues(start=4.dp,end=20.dp,top=4.dp,bottom=4.dp),horizontalArrangement=Arrangement.spacedBy(12.dp)) {
       items(FoodHubModel.meals(slot,todayMeals),key={it.key}) {entry->
        Column(Modifier.size(212.dp,270.dp).clip(RoundedCornerShape(26.dp)).background(p.card).clickable(role=Role.Button){tap {onRecipe(entry)}}.padding(10.dp),verticalArrangement=Arrangement.spacedBy(10.dp),horizontalAlignment=Alignment.CenterHorizontally) {
         Box(Modifier.size(192.dp,38.dp),contentAlignment=Alignment.Center) {Text(entry.meal.name.text(english),fontSize=15.sp,lineHeight=19.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=p.primary,maxLines=2,textAlign=TextAlign.Center,overflow=TextOverflow.Ellipsis)}
         Box(Modifier.size(192.dp).clip(RoundedCornerShape(22.dp))) {
          Image(painterResource(entry.meal.imageResource),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop)
          assessmentFor(entry.meal)?.let {RecipeScorePill(it,p,Modifier.align(Alignment.BottomCenter).padding(bottom=10.dp))}
         }
        }
       }
      }
     }
    }
   }
  }
 }
}


/** Native paths approximate source SF symbols without an extended icon dependency. */
@Composable private fun FoodHubIcon(kind:String,label:String?,modifier:Modifier=Modifier,tint:Color) {
 Canvas(modifier.then(if(label!=null)Modifier.semantics {contentDescription=label} else Modifier).then(if(kind=="grid")Modifier.size(22.dp)else Modifier)) {
  scale(size.width/24f,size.height/24f,pivot=Offset.Zero) {
   val stroke=Stroke(1.8f,cap=StrokeCap.Round,join=StrokeJoin.Round)
   when(kind) {
    "drop"->drawPath(Path().apply {moveTo(12f,2f);cubicTo(11f,5f,5f,10f,5f,15f);cubicTo(5f,24f,19f,24f,19f,15f);cubicTo(19f,10f,13f,5f,12f,2f);close()},tint)
    "clear"->{drawCircle(tint,10f,Offset(12f,12f));drawLine(Color.White,Offset(8.5f,8.5f),Offset(15.5f,15.5f),1.8f,StrokeCap.Round);drawLine(Color.White,Offset(15.5f,8.5f),Offset(8.5f,15.5f),1.8f,StrokeCap.Round)}
    "camera"->{drawRoundRect(tint,Offset(3f,7f),Size(18f,13f),CornerRadius(3f),style=stroke);drawPath(Path().apply {moveTo(8f,7f);lineTo(10f,4f);lineTo(14f,4f);lineTo(16f,7f)},tint,style=stroke);drawCircle(tint,3.5f,Offset(12f,13.5f),style=stroke)}
    "chevron"->drawPath(Path().apply {moveTo(9f,4f);lineTo(16f,12f);lineTo(9f,20f)},tint,style=Stroke(3f,cap=StrokeCap.Round,join=StrokeJoin.Round))
    "grid"->for(x in listOf(3f,14f))for(y in listOf(3f,14f))drawRoundRect(tint,Offset(x,y),Size(7f,7f),CornerRadius(1.5f),style=stroke)
   }
  }
 }
}
