package com.process.android

import android.os.SystemClock
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

@Composable fun ProcessEstimation(
    context:ProcessEstimationContext,isAlreadyCompleted:Boolean,onValidationChanged:(Boolean)->Unit,
    modifier:Modifier=Modifier,onUnlockProgressChanged:(Float)->Unit={},english:Boolean=false,dark:Boolean=isSystemInDarkTheme(),referenceDate:LocalDate=LocalDate.now()
) {
    val palette=InputPalette(dark);val owner=LocalLifecycleOwner.current;val reduced=rememberProcessReducedMotion();val haptics=LocalHapticFeedback.current
    val initialDate=remember {referenceDate};val finalDate=remember {initialDate.plusDays(ProcessEstimationModel.checkInDays(context).toLong())}
    var displayed by remember {mutableStateOf(finalDate)};var finished by remember {mutableStateOf(isAlreadyCompleted)}
    val validate by rememberUpdatedState(onValidationChanged);val unlock by rememberUpdatedState(onUnlockProgressChanged)
    val locale=if(english)Locale.ENGLISH else Locale.FRENCH
    fun finish() {displayed=finalDate;unlock(1f);validate(true);if(!finished)haptics.performHapticFeedback(HapticFeedbackType.LongPress);finished=true}
    LaunchedEffect(isAlreadyCompleted,reduced,owner) {
        if(isAlreadyCompleted||reduced||finished){finish();return@LaunchedEffect}
        validate(false);unlock(0f)
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            if(finished){validate(true);return@repeatOnLifecycle}
            val fallback=launch {delay(3200);finish()}
            try {
                val started=SystemClock.uptimeMillis()
                while(!finished) {
                    withFrameNanos {
                        val frame=ProcessEstimationModel.frame(initialDate,finalDate,SystemClock.uptimeMillis()-started)
                        if(frame.date!=displayed){displayed=frame.date;if(frame.unlockProgress>0)haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}
                        unlock(frame.unlockProgress)
                        if(frame.finished)finish()
                    }
                }
            } finally {fallback.cancel()}
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background)) {
        val graphHeight=minOf(280.dp,maxHeight*.34f)
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom=148.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            Column(Modifier.fillMaxWidth().padding(horizontal=40.dp).padding(top=54.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(18.dp)) {
                Text(if(english)"Your tracking over time" else "Ton suivi dans le temps",fontSize=18.sp,fontWeight=FontWeight.Medium,color=palette.body,textAlign=TextAlign.Center)
                Text(if(english)"Your next routine check-in" else "Ton prochain point sur ta routine",fontSize=22.sp,lineHeight=28.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center,modifier=Modifier.padding(horizontal=8.dp))
                Row(Modifier.fillMaxWidth().semantics(mergeDescendants=true) {contentDescription="${displayed.dayOfMonth} "+displayed.month.getDisplayName(TextStyle.FULL,locale)},horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    val fill=palette.primary.copy(alpha=if(dark).08f else .045f)
                    Box(Modifier.widthIn(min=64.dp).heightIn(min=46.dp).clip(RoundedCornerShape(12.dp)).background(fill).padding(horizontal=16.dp).clearAndSetSemantics {},contentAlignment=Alignment.Center) {Text(displayed.dayOfMonth.toString(),fontSize=32.sp,fontWeight=FontWeight.Bold,color=palette.primary)}
                    Box(Modifier.weight(1f).heightIn(min=46.dp).clip(RoundedCornerShape(12.dp)).background(fill).padding(horizontal=16.dp).clearAndSetSemantics {},contentAlignment=Alignment.Center) {Text(displayed.month.getDisplayName(TextStyle.FULL,locale).replaceFirstChar {it.titlecase(locale)},fontSize=22.sp,fontWeight=FontWeight.Bold,color=palette.primary,maxLines=1)}
                }
            }
            Spacer(Modifier.height(16.dp))
            Column(Modifier.fillMaxWidth().height(graphHeight).padding(24.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                Canvas(Modifier.size(44.dp)) {
                    val color=Color(.42f,.70f,1f);val stroke=androidx.compose.ui.graphics.drawscope.Stroke(2.8.dp.toPx())
                    drawRoundRect(color,topLeft=androidx.compose.ui.geometry.Offset(size.width*.1f,size.height*.16f),size=androidx.compose.ui.geometry.Size(size.width*.8f,size.height*.78f),cornerRadius=androidx.compose.ui.geometry.CornerRadius(5.dp.toPx()),style=stroke)
                    drawLine(color,androidx.compose.ui.geometry.Offset(size.width*.1f,size.height*.38f),androidx.compose.ui.geometry.Offset(size.width*.9f,size.height*.38f),2.8.dp.toPx())
                }
                Spacer(Modifier.height(16.dp))
                Text(if(english)"Compare your observations over time under similar conditions." else "Compare tes observations au fil du temps, dans des conditions similaires.",color=palette.body,textAlign=TextAlign.Center)
            }
            Row(Modifier.padding(horizontal=40.dp).padding(bottom=4.dp),horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                Image(painterResource(R.drawable.estimation_check),contentDescription=null,modifier=Modifier.padding(top=1.dp).size(24.dp))
                Text(if(english)"A check-in date to review your habits, not a prediction. Changes in appearance cannot be guaranteed." else "Une date de bilan pour suivre tes habitudes, pas une prédiction de résultat. Les changements d’apparence ne peuvent pas être garantis.",fontSize=15.sp,color=palette.body)
            }
        }
    }
}
