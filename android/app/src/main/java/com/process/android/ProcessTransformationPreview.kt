package com.process.android

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.interaction.*
import androidx.compose.ui.graphics.graphicsLayer
import kotlinx.coroutines.delay
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Current live Process deliberately has no testimonial or published before/after catalog. */
@Composable fun ProcessTransformationPreview(onContinue:()->Unit,modifier:Modifier=Modifier,english:Boolean=false) {
    val dark=isSystemInDarkTheme();val palette=InputPalette(dark)
    val interaction=remember {MutableInteractionSource()}
    val pressed by interaction.collectIsPressedAsState()
    var showsPress by remember {mutableStateOf(false)}
    val reduceMotion=rememberProcessReducedMotion()
    LaunchedEffect(pressed) {if(pressed)showsPress=true else {delay(120);showsPress=false}}
    val scale by animateFloatAsState(if(showsPress&&!reduceMotion).96f else 1f,spring(.7f,631.65f),label="transformation.continue.press")
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background)) {
        val minimumHeight=maxHeight
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min=minimumHeight).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            Text(if(english)"Tracking that starts with you"else"Un suivi qui part de toi",fontSize=28.sp,fontWeight=FontWeight.Bold,color=palette.primary)
            Text(if(english)"Compare your own scans under similar conditions and keep track of your habits. Results vary: Process does not guarantee a physical transformation."else"Observe tes propres scans dans des conditions similaires et garde une trace de tes habitudes. Les résultats varient selon les personnes : Process ne garantit pas de transformation physique.",fontSize=17.sp,lineHeight=23.sp,color=palette.body)
            Text(if(english)"Scan scores are wellness estimates, not medical measurements or a diagnosis."else"Les scores du scan sont des estimations de bien-être, pas des mesures médicales ni un diagnostic.",fontSize=17.sp,lineHeight=23.sp,color=palette.body)
            Spacer(Modifier.weight(1f).heightIn(min=16.dp))
            Button(onClick=onContinue,interactionSource=interaction,modifier=Modifier.fillMaxWidth().height(58.dp).graphicsLayer {scaleX=scale;scaleY=scale;alpha=if(pressed).92f else 1f},shape=RoundedCornerShape(29.dp),colors=ButtonDefaults.buttonColors(containerColor=if(dark)Color.White else Color.Black,contentColor=if(dark)Color.Black else Color.White)) {
                Text(if(english)"CONTINUE"else"CONTINUER",fontSize=22.sp,fontWeight=FontWeight.Black)
            }
        }
    }
}
