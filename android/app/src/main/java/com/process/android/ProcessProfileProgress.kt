package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.selection.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.*
import java.time.*
import java.time.format.*
import java.util.Locale
import kotlin.math.roundToInt

/** Read-only visual estimates supplied by the host, not a diagnostic or scan-analysis implementation. */
@Composable fun ProcessProfileProgress(
 snapshot:ProfileSnapshot?,onSettings:()->Unit,onCalendar:()->Unit,modifier:Modifier=Modifier,
 today:LocalDate=LocalDate.now(),selectedDate:LocalDate=today,zone:ZoneId=ZoneId.systemDefault(),english:Boolean=false,
 isTabActive:Boolean=true,reduceMotion:Boolean=rememberProcessReducedMotion(),scanMedia:(@Composable (ProfileScan,Boolean)->Unit)?=null,
) {
 key(snapshot?.contextKey) {
  val p=ProcessSurfacePalette(isSystemInDarkTheme());val scans=snapshot?.scans?:emptyList()
  val session=remember {ProfileIntroSession()};var rangeName by rememberSaveable {mutableStateOf(ProfileScoreRange.WEEK.name)}
  val range=ProfileScoreRange.valueOf(rangeName);val real=remember(scans,today,range,zone){ProcessProfileModel.scores(scans,today,range,zone)}
  val sample=real.size<2;val points=if(sample)ProcessProfileModel.sampleScores(today,range)else real
  val latest=scans.maxByOrNull {it.createdAt}?.wellnessScore;val delta=if(sample)null else real.last().value.roundToInt()-real.first().value.roundToInt()
  val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
  LazyColumn(modifier.fillMaxSize().background(p.background).semantics {contentDescription=if(english)"Profile progress"else"Progression du profil"},contentPadding=PaddingValues(start=16.dp,end=16.dp,top=10.dp,bottom=32.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
   item("header") {Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(6.dp)) {
    Text(if(english)"Your progress"else"Tes progrès",Modifier.weight(1f),fontSize=28.sp,lineHeight=34.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.primary)
    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
    IconButton(onClick=onCalendar,modifier=Modifier.size(36.dp).background(p.card,CircleShape)){Icon(Icons.Default.DateRange,if(english)"Calendar, choose a date"else"Calendrier, choisir une date",Modifier.size(17.dp),tint=p.primary)}
    IconButton(onClick=onSettings,modifier=Modifier.size(36.dp).background(p.card,CircleShape)){Icon(Icons.Default.Settings,if(english)"Settings"else"Réglages",Modifier.size(17.dp),tint=p.primary)}
    }
   }}
   item("scan-pair") {ProfileScanPair(snapshot,p,english,zone,isTabActive&&life.isAtLeast(Lifecycle.State.STARTED),scanMedia)}
   item("score") {
    Column(Modifier.fillMaxWidth().padding(top=18.dp)) {
     Text(latest?.let {"$it%"}?:"—",fontSize=42.sp,lineHeight=50.sp,fontWeight=FontWeight.Bold,letterSpacing=(-.8).sp,color=p.primary)
     Spacer(Modifier.height(8.dp))
     Text(if(english)"DEBLOAT SCORE EVOLUTION"else"ÉVOLUTION DU SCORE DEBLOAT",fontSize=11.sp,lineHeight=14.sp,fontWeight=FontWeight.SemiBold,letterSpacing=.7.sp,color=p.secondary.copy(alpha=p.secondary.alpha*.78f))
     Spacer(Modifier.height(14.dp))
     val insight=when {sample->if(english)"Scan your face to replace this sample curve with your real evolution."else"Scanne ton visage pour remplacer cette courbe d’exemple par ta vraie évolution."
      delta!!>0->if(english)"Your score is up +$delta pts over this period."else"Ton score a gagné +$delta pts sur cette période."
      delta<0->if(english)"Your score is down $delta pts over this period."else"Ton score a perdu $delta pts sur cette période."
      else->if(english)"Score is stable over this period."else"Score stable sur cette période."}
     Text(insight,fontSize=16.sp,lineHeight=21.sp,letterSpacing=0.sp,color=p.primary.copy(alpha=.92f))
     Spacer(Modifier.height(18.dp))
     Row(Modifier.selectableGroup().horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(8.dp)) {
      ProfileScoreRange.entries.forEach {item->Text(if(english)item.english else item.french,Modifier.clip(CircleShape).border(1.dp,p.primary.copy(alpha=if(item==range).92f else .28f),CircleShape).selectable(selected=item==range,role=Role.Tab){rangeName=item.name}.padding(horizontal=16.dp,vertical=8.dp),fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,color=p.primary)}
     }
     Spacer(Modifier.height(22.dp))
     ProfileNativeChart(points,p,english,Modifier.fillMaxWidth().height(236.dp),sample=sample)
    }
   }
   items(ProfileVisualMetric.entries,key={it.name}) {metric->
    val history=remember(scans,metric,selectedDate,zone){ProcessProfileModel.metricHistory(scans,metric,selectedDate,zone)}
    val values=ProcessProfileModel.metricPoints(history,today);val previous=ProcessProfileModel.sourceDelta(history,today)
    ProfileMetricCard(metric,values,previous,p,english,reduceMotion,session)
   }
  }
 }
}
@Composable private fun ProfileScanPair(snapshot:ProfileSnapshot?,p:ProcessSurfacePalette,english:Boolean,zone:ZoneId,playback:Boolean,media:(@Composable (ProfileScan,Boolean)->Unit)?) {
 val pair=ProcessProfileModel.pair(snapshot);val locale=if(english)Locale.US else Locale.FRANCE;val date=DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)
 Row(Modifier.fillMaxWidth().padding(top=2.dp,bottom=4.dp).semantics {contentDescription=if(english)"Face evolution"else"Évolution du visage"},horizontalArrangement=Arrangement.spacedBy(12.dp)) {
  listOf(pair.first,pair.second).forEachIndexed {i,scan->
   val teaser=i==1&&scan!=null&&pair.first?.id==scan.id
   val caption=if(i==0){if(english)"Start"else"Début"}else{if(english)"Now"else"Maintenant"}
   Column(Modifier.weight(1f),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
    Box(Modifier.fillMaxWidth().aspectRatio(1f).shadow(14.dp,RoundedCornerShape(22.dp)).clip(RoundedCornerShape(22.dp)).background(p.strongCard.copy(alpha=p.strongCard.alpha*.55f)).border(.75.dp,p.stroke.copy(alpha=p.stroke.alpha*.55f),RoundedCornerShape(22.dp)),contentAlignment=Alignment.Center) {
     if(scan!=null&&media!=null)Box(Modifier.fillMaxSize().blur(if(teaser)14.dp else 0.dp).graphicsLayer {alpha=if(teaser).78f else 1f}){media(scan,playback&&!teaser)}
     else if(i==0&&scan==null)Text(snapshot?.firstName?.take(1)?.uppercase(locale)?.ifBlank {"?"}?:"?",fontSize=42.sp,lineHeight=50.sp,fontWeight=FontWeight.Bold,color=p.primary.copy(alpha=.55f))
     else Icon(Icons.Default.Face,null,Modifier.size(28.dp),tint=p.secondary.copy(alpha=p.secondary.alpha*.55f))
     if(teaser)Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
      Canvas(Modifier.background(p.card,CircleShape).padding(11.dp).size(16.dp)) {
       val sx=size.width/24f;val sy=size.height/24f
       drawRoundRect(p.primary,androidx.compose.ui.geometry.Offset(3*sx,10*sy),androidx.compose.ui.geometry.Size(17*sx,13*sy),androidx.compose.ui.geometry.CornerRadius(3*sx))
       val shackle=Path().apply {moveTo(7*sx,10*sy);lineTo(7*sx,6*sy);cubicTo(7*sx,-1*sy,19*sx,-1*sy,19*sx,6*sy)}
       drawPath(shackle,p.primary,style=androidx.compose.ui.graphics.drawscope.Stroke(2*sx,cap=StrokeCap.Round))
      }
      Text(if(english)"Unlocked"else"Débloqué",fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=p.primary)
     }
    }
    Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(2.dp)) {
     Text(caption,fontSize=13.sp,lineHeight=17.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=p.primary)
     if(teaser)Text(if(english)"Unlocked"else"Débloqué",fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=p.secondary)
     else scan?.let {Text(it.createdAt.atZone(zone).toLocalDate().format(date),fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=p.secondary)}
    }
   }
  }
 }
}
@Composable private fun ProfileMetricCard(metric:ProfileVisualMetric,points:List<ProfileDayPoint>,delta:Double?,p:ProcessSurfacePalette,english:Boolean,reduceMotion:Boolean,session:ProfileIntroSession) {
 Column(Modifier.fillMaxWidth().background(p.card,RoundedCornerShape(24.dp)).padding(14.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
  Text(metric.title(english),fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=p.primary)
  Column(Modifier.fillMaxWidth().background(Color.Black.copy(alpha=if(p.dark).68f else .14f),RoundedCornerShape(18.dp)).border(.5.dp,if(p.dark)Color.White.copy(alpha=.07f)else Color.Black.copy(alpha=.08f),RoundedCornerShape(18.dp)).padding(horizontal=10.dp,vertical=12.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
   Row(verticalAlignment=Alignment.CenterVertically) {
    val latest=points.lastOrNull()?.value
    Row(Modifier.weight(1f),verticalAlignment=Alignment.Bottom,horizontalArrangement=Arrangement.spacedBy(6.dp)) {Text(latest?.roundToInt()?.toString()?:"—",fontSize=34.sp,lineHeight=41.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=p.primary);if(latest!=null)Text("%",fontSize=18.sp,lineHeight=25.sp,color=p.secondary)}
    latest?.let {raw->
     val v=raw.roundToInt()
     val zone=if(metric.lowerIsBetter)when {v<(if(metric==ProfileVisualMetric.VISUAL_INDEX)42 else 48)->2;v<78->1;else->0}else when {v>=68->2;v>=42->1;else->0}
     val color=when(zone){2->Color(.36f,.78f,.58f);1->Color(.95f,.78f,.22f);else->Color(.93f,.52f,.28f)}
     Text(when(zone){2->"OPTIMAL";1->if(english)"DEGRADED"else"DÉGRADÉ";else->if(english)"POOR"else"MÉDIOCRE"},Modifier.background(color,CircleShape).padding(horizontal=12.dp,vertical=6.dp),fontSize=11.sp,lineHeight=14.sp,letterSpacing=0.sp,fontWeight=FontWeight.Black,color=Color.Black.copy(alpha=.9f))
    }
   }
   if(points.isEmpty())Box(Modifier.fillMaxWidth().height(132.dp),contentAlignment=Alignment.Center){Text(if(english)"Take a face scan to start your chart."else"Fais ton scan visage pour démarrer la courbe.",fontSize=13.sp,lineHeight=17.sp,letterSpacing=0.sp,color=p.secondary,textAlign=TextAlign.Center)}
   else ProfileNativeChart(points,p,english,Modifier.fillMaxWidth().height(132.dp),metric=metric,reduceMotion=reduceMotion,session=session)
   delta?.let {Text((if(it>=0)"+"else"")+it.roundToInt()+if(english)" pts vs previous period"else" pts par rapport à la période précédente",fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=p.secondary)}
  }
 }
}
