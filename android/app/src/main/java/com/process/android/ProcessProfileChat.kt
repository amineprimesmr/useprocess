package com.process.android

import android.os.SystemClock
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.activity.compose.BackHandler
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlin.math.sin

/** Native local questionnaire. Host supplies identity-scoped store and real navigation/profile save. */
@Composable fun ProcessProfileChat(
    store:ProfileChatStore,
    firstName:String,
    onComplete:(ProfileChatProfile)->Unit,
    onBack:()->Unit,
    modifier:Modifier=Modifier,
    onProfileChange:(ProfileChatProfile)->Unit={},
    english:Boolean=false,
    dark:Boolean=isSystemInDarkTheme(),
    reduceMotion:Boolean=rememberProcessReducedMotion()
) {
    val palette=InputPalette(dark)
    val questions=remember(firstName,english) {ProcessProfileChatModel.questions(firstName,english)}
    val currentId=ProcessProfileChatModel.current(store.progress)
    val question=questions.firstOrNull {it.id==currentId}
    val engine=remember(store) {MossTimeline()}
    var messages by remember(store) {mutableStateOf(emptyList<MossMessage>())}
    var controlsVisible by remember(store) {mutableStateOf(false)}
    var typing by remember(store) {mutableStateOf(false)}
    var showExplainer by rememberSaveable {mutableStateOf(false)}
    var rewindInstant by remember {mutableStateOf(false)}
    val assistive=rememberProcessScreenReader()
    val haptics=LocalHapticFeedback.current
    val owner=LocalLifecycleOwner.current
    val complete by rememberUpdatedState(onComplete)
    val changed by rememberUpdatedState(onProfileChange)
    val scroll=rememberScrollState()
    fun refresh() {messages=engine.messages;typing=engine.isTyping;controlsVisible=engine.controlsVisible}
    fun submit(choiceId:String?=null,explained:Boolean=false) {
        if(question==null||!engine.controlsVisible||engine.isTyping)return
        val next=ProcessProfileChatModel.submit(store.progress,question.id,choiceId,explained)
        if(next==store.progress)return
        store.save(next);changed(ProcessProfileChatModel.profile(next))
        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
    }
    fun back() {
        if(showExplainer) {showExplainer=false;return}
        val previous=ProcessProfileChatModel.rewind(store.progress)
        if(previous==null)onBack() else {engine.reset();rewindInstant=true;store.save(previous);changed(ProcessProfileChatModel.profile(previous));refresh()}
    }
    BackHandler {back()}
    // Rebuild completed history instantly; only the new current question receives a live timeline.
    LaunchedEffect(currentId,english,firstName,reduceMotion,assistive,store) {
        engine.reset()
        questions.filter {it.id in store.progress.completed}.forEach {q->
            engine.speak(q.lines(if(q.kind==ProfileChatKind.CHOICE)questions.filter {it.kind==ProfileChatKind.CHOICE}.indexOf(q)+1 else null),SystemClock.uptimeMillis(),instant=true)
            ProcessProfileChatModel.answerDisplay(q,store.progress)?.let(engine::userReplied)
        }
        if(question==null) {refresh();complete(ProcessProfileChatModel.profile(store.progress));return@LaunchedEffect}
        val instant=store.wasPresented(question.id)||rewindInstant||reduceMotion||assistive
        rewindInstant=false
        val number=if(question.kind==ProfileChatKind.CHOICE)questions.filter {it.kind==ProfileChatKind.CHOICE}.indexOf(question)+1 else null
        engine.speak(question.lines(number),SystemClock.uptimeMillis(),instant)
        store.markPresented(question.id);refresh()
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            var tick=0
            while(engine.isTyping) {
                withFrameNanos { }
                val pulses=engine.advance(SystemClock.uptimeMillis())
                // Native Android sparse haptic fallback; CoreHaptics intensity/sharpness is not portable.
                if(!reduceMotion&&!assistive&&pulses.any {it.glyph==null || ++tick%4==0})haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                refresh()
            }
        }
    }
    DisposableEffect(engine) {onDispose {engine.reset()}}
    LaunchedEffect(messages.size,controlsVisible,showExplainer) {
        if(!showExplainer) {delay(30);if(reduceMotion)scroll.scrollTo(scroll.maxValue) else scroll.animateScrollTo(scroll.maxValue,tween(280))}
    }
    Box(modifier.fillMaxSize().background(palette.background)) {
        if(showExplainer) {
            ProcessTrackingExplainer({showExplainer=false;submit(explained=true)},Modifier.padding(top=52.dp),english,dark)
        } else {
            MossBlueArc(dark,reduceMotion)
            Column(Modifier.fillMaxSize().padding(top=76.dp).verticalScroll(scroll)
                .clickable(enabled=typing,indication=null,interactionSource=remember {androidx.compose.foundation.interaction.MutableInteractionSource()}) {engine.completeBatch();refresh()}
                .padding(horizontal=24.dp).padding(top=12.dp,bottom=28.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
                messages.takeLast(4).forEachIndexed {index,message->
                    val depth=messages.takeLast(4).lastIndex-index
                    MossMessageView(message,depth,palette,assistive)
                }
                AnimatedVisibility(visible=controlsVisible&&!typing,enter=fadeIn(tween(180))+slideInVertically(tween(180)){it/8},exit=fadeOut(tween(180))) {
                    when(question?.kind) {
                        ProfileChatKind.INFO -> ChatPrimaryButton(question.continueLabel,palette) {if(question.id=="intro_next")showExplainer=true else submit()}
                        ProfileChatKind.CHOICE -> {
                            val choicesScroll=rememberScrollState()
                            Column(Modifier.then(if(question.choices.size>=5)Modifier.heightIn(max=220.dp).verticalScroll(choicesScroll) else Modifier),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                                question.choices.forEach {choice->
                                    Surface(onClick={submit(choice.id)},shape=RoundedCornerShape(32.dp),color=palette.primary.copy(alpha=.09f),contentColor=palette.primary,modifier=Modifier.widthIn(max=280.dp)) {
                                        Text(choice.label,Modifier.padding(horizontal=12.dp,vertical=8.dp),fontSize=15.sp,fontWeight=FontWeight.Medium)
                                    }
                                }
                            }
                        }
                        ProfileChatKind.SUMMARY,null -> ChatProfileSummary(store.progress,english,palette) {if(question==null)complete(ProcessProfileChatModel.profile(store.progress)) else submit()}
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal=12.dp,vertical=6.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            TextButton(onClick=::back) {Text(if(english) "Back" else "Retour",color=palette.primary)}
            ChatProgress(question,messages,showExplainer,palette,Modifier.weight(1f))
        }
    }
}

@Composable private fun MossMessageView(message:MossMessage,depth:Int,palette:InputPalette,assistive:Boolean) {
    val opacity=(1f-depth*.32f).coerceAtLeast(0f)
    val scale=(1f-depth*.04f).coerceAtLeast(.82f)
    Row(Modifier.fillMaxWidth().blur((depth*1.5f).dp).graphicsLayer {alpha=opacity;scaleX=scale;scaleY=scale;transformOrigin=TransformOrigin(.5f,0f)},horizontalArrangement=if(message.sender==MossSender.USER)Arrangement.End else Arrangement.Start) {
        val user=message.sender==MossSender.USER
        val base=Modifier.padding(start=if(user)56.dp else 0.dp,end=if(user)0.dp else 40.dp)
        if(user)Text(message.text,base.clip(RoundedCornerShape(17.5.dp)).background(Color(0xFF2C2C2E)).padding(horizontal=16.dp,vertical=10.dp),color=Color.White,fontSize=15.sp,fontWeight=FontWeight.Medium,textAlign=TextAlign.End)
        else Text(buildAnnotatedString {append(message.text);if(!message.done)addStyle(SpanStyle(color=Color.Transparent),message.visibleEnd,message.text.length)},
            base.semantics {if(assistive)liveRegion=LiveRegionMode.Polite},fontSize=22.08.sp,color=palette.primary)
    }
}

@Composable private fun ChatPrimaryButton(title:String,palette:InputPalette,onClick:()->Unit) {
    Button(onClick=onClick,modifier=Modifier.fillMaxWidth().heightIn(min=54.dp),shape=RoundedCornerShape(28.dp),colors=ButtonDefaults.buttonColors(containerColor=palette.primary,contentColor=palette.background)) {Text(title,fontSize=16.sp,fontWeight=FontWeight.SemiBold)}
}

@Composable private fun ChatProfileSummary(progress:ProfileChatProgress,english:Boolean,palette:InputPalette,onContinue:()->Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(palette.primary.copy(alpha=.05f)).padding(20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
        Text(if(english) "● DASHBOARD READY" else "● DASHBOARD PRÊT",Modifier.clip(RoundedCornerShape(20.dp)).background(Color(.18f,.72f,.44f,.12f)).padding(horizontal=12.dp,vertical=6.dp),color=Color(.18f,.72f,.44f),fontSize=12.sp,fontWeight=FontWeight.Bold,letterSpacing=.7.sp)
        Text(if(english) "Built around you" else "Construit autour de toi",fontSize=23.sp,fontWeight=FontWeight.Bold,color=palette.primary)
        Text(if(english) "Everything you told me, locked in." else "Tout ce que tu m’as dit, c’est verrouillé.",fontSize=15.sp,color=palette.muted)
        ProcessProfileChatModel.summary(progress,english).forEach {section->
            Column(verticalArrangement=Arrangement.spacedBy(6.dp)) {
                Text(section.title.uppercase(),fontSize=11.sp,fontWeight=FontWeight.SemiBold,letterSpacing=.6.sp,color=palette.muted)
                section.chips.forEach {Text(it,Modifier.clip(RoundedCornerShape(24.dp)).background(palette.primary.copy(alpha=.06f)).padding(horizontal=10.dp,vertical=6.dp),fontSize=13.sp,fontWeight=FontWeight.Medium,color=palette.primary)}
            }
        }
        ChatPrimaryButton(if(english) "See my dashboard" else "Voir mon dashboard",palette,onContinue)
    }
}

@Composable private fun ChatProgress(question:ProfileChatQuestion?,messages:List<MossMessage>,explainer:Boolean,palette:InputPalette,modifier:Modifier) {
    val id=question?.id
    val intro=id?.startsWith("intro_")==true
    val total=if(intro||explainer)4 else 5
    val index=if(explainer||id==null||id=="profile_summary")total else when(id) {
        "intro_swollen_face"->if(messages.any {it.id=="process.chat.intro_swollen_face.1"})1 else 0
        "intro_causes"->2;"intro_next"->3;else->(ProcessProfileChatModel.order.indexOf(id)-3).coerceIn(0,4)
    }
    val line=messages.lastOrNull {it.sender==MossSender.MOSS}
    val fraction=if(line==null||line.text.isEmpty())0f else (line.visibleEnd.toFloat()/line.text.length).coerceIn(0f,1f)
    Row(modifier.semantics {progressBarRangeInfo=ProgressBarRangeInfo((index+fraction).coerceAtMost(total.toFloat()),0f..total.toFloat())},horizontalArrangement=Arrangement.spacedBy(4.dp)) {
        repeat(total) {i->Box(Modifier.weight(1f).height(3.dp).clip(RoundedCornerShape(2.dp)).background(palette.primary.copy(alpha=.15f))) {
            Box(Modifier.fillMaxHeight().fillMaxWidth(if(i<index)1f else if(i==index)fraction else 0f).background(palette.primary))
        }}
    }
}

@Composable private fun MossBlueArc(dark:Boolean,reduced:Boolean) {
    var time by remember {mutableDoubleStateOf(0.0)}
    val owner=LocalLifecycleOwner.current
    LaunchedEffect(reduced,owner) {if(!reduced)owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {while(true) {time=SystemClock.uptimeMillis()/1000.0;delay(50)}}}
    Canvas(Modifier.fillMaxSize().blur(34.dp).clearAndSetSemantics {}) {
        val phase=if(reduced).3 else (sin(time*.1)+1)/2
        val breath=if(reduced).5 else (sin(time*.6)+1)/2
        val colors=listOf(Color(.42f,.72f,1f,.95f),Color(.22f,.47f,.98f,.92f),Color(.08f,.38f,.96f,.90f),Color(.35f,.62f,1f,.88f),Color(.22f,.47f,.98f,.92f))
        val scaled=phase*4;val index=scaled.toInt().coerceAtMost(3);val color=lerp(colors[index],colors[index+1],(scaled-index).toFloat())
        val alpha=((.48+.22*breath)*(if(dark)1.05 else .62)).toFloat()
        drawRect(Brush.radialGradient(listOf(color,color.copy(alpha=color.alpha*.62f),color.copy(alpha=color.alpha*.4f),color.copy(alpha=color.alpha*.24f),color.copy(alpha=color.alpha*.1f),Color.Transparent),center=Offset(size.width/2,size.height*(1.16f+.03f*breath.toFloat())),radius=size.height*(.34f+.08f*breath.toFloat())),alpha=alpha,blendMode=BlendMode.Screen)
    }
}
