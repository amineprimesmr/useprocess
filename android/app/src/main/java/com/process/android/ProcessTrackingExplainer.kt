package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*

/** The live TransformationPreviewStepView has no fabricated before/after studies. */
@Composable fun ProcessTrackingExplainer(onContinue:()->Unit,modifier:Modifier=Modifier,english:Boolean=false,dark:Boolean=isSystemInDarkTheme()) {
    val palette=InputPalette(dark)
    Column(modifier.fillMaxSize().background(palette.background).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            Text(if(english) "Tracking that starts with you" else "Un suivi qui part de toi",fontSize=28.sp,fontWeight=FontWeight.Bold,color=palette.primary)
            Text(if(english) "Compare your own scans under similar conditions and keep track of your habits. Results vary: Process does not guarantee a physical transformation." else "Observe tes propres scans dans des conditions similaires et garde une trace de tes habitudes. Les résultats varient selon les personnes : Process ne garantit pas de transformation physique.",fontSize=17.sp,color=palette.body)
            Text(if(english) "Scan scores are wellness estimates, not medical measurements or a diagnosis." else "Les scores du scan sont des estimations de bien-être, pas des mesures médicales ni un diagnostic.",fontSize=17.sp,color=palette.body)
        }
        Button(onClick=onContinue,modifier=Modifier.fillMaxWidth().heightIn(min=58.dp),shape=RoundedCornerShape(29.dp),colors=ButtonDefaults.buttonColors(containerColor=palette.primary,contentColor=palette.background)) {
            Text(if(english) "CONTINUE" else "CONTINUER",fontSize=22.sp,fontWeight=FontWeight.Black)
        }
    }
}
