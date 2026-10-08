package com.tenkdesign.android

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.*
import kotlinx.coroutines.CancellationException
import kotlin.math.sin

@Composable fun TenKWaveformGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    val context=LocalContext.current
    var uri by remember {mutableStateOf<Uri?>(null)}
    // The original archive does not contain Audio.wav. This is an explicitly synthetic visual sample.
    var audio by remember {mutableStateOf(WaveformAudio(FloatArray(8000){i->(sin(i*.073)*(.25+.7*(i%711)/711.0)).toFloat()},8000))}
    var error by remember {mutableStateOf<String?>(null)}
    var loading by remember {mutableStateOf(false)}
    var progress by remember {mutableFloatStateOf(.32f)}
    var active by remember {mutableStateOf(false)}
    var imported by remember {mutableStateOf(false)}
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){if(it!=null)uri=it}
    LaunchedEffect(uri) {
        val source=uri?:return@LaunchedEffect
        loading=true;error=null
        try {audio=loadLocalWaveform(context,source);progress=0f;imported=true}
        catch(cancel:CancellationException){throw cancel}
        catch(_:Exception){error="Impossible de lire ce WAV. Formats pris en charge : PCM 16/24/32 bits et float32, 64 Mio maximum."}
        finally {loading=false}
    }
    val scale by animateFloatAsState(if(active)1.4f else 1f,if(reduceMotion)snap()else spring(.75f,650f),label="waveform.drag.scale")
    val ink=if(isSystemInDarkTheme())Color.White else Color.Black
    Column(modifier.fillMaxSize().background(if(isSystemInDarkTheme())Color.Black else Color.White).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
        Text("Waveform Scrubber",fontSize=28.sp,lineHeight=34.sp,color=ink)
        Text(if(imported)"Fichier local — contrôle de position uniquement"else"Signal synthétique — Audio.wav absent de l’archive originale",color=Color.Gray)
        OutlinedButton(onClick={picker.launch(arrayOf("audio/wav","audio/x-wav","audio/wave"))},enabled=!loading){Text(if(loading)"Chargement…"else"Choisir un WAV")}
        error?.let {Text(it,color=MaterialTheme.colorScheme.error)}
        Column(verticalArrangement=Arrangement.spacedBy(6.dp)) {
            TenKWaveformScrubber(audio.firstChannel,progress,{progress=it},Modifier.graphicsLayer {scaleY=scale},WaveformConfig(activeTint=ink),{active=it})
            Row(Modifier.padding(horizontal=10.dp).padding(bottom=5.dp)) {
                Text(WaveformModel.clock(audio.durationSeconds*progress),fontSize=14.sp,fontFamily=FontFamily.Monospace,color=Color.Gray)
                Spacer(Modifier.weight(1f))
                Text(WaveformModel.clock(audio.durationSeconds),fontSize=14.sp,fontFamily=FontFamily.Monospace,color=Color.Gray)
            }
        }
    }
}
