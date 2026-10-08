package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import kotlinx.coroutines.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import java.time.*

/** Real snapshot in, context-scoped navigation and write intents out. No account/plan is fabricated. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ProcessHomeDashboard(
 snapshot:ProcessHomeSnapshot,onOpenStreak:()->Unit,onScan:()->Unit,onOpenScan:(String)->Unit,
 onOpenFood:()->Unit,onWaterChange:(String,Int)->Unit,onOpenExercise:(RoutineStep)->Unit,
 onStartRoutine:(String)->Unit,onRoutineComplete:(RoutineCompletion)->Unit,
 onRefresh:suspend (String)->Unit,onRestore:suspend (String)->Unit,
 welcome:WelcomeCardDismissal,onWelcomeChange:(WelcomeCardDismissal)->Unit,onReferral:()->Unit,
 modifier:Modifier=Modifier,english:Boolean=false,isActive:Boolean=true,now:Instant=rememberProcessHomeClock(isActive),zone:ZoneId=ZoneId.systemDefault(),
 tutorial:HomeTutorialState?=null,reduceMotion:Boolean=rememberProcessReducedMotion(),
 scanMedia:(@Composable (HomeScanSummary?,Boolean)->Unit)?=null,posture:(@Composable ()->Unit)?=null,
) {
 key(snapshot.contextKey) {
  val p=ProcessSurfacePalette(isSystemInDarkTheme());val scope=rememberCoroutineScope();val latest by rememberUpdatedState(snapshot)
  var refreshing by remember {mutableStateOf(false)};var restoring by remember {mutableStateOf(false)};var error by remember {mutableStateOf<String?>(null)}
  val list=rememberLazyListState();val today=now.atZone(zone).toLocalDate();val plan=snapshot.plan
  val availability=plan?.availability(snapshot.selectedDate,today)
  val sections=snapshot.visibleSections.filter {section->
   val step=when(section){HomeSection.FACE_SCAN->HomeTutorialStep.FACE_SCAN;HomeSection.NUTRITION->HomeTutorialStep.NUTRITION;else->HomeTutorialStep.ROUTINE}
   tutorial?.progress?.showsSection(step,plan!=null) !=false
  }
  fun runRestore() {if(!restoring&&snapshot.canRestore) {restoring=true;error=null;scope.launch {try {onRestore(snapshot.contextKey);currentCoroutineContext().ensureActive()}catch(e:CancellationException){throw e}catch(_:Exception){error=if(english)"Unable to restore your plan. Try again."else"Impossible de restaurer ton plan. Réessaie."}finally{restoring=false}}}}
  LaunchedEffect(tutorial?.progress?.index,tutorial?.progress?.active,sections) {
   val progress=tutorial?.progress?:return@LaunchedEffect
   if(progress.shouldScrollVertically) {
    delay(if(reduceMotion)0 else 180)
    val section=when(progress.step){HomeTutorialStep.FACE_SCAN->HomeSection.FACE_SCAN;HomeTutorialStep.HYDRATION,HomeTutorialStep.NUTRITION->HomeSection.NUTRITION;else->HomeSection.FACE_ROUTINE}
    val index=sections.indexOf(section);if(index>=0){if(reduceMotion)list.scrollToItem(index+1)else list.animateScrollToItem(index+1)}
   }
  }
  PullToRefreshBox(refreshing,{if(!refreshing){refreshing=true;error=null;scope.launch {try{onRefresh(snapshot.contextKey);currentCoroutineContext().ensureActive()}catch(e:CancellationException){throw e}catch(_:Exception){error=if(english)"Refresh unavailable. Try again."else"Actualisation indisponible. Réessaie."}finally{refreshing=false}}}},modifier.fillMaxSize().background(p.background)) {
   LazyColumn(state=list,contentPadding=PaddingValues(start=16.dp,end=16.dp,top=16.dp,bottom=114.dp)) {
    item(key="header") {
     Row(Modifier.fillMaxWidth().padding(bottom=4.dp),verticalAlignment=Alignment.Top,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
      Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(10.dp)) {
       val name=snapshot.firstName.trim();Text((if(english)"Hi"else"Salut")+if(name.isEmpty())""else" $name",fontSize=28.sp,lineHeight=34.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.primary)
       if(plan!=null)Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)) {
        val fraction by animateFloatAsState(plan.progress(today),if(reduceMotion)snap()else spring(.82f,158f),label="home progress")
        Box(Modifier.size(120.dp,5.dp).clip(CircleShape).background(p.primary.copy(alpha=if(p.dark).10f else .08f)).semantics {progressBarRangeInfo=ProgressBarRangeInfo(fraction,0f..1f)}) {Box(Modifier.fillMaxHeight().width(maxOf(4f,120f*fraction).dp).background(Brush.horizontalGradient(listOf(Color(0xFFFFC55B),Color(0xFFFF7738)))))}
        val days=plan.remainingDays(today);Text(if(days==0){if(english)"Done"else"Terminé"}else if(english)"$days day${if(days==1)""else"s"} left"else"$days j restant${if(days==1)""else"s"}",fontSize=12.sp,color=p.secondary.copy(alpha=.85f),letterSpacing=0.sp)
       }
      }
      Row(Modifier.clickable(role=Role.Button,onClick=onOpenStreak).semantics {contentDescription=if(english)"Streak, ${snapshot.streak} days"else"Série, ${snapshot.streak} jours"},verticalAlignment=Alignment.CenterVertically) {
       Box {ProcessStreakFlame(height=36.dp,active=!reduceMotion,timeSeconds=if(reduceMotion)0.0 else null);if(!snapshot.todayComplete)Box(Modifier.align(Alignment.TopEnd).padding(5.dp).size(5.dp).background(Color.Red,CircleShape))}
       Text(snapshot.streak.coerceAtLeast(0).toString(),fontSize=17.sp,fontWeight=FontWeight.Bold,color=p.primary)
      }
     }
     error?.let {Text(it,color=MaterialTheme.colorScheme.error,fontSize=14.sp,modifier=Modifier.padding(top=12.dp))}
    }
    if(plan==null)item(key="no-plan") {
     Column(Modifier.padding(top=24.dp).fillMaxWidth().background(p.card,RoundedCornerShape(20.dp)).padding(14.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
      Text(if(english)"Your plan"else"Ton plan",fontWeight=FontWeight.SemiBold,color=p.primary)
      Text(if(snapshot.canRestore){if(english)"Your program couldn't be loaded. Restore it in one tap."else"Ton programme n'a pas pu être chargé. Restaure-le en un clic."}else{if(english)"Your plan is getting ready. Check back in a moment."else"Ton plan se prépare. Reviens dans un instant."},color=p.secondary,fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp)
      if(snapshot.canRestore)OutlinedButton(::runRestore,enabled=!restoring,colors=ButtonDefaults.outlinedButtonColors(contentColor=p.primary),modifier=Modifier.fillMaxWidth()){if(restoring)CircularProgressIndicator(Modifier.size(16.dp),strokeWidth=2.dp);Text(if(restoring){if(english)"Restoring…"else"Restauration…"}else{if(english)"Restore my personalized plan"else"Restaurer mon plan personnalisé"})}
     }
    } else itemsIndexed(sections,key={_,section->section.name}) {index,section->
     val top=if(index==0)24+8+if(section==HomeSection.FACE_SCAN)12 else 0 else if(section==HomeSection.FACE_ROUTINE)56 else 36
     Column(Modifier.padding(top=top.dp)) {
      when(section) {
       HomeSection.FACE_SCAN->{HomeFocus(tutorial,HomeTutorialStep.FACE_SCAN,english,reduceMotion){ProcessHomeScanCard(snapshot.latestScan,now,zone,onScan,onOpenScan,scanMedia,english)}
        if(tutorial?.progress?.active!=true)ProcessWelcomeCards(welcome,onWelcomeChange,onReferral,Modifier.padding(top=18.dp),english=english,reduceMotion=reduceMotion)
       }
       HomeSection.NUTRITION->if(availability==HomeDayAvailability.EDITABLE)ProcessHomeNutrition(snapshot,onWaterChange,onOpenFood,tutorial,english,reduceMotion)
       HomeSection.FACE_ROUTINE->if(availability==HomeDayAvailability.EDITABLE) {
        HomeFocus(tutorial,HomeTutorialStep.ROUTINE,english,reduceMotion){ProcessHomeRoutineSection(snapshot,onOpenExercise,onStartRoutine,onRoutineComplete,english,reduceMotion)}
       }
       HomeSection.POSTURE->if(availability==HomeDayAvailability.EDITABLE)posture?.invoke()
       else->Unit
      }
     }
    }
    if(plan!=null&&availability!=HomeDayAvailability.EDITABLE)item(key="day-unavailable") {
     Column(Modifier.padding(top=20.dp).fillMaxWidth().background(p.card,RoundedCornerShape(20.dp)).padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
      Text(if(availability==HomeDayAvailability.FUTURE){if(english)"Upcoming day"else"Jour à venir"}else{if(english)"Outside plan"else"Hors plan"},fontWeight=FontWeight.SemiBold,color=p.primary)
      Text(if(availability==HomeDayAvailability.FUTURE){if(english)"This day's content will be available on the day itself."else"Le contenu de cette journée sera disponible le jour J."}else{if(english)"This date isn't covered by your personalized plan calendar."else"Cette date n'est pas couverte par ton calendrier du plan personnalisé."},color=p.secondary,fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp)
     }
    }
   }
  }
 }
}
@Composable internal fun HomeFocus(tutorial:HomeTutorialState?,focus:HomeTutorialStep,english:Boolean,reduceMotion:Boolean,content:@Composable ()->Unit) {
 if(tutorial==null)content()else ProcessHomeTutorial(tutorial,focus,english=english,reduceMotion=reduceMotion,content=content)
}

@Composable fun rememberProcessHomeClock(active:Boolean=true):Instant {
 val lifecycle=LocalLifecycleOwner.current.lifecycle;var now by remember {mutableStateOf(Instant.now())}
 LaunchedEffect(lifecycle,active) {if(active)lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED){while(true){now=Instant.now();delay(1000)}}}
 return now
}
