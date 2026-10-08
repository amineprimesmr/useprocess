package com.process.android
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*

/** Wrap the real target card; only its current step adds caption,rotating border and exit controls. */
@Composable fun ProcessHomeTutorial(
 state:HomeTutorialState,focus:HomeTutorialStep,modifier:Modifier=Modifier,cornerRadius:Dp=30.dp,
 english:Boolean=false,reduceMotion:Boolean=rememberProcessReducedMotion(),content:@Composable ()->Unit,
) {
 require(!focus.isTabStep)
 val progress=state.progress;val focused=progress.active&&progress.step==focus
 val revealed=progress.active&&!progress.step.isTabStep&&!focused&&focus.ordinal<progress.step.ordinal
 DisposableEffect(state,focus){onDispose {state.visibleCTA.remove(focus)}}
 Column(modifier,verticalArrangement=Arrangement.spacedBy(22.dp)) {
  Box(Modifier.fillMaxWidth().graphicsLayer {alpha=if(revealed).88f else 1f}) {
   content()
   if(focused)ProcessTutorialBorder(Modifier.matchParentSize(),cornerRadius,reduceMotion=reduceMotion)
  }
  AnimatedVisibility(focused,enter=if(reduceMotion)EnterTransition.None else fadeIn(spring(.88f,146f))+slideInVertically(spring(.88f,146f)){it/4},exit=if(reduceMotion)ExitTransition.None else fadeOut(tween(150))) {
   Column(verticalArrangement=Arrangement.spacedBy(22.dp)) {
    TutorialCaption(focus,english,isSystemInDarkTheme())
    Column(Modifier.onGloballyPositioned {val bounds=it.boundsInWindow();state.visibleCTA[focus]=focused&&bounds.width>0&&bounds.height>0}.padding(top=4.dp,bottom=8.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
     val dark=isSystemInDarkTheme();val foreground=if(dark)Color.White else Color.Black
     Row(Modifier.fillMaxWidth().clearAndSetSemantics {contentDescription="${progress.index+1}/5"},horizontalArrangement=Arrangement.spacedBy(6.dp,Alignment.CenterHorizontally)) {
      repeat(4){i->Box(Modifier.size(if(i==progress.index)18.dp else 6.dp,6.dp).background(foreground.copy(alpha=if(i==progress.index)1f else if(dark).22f else .18f),CircleShape))}
     }
     TutorialControls(state,english,dark)
    }
   }
  }
 }
}
@Composable private fun TutorialCaption(step:HomeTutorialStep,english:Boolean,dark:Boolean) {
 val foreground=if(dark)Color.White else Color.Black
 Column(Modifier.fillMaxWidth().padding(horizontal=4.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
  Text(step.title(english),fontSize=26.sp,lineHeight=31.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=foreground)
  Text(step.message(english),fontSize=16.sp,lineHeight=24.sp,letterSpacing=0.sp,color=foreground.copy(alpha=if(dark).62f else .58f))
 }
}
@Composable private fun TutorialControls(state:HomeTutorialState,english:Boolean,dark:Boolean) {
 val foreground=if(dark)Color.White else Color.Black;val haptics=LocalHapticFeedback.current
 val last=state.progress.step.isTabStep
 Column(verticalArrangement=Arrangement.spacedBy(14.dp)) {
  Box(Modifier.fillMaxWidth().height(54.dp).clip(CircleShape).background(foreground).clickable(enabled=state.progress.active,role=Role.Button){haptics.performHapticFeedback(HapticFeedbackType.LongPress);state.advance()},contentAlignment=Alignment.Center) {
   Text(if(last){if(english)"Let’s go"else"C’est parti"}else{if(english)"Continue"else"Continuer"},fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=if(dark)Color.Black else Color.White)
  }
  Box(Modifier.fillMaxWidth().semantics {contentDescription=if(english)"Skip the tutorial"else"Passer le tutoriel"}.clickable(enabled=state.progress.active,role=Role.Button){haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove);state.skip()}.padding(vertical=8.dp),contentAlignment=Alignment.Center) {Text(if(english)"Skip"else"Passer",fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=foreground.copy(alpha=if(dark).62f else .58f))}
 }
}
@Composable fun ProcessTutorialTabFooter(state:HomeTutorialState,modifier:Modifier=Modifier,english:Boolean=false) {
 if(state.progress.active&&state.progress.step.isTabStep)Column(modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent,Color.Black.copy(alpha=.55f),Color.Black.copy(alpha=.72f)))).navigationBarsPadding().padding(horizontal=22.dp).padding(bottom=16.dp)) {
  TutorialCaption(state.progress.step,english,true)
  Spacer(Modifier.height(18.dp))
  TutorialControls(state,english,true)
 }
}
@Composable fun ProcessTutorialTabOutline(state:HomeTutorialState,tabs:List<String>,modifier:Modifier=Modifier,reduceMotion:Boolean=rememberProcessReducedMotion()) {
 require(tabs.distinct().size==tabs.size)
 if(state.progress.active&&state.progress.step.isTabStep&&"profile" in tabs)BoxWithConstraints(modifier) {
  val cell=maxWidth/tabs.size;val width=(cell-4.dp).coerceAtLeast(44.dp)
  ProcessTutorialBorder(Modifier.offset(x=cell*(tabs.indexOf("profile")+.5f)-width/2).width(width).fillMaxHeight(),22.dp,reduceMotion=reduceMotion)
 }
}
