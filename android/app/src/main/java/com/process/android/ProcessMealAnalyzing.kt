package com.process.android
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.*
import androidx.lifecycle.compose.LocalLifecycleOwner

@Composable fun ProcessMealAnalyzing(
 contextKey:String,isAnalysisComplete:Boolean,onRevealReady:()->Unit,modifier:Modifier=Modifier,
 english:Boolean=false,analysisFailure:String?=null,onRetry:(()->Unit)?=null,
 reduceMotion:Boolean=rememberProcessReducedMotion(),photo:(@Composable ()->Unit)?=null,
) {
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val state=rememberMealAnalysisState(contextKey,isAnalysisComplete,analysisFailure,onRevealReady)
 val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState();val animate=life.isAtLeast(Lifecycle.State.RESUMED)&&!reduceMotion&&!state.ready&&analysisFailure==null
 var pulse=.94f;var sweep=-1f
 if(animate) {
  val transition=rememberInfiniteTransition(label="meal ambient")
  val animatedPulse by transition.animateFloat(.94f,1.08f,infiniteRepeatable(tween(2400,easing=FastOutSlowInEasing),RepeatMode.Reverse),label="meal pulse")
  val animatedSweep by transition.animateFloat(-1f,1f,infiniteRepeatable(tween(1800,easing=LinearEasing)),label="meal sweep")
  pulse=animatedPulse;sweep=animatedSweep
 }
 val completed=state.statuses.count {it==MealAnalysisStepStatus.COMPLETED};val haptics=LocalHapticFeedback.current
 var previousCompleted by remember(contextKey){mutableIntStateOf(0)}
 LaunchedEffect(completed){if(completed>previousCompleted&&life.isAtLeast(Lifecycle.State.RESUMED))haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove);previousCompleted=completed}
 val density=LocalDensity.current
 val glow=remember(p.dark,density){Paint(Paint.ANTI_ALIAS_FLAG).apply {color=p.accent.copy(alpha=if(p.dark).14f else .10f).toArgb();maskFilter=BlurMaskFilter(with(density){50.dp.toPx()},BlurMaskFilter.Blur.NORMAL)}}
 Box(modifier.fillMaxSize().background(p.background),contentAlignment=Alignment.Center) {
  Canvas(Modifier.fillMaxSize()) {drawContext.canvas.nativeCanvas.drawCircle(size.width/2,size.height/2-130.dp.toPx(),160.dp.toPx()*pulse,glow)}
  Column(Modifier.fillMaxSize().padding(horizontal=22.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(28.dp)) {
   Spacer(Modifier.weight(1f).heightIn(min=36.dp))
   Box(Modifier.size(152.dp).scale(.98f+(pulse-.94f)/.14f*.04f).shadow(18.dp,RoundedCornerShape(26.dp),ambientColor=p.accent.copy(alpha=.24f),spotColor=p.accent.copy(alpha=.24f)).clip(RoundedCornerShape(26.dp)).background(p.strongCard).border(2.dp,p.accent.copy(alpha=.45f),RoundedCornerShape(26.dp)).clearAndSetSemantics {}) {
    photo?.invoke()
    if(animate)Canvas(Modifier.fillMaxSize()) {
     val y=size.height/2+sweep*80.dp.toPx()-24.dp.toPx()
     drawRect(Brush.verticalGradient(listOf(Color.Transparent,p.accent.copy(alpha=.32f),Color.Transparent),startY=y,endY=y+48.dp.toPx()),Offset(0f,y),Size(size.width,48.dp.toPx()),blendMode=BlendMode.Plus)
    }
   }
   Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
    Text(if(english)"Meal analysis"else"Analyse du repas",fontSize=22.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.primary)
    Text(analysisFailure?:if(state.ready||completed==6){if(english)"Analysis ready"else"Analyse prête"}else processMealAnalysisSteps[state.activeIndex].title(english),fontSize=15.sp,lineHeight=20.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp,color=if(analysisFailure==null)p.secondary else MaterialTheme.colorScheme.error,textAlign=androidx.compose.ui.text.style.TextAlign.Center)
   }
   Column(Modifier.fillMaxWidth().background(if(p.dark)Color.White.copy(alpha=.06f)else Color.White.copy(alpha=.92f),RoundedCornerShape(22.dp)).border(.5.dp,p.stroke.copy(alpha=p.stroke.alpha*.35f),RoundedCornerShape(22.dp)).padding(horizontal=14.dp,vertical=6.dp)) {
    processMealAnalysisSteps.forEachIndexed {index,step->
     val status=state.statuses[index];val statusLabel=when(status){MealAnalysisStepStatus.PENDING->if(english)"pending"else"en attente";MealAnalysisStepStatus.LOADING->if(english)"in progress"else"en cours";MealAnalysisStepStatus.COMPLETED->if(english)"done"else"terminé"}
     Row(Modifier.fillMaxWidth().padding(vertical=13.dp).clearAndSetSemantics {contentDescription="${step.title(english)}, $statusLabel"},horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.CenterVertically) {
      val background=when(status){MealAnalysisStepStatus.COMPLETED->p.accent.copy(alpha=.16f);MealAnalysisStepStatus.LOADING->p.accent.copy(alpha=.10f);MealAnalysisStepStatus.PENDING->p.secondary.copy(alpha=.08f)}
      Box(Modifier.size(34.dp).background(background,CircleShape),contentAlignment=Alignment.Center) {
       when(status) {
        MealAnalysisStepStatus.COMPLETED->Icon(Icons.Default.Check,null,Modifier.size(16.dp),tint=p.accent)
        MealAnalysisStepStatus.LOADING->if(!animate)Text("…",color=p.accent)else CircularProgressIndicator(Modifier.size(16.dp),color=p.accent,strokeWidth=2.dp)
        MealAnalysisStepStatus.PENDING->MealAnalysisGlyph(index,p.secondary.copy(alpha=.45f))
       }
      }
      Text(step.title(english),Modifier.weight(1f),fontSize=15.sp,lineHeight=20.sp,fontWeight=if(status==MealAnalysisStepStatus.LOADING)FontWeight.SemiBold else FontWeight.Medium,letterSpacing=0.sp,color=if(status==MealAnalysisStepStatus.PENDING)p.secondary.copy(alpha=p.secondary.alpha*.55f)else p.primary)
      when(status) {MealAnalysisStepStatus.COMPLETED->Icon(Icons.Default.CheckCircle,null,Modifier.size(18.dp),tint=p.accent);MealAnalysisStepStatus.LOADING->Text("…",fontSize=12.sp,fontWeight=FontWeight.Bold,color=p.secondary);MealAnalysisStepStatus.PENDING->Box(Modifier.size(18.dp).border(1.5.dp,p.secondary.copy(alpha=.22f),CircleShape))}
     }
     if(index<5)HorizontalDivider(Modifier.padding(start=52.dp),color=p.stroke.copy(alpha=.35f),thickness=.5.dp)
    }
   }
   if(analysisFailure!=null&&onRetry!=null)TextButton(onRetry){Text(if(english)"Try again"else"Réessayer")}
   Spacer(Modifier.weight(1f).heightIn(min=24.dp))
  }
 }
}
@Composable private fun MealAnalysisGlyph(index:Int,tint:Color) {
 Canvas(Modifier.size(14.dp)) {
  val w=size.width;val h=size.height
  when(index) {
   0->{rotate(-35f){drawOval(tint,Offset(w*.18f,h*.12f),Size(w*.64f,h*.76f));drawLine(Color.White.copy(alpha=.5f),Offset(w*.5f,h*.2f),Offset(w*.5f,h),1.dp.toPx())}}
   1->{val path=Path().apply {moveTo(w*.6f,0f);lineTo(w*.1f,h*.55f);lineTo(w*.47f,h*.55f);lineTo(w*.35f,h);lineTo(w*.9f,h*.4f);lineTo(w*.55f,h*.4f);close()};drawPath(path,tint)}
   2->{val path=Path().apply{moveTo(w*.5f,0f);cubicTo(0f,h*.6f,0f,h,w*.5f,h);cubicTo(w,h,w,h*.6f,w*.5f,0f);close()};drawPath(path,tint)}
   3->{val path=Path().apply{moveTo(w*.5f,0f);lineTo(w*.65f,h*.35f);lineTo(w,h*.5f);lineTo(w*.65f,h*.65f);lineTo(w*.5f,h);lineTo(w*.35f,h*.65f);lineTo(0f,h*.5f);lineTo(w*.35f,h*.35f);close()};drawPath(path,tint)}
   4->{drawLine(tint,Offset(0f,h*.3f),Offset(w,h*.3f),1.5.dp.toPx());drawLine(tint,Offset(0f,h*.7f),Offset(w,h*.7f),1.5.dp.toPx());drawLine(tint,Offset(0f,h*.3f),Offset(w*.25f,0f),1.5.dp.toPx());drawLine(tint,Offset(w,h*.7f),Offset(w*.75f,h),1.5.dp.toPx())}
   else->repeat(3){i->val barHeight=h*(.35f+i*.3f);drawRoundRect(tint,Offset(w*i/3,h-barHeight),Size(w*.23f,barHeight),CornerRadius(1.dp.toPx()))}
  }
 }
}
