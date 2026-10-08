package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay

private val FaceAccent=Color(.22f,.47f,.98f)

/** Original narrative/assets/reveal order; the host owns profile state and navigation. */
@Composable fun ProcessFaceLeverageIntro(
    firstName:String,
    onContinue:()->Unit,
    modifier:Modifier=Modifier,
    female:Boolean=false,
    onViewed:()->Unit={},
    english:Boolean=false,
    dark:Boolean=isSystemInDarkTheme(),
    reduceMotion:Boolean=rememberProcessReducedMotion()
) {
    val palette=InputPalette(dark)
    val viewed by rememberUpdatedState(onViewed)
    val haptics=LocalHapticFeedback.current
    var revealCount by remember {mutableIntStateOf(0)}
    val greeting=OnboardingInputRules.trimName(firstName).takeIf(OnboardingInputRules::isRealName) ?: if(english) "You" else "Toi"
    LaunchedEffect(Unit) {viewed()}
    LaunchedEffect(reduceMotion) {
        if(reduceMotion)revealCount=9 else {
            val times=listOf(80L,180L,300L,300L,440L,520L,680L,800L,920L)
            var previous=0L
            times.forEachIndexed {index,time->delay(time-previous);revealCount=index+1;previous=time}
        }
        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
    }
    Column(modifier.fillMaxSize().background(palette.background)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal=24.dp).padding(top=60.dp,bottom=24.dp)) {
            Row(horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.Top) {
                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                    FaceReveal(0,revealCount,reduceMotion) {Text("$greeting,",fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=FaceAccent)}
                    FaceReveal(1,revealCount,reduceMotion) {
                        Text(buildAnnotatedString {
                            withStyle(SpanStyle(color=palette.primary)) {append(if(english) "Your face is " else "Ton visage est ")}
                            withStyle(SpanStyle(color=FaceAccent)) {append(if(english) "your leverage." else "ton levier.")}
                        },fontSize=30.sp,fontWeight=FontWeight.Bold)
                    }
                    FaceReveal(2,revealCount,reduceMotion) {
                        Text(if(english) "A sharper face, and people take you more seriously — before you even speak." else "Un visage plus net, et on te prend plus au sérieux. Avant même que tu parles.",Modifier.padding(top=2.dp),fontSize=13.sp,lineHeight=17.sp,color=palette.body)
                    }
                }
                FaceReveal(3,revealCount,reduceMotion) {
                    Box(Modifier.size(112.dp,124.dp).shadow(16.dp,RoundedCornerShape(24.dp)).clip(RoundedCornerShape(24.dp))
                        .border(1.dp,Color.White.copy(alpha=if(dark).16f else .55f),RoundedCornerShape(24.dp))) {
                        Image(painterResource(if(female)R.drawable.avaprime else R.drawable.mannyprime_leverage),null,Modifier.size(112.dp,124.dp).offset(y=(-22).dp),contentScale=ContentScale.Crop,alignment=Alignment.TopCenter)
                    }
                }
            }
            Spacer(Modifier.height(64.dp))
            FaceReveal(4,revealCount,reduceMotion) {Text(if(english) "WHAT CHANGES" else "CE QUE ÇA CHANGE",fontSize=12.sp,fontWeight=FontWeight.Bold,letterSpacing=1.1.sp,color=FaceAccent)}
            Spacer(Modifier.height(14.dp))
            FaceReveal(5,revealCount,reduceMotion) {
                Column(Modifier.faceCard(palette,24).padding(20.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
                    Text(if(english) "Android version" else "Version Android",Modifier.padding(start=10.dp),fontSize=13.sp,fontWeight=FontWeight.Medium,color=palette.muted)
                    Text(if(english) "Track your habits at your own pace." else "Des habitudes à suivre, à ton rythme.",fontSize=22.sp,fontWeight=FontWeight.Bold,color=palette.primary)
                    Text(if(english) "Scan, plan and AI coach" else "Scan, plan et coach IA",fontSize=13.sp,fontWeight=FontWeight.Medium,color=palette.muted)
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.Top) {
                FaceReveal(6,revealCount,reduceMotion,Modifier.weight(1f)) {
                    Column(Modifier.faceCard(palette,22).heightIn(min=236.dp).padding(18.dp)) {
                        FaceIcon(0)
                        Spacer(Modifier.height(48.dp))
                        Text(if(english) "First impression" else "Première impression",fontSize=18.sp,fontWeight=FontWeight.Bold,color=palette.primary)
                        Text(if(english) "They judge you in 3 seconds. Your face speaks first." else "On te juge en 3 secondes. Ton visage parle avant toi.",Modifier.padding(top=4.dp),fontSize=14.sp,fontWeight=FontWeight.Medium,color=palette.body)
                    }
                }
                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(18.dp)) {
                    FaceReveal(7,revealCount,reduceMotion) {FaceSmallCard(if(english) "Presence" else "Présence",if(english) "People listen more." else "On t’écoute davantage.",1,palette)}
                    FaceReveal(8,revealCount,reduceMotion) {FaceSmallCard(if(english) "Attraction" else "Attirance",if(english) "More looks, more interest." else "Plus de regards, plus d’intérêt.",2,palette)}
                }
            }
        }
        Box(Modifier.fillMaxWidth().background(palette.background.copy(alpha=.96f)).padding(start=34.dp,end=34.dp,top=8.dp,bottom=34.dp)) {
            Button(onClick=onContinue,modifier=Modifier.fillMaxWidth().height(56.dp),shape=RoundedCornerShape(28.dp),colors=ButtonDefaults.buttonColors(containerColor=palette.primary,contentColor=palette.background)) {
                Text(if(english) "Continue" else "Continuer",fontSize=18.sp,fontWeight=FontWeight.Bold)
            }
        }
    }
}

@Composable private fun FaceReveal(index:Int,count:Int,reduced:Boolean,modifier:Modifier=Modifier,content:@Composable ()->Unit) {
    val visible=reduced || index<count
    val progress by animateFloatAsState(if(visible)1f else 0f,if(reduced)snap() else spring(.84f,102.70f),label="face.reveal.$index")
    Box(modifier.graphicsLayer {alpha=progress;translationY=18.dp.toPx()*(1f-progress);scaleX=.97f+.03f*progress;scaleY=scaleX;transformOrigin=TransformOrigin(0f,0f)}
        .then(if(visible)Modifier else Modifier.clearAndSetSemantics {})) {content()}
}

private fun Modifier.faceCard(palette:InputPalette,radius:Int)=fillMaxWidth().clip(RoundedCornerShape(radius.dp))
    .background(if(palette.dark)Color.White.copy(alpha=.07f) else Color.White.copy(alpha=.75f))
    .border(1.dp,palette.primary.copy(alpha=.08f),RoundedCornerShape(radius.dp))

@Composable private fun FaceSmallCard(title:String,subtitle:String,icon:Int,palette:InputPalette) {
    // Minimum height preserves readable large-font content instead of clipping the authored 104dp card.
    Column(Modifier.faceCard(palette,22).heightIn(min=104.dp).padding(14.dp)) {
        FaceIcon(icon)
        Text(title,fontSize=16.sp,fontWeight=FontWeight.Bold,color=palette.primary)
        Text(subtitle,Modifier.padding(top=3.dp),fontSize=12.sp,fontWeight=FontWeight.Medium,color=palette.muted)
    }
}

/** Decorative Android vectors; SF Symbol optical matching remains unverified. */
@Composable private fun FaceIcon(kind:Int) {
    Box(Modifier.padding(bottom=10.dp).size(32.dp).background(FaceAccent.copy(alpha=.14f),CircleShape),contentAlignment=Alignment.Center) {
        Canvas(Modifier.size(16.dp)) {
            val w=size.width;val h=size.height;val stroke=Stroke(1.4.dp.toPx())
            if(kind==0) {
                val eye=Path().apply {moveTo(0f,h/2);quadraticTo(w/2,-h*.15f,w,h/2);quadraticTo(w/2,h*1.15f,0f,h/2);close()}
                drawPath(eye,FaceAccent,style=stroke);drawCircle(FaceAccent,w*.13f)
            } else if(kind==1) {
                drawCircle(FaceAccent,w*.15f,Offset(w*.4f,h*.24f));drawLine(FaceAccent,Offset(w*.4f,h*.48f),Offset(w*.4f,h),stroke.width)
                drawLine(FaceAccent,Offset(w*.15f,h*.65f),Offset(w*.68f,h*.45f),stroke.width)
                drawArc(FaceAccent,-45f,90f,false,topLeft=Offset(w*.3f,h*.03f),size=androidx.compose.ui.geometry.Size(w*.65f,h*.75f),style=stroke)
            } else {
                val heart=Path().apply {moveTo(w/2,h);cubicTo(-w*.4f,h*.3f,w*.1f,-h*.3f,w/2,h*.22f);cubicTo(w*.9f,-h*.3f,w*1.4f,h*.3f,w/2,h);close()}
                drawPath(heart,FaceAccent)
            }
        }
    }
}
