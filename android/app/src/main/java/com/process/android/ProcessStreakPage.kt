package com.process.android

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.format.TextStyle as DateTextStyle
import java.util.Locale

/** Reusable streak page. Host supplies computed counts and scan-backed week state. */
@Composable fun ProcessStreakPage(
    summary:ProcessStreakSummary,days:List<ProcessStreakDay>,selectedDate:LocalDate,
    onDateSelected:(LocalDate)->Unit,onClose:()->Unit,modifier:Modifier=Modifier,
    english:Boolean=false,dark:Boolean=isSystemInDarkTheme(),active:Boolean=true,preview:Boolean=false
) {
    val palette=InputPalette(dark);val accent=if(dark)Color(.34f,.72f,1f) else Color(.06f,.36f,.78f)
    val deep=if(dark)Color(.20f,.56f,.98f) else Color(.03f,.24f,.66f)
    val locale=if(english)Locale.ENGLISH else Locale.FRENCH
    val reduced=rememberProcessReducedMotion();val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val animate=active&&!reduced&&lifecycle.isAtLeast(Lifecycle.State.RESUMED)
    var hero by remember {mutableStateOf(preview||reduced)};var stats by remember {mutableStateOf(preview||reduced)}
    LaunchedEffect(reduced) {hero=true;if(!reduced&&!preview)delay(80);stats=true}
    val heroProgress by animateFloatAsState(if(hero)1f else 0f,if(reduced)snap() else spring(.82f,130.51f),label="streak.hero")
    val statProgress by animateFloatAsState(if(stats)1f else 0f,if(reduced)snap() else spring(.82f,130.51f),label="streak.stats")
    val density=LocalDensity.current.density;val haptics=LocalHapticFeedback.current
    BackHandler(onBack=onClose)
    Column(modifier.fillMaxSize().background(palette.background).verticalScroll(rememberScrollState()).padding(horizontal=16.dp).padding(top=16.dp,bottom=12.dp),verticalArrangement=Arrangement.spacedBy(28.dp)) {
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).clip(CircleShape).background(palette.primary.copy(alpha=.06f)).clickable(onClick=onClose).semantics {contentDescription=if(english)"Close" else "Fermer";role=Role.Button},contentAlignment=Alignment.Center) {Text("×",color=palette.primary,fontSize=24.sp)}
            Box(Modifier.weight(1f),contentAlignment=Alignment.Center) {Text(if(english)"Streak" else "Série",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)}
            Spacer(Modifier.size(40.dp))
        }
        Column(Modifier.fillMaxWidth().graphicsLayer {alpha=heroProgress;translationY=18*density*(1-heroProgress)},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(6.dp)) {
            Box(Modifier.fillMaxWidth().height(248.dp).semantics(mergeDescendants=true) {contentDescription="${summary.current} "+if(english)"Day Streak" else "jours de série"},contentAlignment=Alignment.Center) {
                // The original broad elliptical hero glow remains a separate visual parity item.
                ProcessStreakFlame(active=active,dark=dark)
                Column(Modifier.offset(y=10.dp).clearAndSetSemantics {},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(2.dp)) {
                    Box {
                        val text=summary.current.toString();val style=TextStyle(fontSize=72.sp,fontWeight=FontWeight.Bold,fontFamily=FontFamily.SansSerif,fontFeatureSettings="tnum",shadow=Shadow(Color.Black.copy(alpha=if(dark).22f else .14f),Offset(0f,4*density),8*density))
                        Text(text,style=style,color=Color.Black.copy(alpha=if(dark).5f else .28f),modifier=Modifier.offset(y=4.dp))
                        Text(text,style=style,color=deep.copy(alpha=if(dark).38f else .52f),modifier=Modifier.offset(x=1.5.dp,y=2.5.dp))
                        Text(text,style=style,color=Color.White.copy(alpha=if(dark).18f else .10f),modifier=Modifier.offset(x=(-1.2).dp,y=(-1.4).dp))
                        Text(text,style=style.copy(brush=Brush.verticalGradient(listOf(Color.White.copy(alpha=if(dark).62f else .48f),Color.White.copy(alpha=if(dark).38f else .24f)))))
                    }
                    Text(if(english)"Day Streak" else "jours de série",fontSize=15.sp,fontWeight=FontWeight.Medium,color=Color.White.copy(alpha=.82f),modifier=Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha=.22f)).padding(horizontal=14.dp,vertical=5.dp))
                }
            }
            val message=ProcessStreakModel.message(summary,english)
            Row(Modifier.offset(y=(-4).dp).clip(RoundedCornerShape(50)).background(palette.primary.copy(alpha=.06f)).padding(horizontal=14.dp,vertical=8.dp),horizontalArrangement=Arrangement.spacedBy(6.dp),verticalAlignment=Alignment.CenterVertically) {
                Text(message.first,fontSize=14.sp);Text(message.second,fontSize=13.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
            }
        }
        if(days.isNotEmpty()) {
            val range=ProcessStreakModel.activeRange(days)
            Column(Modifier.graphicsLayer {alpha=heroProgress;translationY=12*density*(1-heroProgress)},verticalArrangement=Arrangement.spacedBy(10.dp)) {
                Row {days.forEach {day->
                    val label=day.date.dayOfWeek.getDisplayName(DateTextStyle.SHORT,locale).replace(".","").lowercase(locale).replaceFirstChar {it.titlecase(locale)}
                    Box(Modifier.weight(1f).clickable {onDateSelected(day.date);haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)},contentAlignment=Alignment.Center) {Text(label,fontSize=11.sp,fontWeight=if(day.today)FontWeight.Bold else FontWeight.Medium,color=if(day.today)palette.primary else if(day.date==selectedDate)accent else palette.muted.copy(alpha=.75f))}
                }}
                BoxWithConstraints(Modifier.fillMaxWidth().height(52.dp)) {
                    val column=maxWidth/days.size
                    val left by animateDpAsState(column*(range?.first?:0)-2.dp,if(reduced)snap() else spring(.82f,194.96f),label="streak.range.left")
                    val width by animateDpAsState(column*(range?.count()?:0)+4.dp,if(reduced)snap() else spring(.82f,194.96f),label="streak.range.width")
                    if(range!=null)Box(Modifier.offset {IntOffset((left.value*density).toInt(),0)}.width(width).height(52.dp).clip(RoundedCornerShape(50)).background(accent))
                    Row(Modifier.fillMaxSize()) {days.forEachIndexed {index,day->
                        val onPill=range?.contains(index)==true
                        Box(Modifier.weight(1f).fillMaxHeight().semantics {contentDescription=day.date.toString()+", "+if(day.complete)(if(english)"Completed" else "Validé") else if(day.future)(if(english)"Upcoming" else "À venir") else if(day.today)(if(english)"Today" else "Aujourd’hui") else if(day.missed)(if(english)"Missed" else "Manqué") else ""},contentAlignment=Alignment.Center) {
                            when {
                                day.future->Box(Modifier.size(28.dp).border(1.5.dp,palette.primary.copy(alpha=if(dark).18f else .22f),CircleShape))
                                day.complete->Box(Modifier.size(28.dp).clip(CircleShape).background(if(onPill)Color.Black.copy(alpha=.22f) else Color(.17f,.17f,.18f)),contentAlignment=Alignment.Center) {Text("✓",fontSize=12.sp,fontWeight=FontWeight.Bold,color=if(onPill)Color.Black.copy(alpha=.85f) else accent)}
                                day.today->StreakTodaySpinner(onPill,accent,palette,animate)
                                day.missed->Box(Modifier.size(28.dp).clip(CircleShape).background(Color(.17f,.17f,.18f)),contentAlignment=Alignment.Center) {Text("×",fontSize=14.sp,color=Color.White.copy(alpha=.35f))}
                                else->Box(Modifier.size(8.dp).clip(CircleShape).background(palette.muted.copy(alpha=.18f)))
                            }
                        }
                    }}
                }
            }
        }
        Row(Modifier.fillMaxWidth().graphicsLayer {alpha=statProgress;translationY=14*density*(1-statProgress)},horizontalArrangement=Arrangement.spacedBy(10.dp)) {
            val values=listOf(Triple("♨",summary.current,if(english)"Current Streak" else "Série actuelle"),Triple("✧",maxOf(summary.longest,summary.current),if(english)"Best Streak" else "Meilleure série"),Triple("✓",summary.total,if(english)"Completed Days" else "Jours validés"))
            values.forEachIndexed {index,(symbol,value,label)->
                Column(Modifier.weight(1f).clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha=if(dark).06f else .72f)).border(1.dp,palette.primary.copy(alpha=if(dark).08f else .06f),RoundedCornerShape(18.dp)).padding(14.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
                    Text(symbol,fontSize=14.sp,fontWeight=FontWeight.SemiBold,color=if(index==0)accent else palette.muted)
                    Text(value.toString(),fontSize=28.sp,fontWeight=FontWeight.Bold,color=palette.primary,style=TextStyle(fontFeatureSettings="tnum"))
                    Text(label,fontSize=11.sp,fontWeight=FontWeight.Medium,color=palette.muted)
                }
            }
        }
    }
}
@Composable private fun StreakTodaySpinner(onPill:Boolean,accent:Color,palette:InputPalette,animate:Boolean) {
    val rotation=if(animate) {
        val transition=rememberInfiniteTransition(label="streak.today")
        val angle by transition.animateFloat(0f,360f,infiniteRepeatable(tween(1100,easing=LinearEasing),RepeatMode.Restart),label="streak.today.rotation")
        angle
    } else 0f
    Canvas(Modifier.size(28.dp)) {
        drawCircle(if(onPill)Color.Black.copy(alpha=.12f) else palette.primary.copy(alpha=.14f),radius=size.minDimension/2-1.dp.toPx(),style=Stroke(2.dp.toPx()))
        drawArc(if(onPill)Color.Black.copy(alpha=.55f) else accent,startAngle=rotation,sweepAngle=100.8f,useCenter=false,style=Stroke(2.2.dp.toPx(),cap=StrokeCap.Round))
    }
}
