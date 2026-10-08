package com.process.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@Composable fun ProcessFaceCaptureGallery(onBack:()->Unit,english:Boolean=false) {
 var message by remember {mutableStateOf(false)}
 Column(Modifier.fillMaxSize()) {
  Text(if(english)"Camera preview · analysis is not connected"else"Aperçu caméra · analyse non connectée",style=MaterialTheme.typography.labelSmall,modifier=Modifier.padding(8.dp))
  ProcessFaceCapture("camera-gallery",onBack,{message=true;false},Modifier.weight(1f),english)
 }
 if(message)AlertDialog(onDismissRequest={message=false},title={Text(if(english)"Local photo"else"Photo locale")},text={Text(if(english)"This preview does not analyze or upload the photo. Retake or close to discard it."else"Cet aperçu n’analyse et n’envoie pas la photo. Reprends-la ou ferme l’écran pour la supprimer.")},confirmButton={TextButton({message=false}){Text("OK")}})
}
