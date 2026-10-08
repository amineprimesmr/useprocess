package com.process.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier

@Composable internal fun ProcessProfileGallery(onClose:()->Unit,onSettings:()->Unit,english:Boolean) {
 var calendar by remember {mutableStateOf(false)}
 Column(Modifier.fillMaxSize().safeDrawingPadding()) {
  if(calendar)ProcessProgramCalendar(null,emptyList(),emptyList(),0,{calendar=false},english=english)
  else {
   TextButton(onClick=onClose){Text(if(english)"Close — no connected profile"else"Fermer — aucun profil connecté")}
   ProcessProfileProgress(null,onSettings,{calendar=true},english=english)
  }
 }
}
