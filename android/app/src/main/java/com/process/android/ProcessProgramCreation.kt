package com.process.android

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/** UI/timing adaptation. Success requires the host's real prepareProgram callback to complete. */
@Composable
fun ProcessProgramCreation(
    completed: Boolean,
    healthAlreadyAuthorized: Boolean,
    requestHealthAccess: suspend () -> Boolean,
    prepareProgram: suspend () -> Unit,
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
    english: Boolean = false,
    dark: Boolean = isSystemInDarkTheme(),
    onHealthResult: (Boolean) -> Unit = {},
) {
    val palette=InputPalette(dark)
    val reduceMotion by rememberUpdatedState(rememberProcessReducedMotion())
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    val haptic=LocalHapticFeedback.current
    val currentPrepare by rememberUpdatedState(prepareProgram)
    val currentRequest by rememberUpdatedState(requestHealthAccess)
    val currentHealthResult by rememberUpdatedState(onHealthResult)
    var progress by remember {mutableStateOf(ProgramCreationModel.progress(if(completed)2 else 0,if(completed)1.0 else 0.0))}
    var duration by remember {mutableIntStateOf(400)}
    var popup by remember {mutableIntStateOf(-1)}
    var waitingForHealth by remember {mutableStateOf(false)}
    var success by remember {mutableStateOf(completed)}
    var revealed by remember {mutableStateOf(completed)}
    var failure by remember {mutableStateOf(false)}
    var attempt by remember {mutableIntStateOf(0)}
    val answers=remember {Channel<Boolean>(Channel.RENDEZVOUS)}
    
    LaunchedEffect(attempt,completed) {
        if(completed) {success=true;revealed=true;return@LaunchedEffect}
        success=false;revealed=false;failure=false;popup=-1
        progress=ProgramCreationModel.progress(0,0.0)
        suspend fun activeDelay(millis:Long) {
            lifecycle.currentStateFlow.first {it.isAtLeast(Lifecycle.State.STARTED)}
            delay(if(reduceMotion)0 else millis)
            lifecycle.currentStateFlow.first {it.isAtLeast(Lifecycle.State.STARTED)}
        }
        try {
            activeDelay(ProgramCreationModel.START_DELAY)
            for(phase in 0..2) {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                ProgramCreationModel.milestones(phase).forEach {milestone ->
                    activeDelay(milestone.delayMillis)
                    duration=milestone.animationMillis
                    progress=ProgramCreationModel.progress(phase,milestone.value)
                    if(!reduceMotion) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
                if(phase<2 && !(phase==0 && healthAlreadyAuthorized)) {
                    popup=phase
                    val answer=answers.receive()
                    popup=-1
                    if(phase==0) {
                        waitingForHealth=true
                        try {currentHealthResult(if(answer)currentRequest() else false)}
                        finally {waitingForHealth=false}
                    }
                }
            }
            // The source animation alone is not proof that a program was actually generated.
            currentPrepare()
            activeDelay(200)
            success=true
            activeDelay(100)
            revealed=true
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        } catch(cancelled:CancellationException) {throw cancelled}
        catch(error:Exception) {popup=-1;waitingForHealth=false;failure=true}
    }
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background)) {
        if(success) {
            CreationConfetti(revealed && !reduceMotion,Modifier.fillMaxSize())
            Column(Modifier.fillMaxSize().padding(horizontal=34.dp,vertical=34.dp),horizontalAlignment=Alignment.CenterHorizontally) {
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                    if(revealed) {
                        Image(painterResource(R.drawable.creation_check),contentDescription=null,Modifier.size(120.dp))
                        Spacer(Modifier.height(34.dp))
                        Text(if(english)"You're all set." else "Tout est prêt.",fontSize=28.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center)
                        Spacer(Modifier.height(10.dp))
                        Text(if(english)"Thanks for your answers." else "Merci pour vos réponses.",fontSize=28.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center)
                    }
                }
                AnimatedVisibility(revealed,enter=fadeIn(tween(if(reduceMotion)0 else 150)),exit=fadeOut(tween(if(reduceMotion)0 else 150))) {
                    Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(18.dp)) {
                        Button(onClick=onContinue,modifier=Modifier.fillMaxWidth().heightIn(min=58.dp),colors=ButtonDefaults.buttonColors(containerColor=palette.primary,contentColor=palette.background)) {
                            Text(if(english)"Get started" else "Commencer",fontSize=20.sp,fontWeight=FontWeight.Bold)
                        }
                        Text(if(english)"Process doesn't replace medical advice. Always check with your doctor first." else "Process ne remplace pas les conseils d'un médecin. Consulte toujours ton médecin en premier lieu.",fontSize=12.sp,color=palette.body,textAlign=TextAlign.Center)
                    }
                }
            }
        } else {
            val hostHeight=maxHeight.value
            val spacing=(hostHeight*.06f).coerceAtLeast(28f).dp
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal=28.dp).padding(top=58.dp,bottom=if(popup>=0)220.dp else 80.dp),horizontalAlignment=Alignment.CenterHorizontally) {
                Row(verticalAlignment=Alignment.Bottom,modifier=Modifier.semantics(mergeDescendants=true){progressBarRangeInfo=ProgressBarRangeInfo(progress.percentage/100f,0f..1f)}) {
                    Text(progress.percentage.toString(),style=TextStyle(fontSize=78.sp,fontWeight=FontWeight.Bold,brush=Brush.linearGradient(listOf(palette.primary,palette.primary.copy(alpha=.62f)))))
                    Text("%",fontSize=40.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,modifier=Modifier.padding(bottom=12.dp))
                }
                Text(if(english)"Building your program" else "Création du programme",fontSize=20.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
                Spacer(Modifier.height(spacing))
                Image(painterResource(creationBadge(ProgramCreationModel.badge(progress.percentage),english,dark)),null,Modifier.widthIn(max=336.dp).height(106.dp))
                Spacer(Modifier.height((hostHeight*.07f).coerceAtLeast(32f).dp))
                val labels=if(english)listOf("Connecting to Health Connect","Analyzing your profile","Building your personal plan") else listOf("Connexion à Health Connect","Analyse de ton profil","Génération de ton plan personnalisé")
                Column(verticalArrangement=Arrangement.spacedBy(22.dp)) {
                    repeat(progress.visibleCount) { index ->
                        val value by animateFloatAsState(progress.bars[index],tween(if(reduceMotion)0 else duration,easing=CubicBezierEasing(.42f,0f,.58f,1f)),label="creationBar$index")
                        Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                            Text(labels[index]+if(progress.bars[index]>=.999f)"  ✓" else "",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
                            BoxWithConstraints(Modifier.fillMaxWidth().height(16.dp).clip(RoundedCornerShape(8.dp)).background(if(dark)Color(.14f,.16f,.20f)else Color(.90f,.93f,.97f)).semantics {progressBarRangeInfo=ProgressBarRangeInfo(value,0f..1f)}) {
                                Box(Modifier.width((maxWidth.value*value).coerceAtLeast(16f).dp).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(Brush.linearGradient(if(dark) listOf(Color(.52f,.88f,1f),Color(.34f,.72f,1f),Color(.20f,.56f,.98f)) else listOf(Color(.28f,.66f,1f),Color(.14f,.50f,.96f),Color(.08f,.38f,.90f)))))
                            }
                        }
                    }
                }
                if(waitingForHealth) Text(if(english)"Waiting for the permission request…" else "En attente de la demande d’autorisation…",color=palette.body,modifier=Modifier.padding(top=20.dp))
                if(failure) {
                    Text(if(english)"Couldn't finish preparing your program. Please try again." else "La préparation du programme n’a pas abouti. Réessaie.",color=palette.primary,modifier=Modifier.padding(top=24.dp).semantics{liveRegion=LiveRegionMode.Polite})
                    Button(onClick={attempt++}) {Text(if(english)"Try again" else "Réessayer")}
                }
            }
        }
        if(popup>=0) AlertDialog(onDismissRequest={},title={Text(if(popup==0) {if(english)"Connect Health Connect" else "Connecter Health Connect"}else {if(english)"To continue, please confirm" else "Pour pouvoir continuer, précise"})},text={Text(if(popup==0) {if(english)"Connect Health Connect to personalize your plan with your real data." else "Connecte Health Connect pour personnaliser ton plan avec tes vraies données."}else {if(english)"Have you already tried to debloat your face?" else "As-tu déjà essayé de dégonfler ton visage ?"})},confirmButton={TextButton(onClick={answers.trySend(true)}){Text(if(popup==0){if(english)"Allow"else"Autoriser"}else{if(english)"Yes"else"Oui"})}},dismissButton={TextButton(onClick={answers.trySend(false)}){Text(if(popup==0){if(english)"Later"else"Plus tard"}else{if(english)"No"else"Non"})}})
    }
}

private fun creationBadge(badge:ProgramCreationModel.Badge,english:Boolean,dark:Boolean):Int=when(badge) {
    ProgramCreationModel.Badge.SCIENCE -> if(english){if(dark)R.drawable.creation_science_en_dark else R.drawable.creation_science_en}else{if(dark)R.drawable.creation_science_dark else R.drawable.creation_science}
    ProgramCreationModel.Badge.PROGRAM -> if(english){if(dark)R.drawable.creation_program_en_dark else R.drawable.creation_program_en}else{if(dark)R.drawable.creation_program_dark else R.drawable.creation_program}
    ProgramCreationModel.Badge.DOWNLOAD -> if(english){if(dark)R.drawable.creation_download_en_dark else R.drawable.creation_download_en}else{if(dark)R.drawable.creation_download_dark else R.drawable.creation_download}
}

@Composable
private fun CreationConfetti(active:Boolean,modifier:Modifier) {
    val pieces=remember {ProgramCreationModel.confetti()}
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    var elapsed by remember {mutableFloatStateOf(0f)}
    LaunchedEffect(active,lifecycle) {
        if(active) lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            var start=0L
            while(true) withFrameNanos { now ->if(start==0L)start=now;elapsed=(now-start)/1_000_000_000f}
        }
    }
    val colors=listOf(Color(.55f,.78f,.98f),Color(.98f,.62f,.78f),Color(.98f,.86f,.45f),Color(.72f,.62f,.98f),Color(.58f,.88f,.72f))
    Canvas(modifier) {
        if(active) pieces.forEach {piece ->
            val time=elapsed-piece.delay
            if(time>=0) {
                val phase=(time%piece.duration)/piece.duration
                val x=piece.xRatio*size.width;val y=(-30+(size.height/density+70)*phase).dp.toPx()
                rotate(piece.spin*phase,pivot=Offset(x,y)) {
                    drawRoundRect(colors[piece.colorIndex].copy(alpha=piece.opacity),Offset(x-piece.width.dp.toPx()/2,y-piece.height.dp.toPx()/2),Size(piece.width.dp.toPx(),piece.height.dp.toPx()),androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()))
                }
            }
        }
    }
}
