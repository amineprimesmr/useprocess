package com.process.android
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Original welcome/referral deck. Host owns plan readiness, rewards and tutorial suppression. */
@Composable fun ProcessWelcomeCards(
    dismissal:WelcomeCardDismissal,onDismissalChange:(WelcomeCardDismissal)->Unit,onOpenReferral:()->Unit,
    modifier:Modifier=Modifier,tutorialConstrainsLayout:Boolean=false,english:Boolean=false,
    reduceMotion:Boolean=rememberProcessReducedMotion(),
) {
    val state=dismissal.normalized()
    val haptic=LocalHapticFeedback.current
    val latestState by rememberUpdatedState(state)
    val change by rememberUpdatedState(onDismissalChange)
    fun dismissTop() {haptic.performHapticFeedback(HapticFeedbackType.LongPress);change(latestState.dismissTop())}
    val floatSpec:FiniteAnimationSpec<Float> = if(reduceMotion)snap()else spring(.88f,273.4f)
    val positionSpec:FiniteAnimationSpec<androidx.compose.ui.unit.IntOffset> = if(reduceMotion)snap()else spring(.88f,273.4f)
    val backScale by animateFloatAsState(if(state.frontDismissed)1f else .945f,floatSpec,label="welcome.back.scale")
    val backY by animateFloatAsState(if(state.frontDismissed)0f else 11f,floatSpec,label="welcome.back.offset")
    val backAlpha by animateFloatAsState(if(state.frontDismissed)1f else .72f,floatSpec,label="welcome.back.alpha")
    AnimatedVisibility(!state.stackDismissed&&!tutorialConstrainsLayout,modifier,enter=EnterTransition.None,exit=slideOutHorizontally(positionSpec){-it}+fadeOut(floatSpec)) {
        Box(Modifier.fillMaxWidth().padding(top=18.dp).padding(bottom=backY.dp)) {
            WelcomeCard(true,state.frontDismissed,{haptic.performHapticFeedback(HapticFeedbackType.LongPress);onOpenReferral()},::dismissTop,english,Modifier.graphicsLayer {scaleX=backScale;translationY=backY* density;alpha=backAlpha;transformOrigin=TransformOrigin(.5f,0f)})
            AnimatedVisibility(!state.frontDismissed,enter=EnterTransition.None,exit=slideOutHorizontally(positionSpec){-it}+fadeOut(floatSpec)) {
                WelcomeCard(false,true,::dismissTop,::dismissTop,english,Modifier)
            }
        }
    }
}
@Composable private fun WelcomeCard(referral:Boolean,interactive:Boolean,onTap:()->Unit,onClose:()->Unit,english:Boolean,modifier:Modifier) {
    val shape=RoundedCornerShape(24.dp)
    val title=if(referral){if(english)"🎁 Free month or year"else"🎁 Mois ou an offert"}else{if(english)"Welcome to Process"else"Bienvenue dans Process"}
    val subtitle=if(referral){if(english)"Share your link. Earn 1 free month or year for each friend who subscribes."else"Partage ton lien. Tu gagnes 1 mois ou 1 an offert par ami abonné."}else{if(english)"Your plan is ready. Scan, follow the program, and move forward every day."else"Ton plan est prêt. Scanne, suis le programme et avance chaque jour."}
    Box(modifier.fillMaxWidth().height(148.dp).shadow(8.dp,shape,ambientColor=Color.Black.copy(alpha=.22f),spotColor=Color.Black.copy(alpha=.22f)).clip(shape).border(.6.dp,Color.White.copy(alpha=.10f),shape).then(if(!interactive)Modifier.clearAndSetSemantics {}else Modifier)) {
        Box(Modifier.fillMaxSize().clickable(enabled=interactive,role=Role.Button,onClick=onTap)) {
            Box(Modifier.fillMaxSize().background(Color(.055f,.063f,.086f)))
            Image(painterResource(R.drawable.welcome_nebula),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop,alpha=.94f)
            Box(Modifier.fillMaxSize().drawWithCache {
                val radial=Brush.radialGradient(0f to Color(.62f,.66f,.74f,.16f),4f/220f to Color(.62f,.66f,.74f,.16f),1f to Color.Transparent,center=Offset(size.width*.14f,size.height*.92f),radius=220.dp.toPx())
                val linear=Brush.linearGradient(listOf(Color(.55f,.60f,.70f,.10f),Color.Transparent,Color.White.copy(alpha=.04f)),start=Offset(0f,size.height),end=Offset(size.width*.92f,size.height*.08f))
                onDrawBehind {drawRect(radial);drawRect(linear)}
            })
            Image(painterResource(if(referral)R.drawable.welcome_dollar else R.drawable.welcome_mark),null,Modifier.align(Alignment.CenterEnd).size(148.dp).offset(x=22.dp,y=6.dp).drawWithCache {
                val x=Brush.horizontalGradient(0f to Color.Transparent,.22f to Color.White.copy(alpha=.12f),.48f to Color.White.copy(alpha=.55f),.72f to Color.White.copy(alpha=.92f),1f to Color.White.copy(alpha=.55f))
                val y=Brush.verticalGradient(0f to Color.White.copy(alpha=.35f),.28f to Color.White,.62f to Color.White.copy(alpha=.82f),1f to Color.White.copy(alpha=.08f))
                val paint=Paint().apply {blendMode=if(referral)BlendMode.SrcOver else BlendMode.Plus;alpha=if(referral).92f else .88f}
                onDrawWithContent {drawContext.canvas.saveLayer(Rect(Offset.Zero,size),paint);drawContent();drawRect(x,blendMode=BlendMode.DstIn);drawRect(y,blendMode=BlendMode.DstIn);drawContext.canvas.restore()}
            },contentScale=ContentScale.Fit)
            Column(Modifier.fillMaxSize().padding(start=16.dp,end=if(referral)92.dp else 44.dp,top=16.dp,bottom=14.dp),verticalArrangement=Arrangement.spacedBy(if(referral)7.dp else 5.dp)) {
                Text(title,fontSize=if(referral)21.sp else 17.sp,fontWeight=FontWeight.Bold,letterSpacing=if(referral)(-.36).sp else (-.28).sp,color=Color.White,maxLines=if(referral)2 else 1,overflow=TextOverflow.Ellipsis)
                Text(subtitle,fontSize=13.sp,lineHeight=17.sp,color=Color(.82f,.82f,.84f),maxLines=2,overflow=TextOverflow.Ellipsis)
            }
        }
        CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
        IconButton(onClick=onClose,enabled=interactive,modifier=Modifier.align(Alignment.TopEnd).padding(top=10.dp,end=10.dp).size(30.dp).background(Color.Black.copy(alpha=.42f),CircleShape).border(.7.dp,Color.White.copy(alpha=.28f),CircleShape)) {
            Icon(Icons.Default.Close,if(english)"Close"else"Fermer",Modifier.size(12.dp),tint=Color.White.copy(alpha=.94f))
        }
        }
    }
}
