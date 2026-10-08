package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay

@Composable fun TenKGooeyRefreshGallery(onBack:()->Unit,reduceMotion:Boolean=false) {
 var refreshes by remember{mutableIntStateOf(0)};var language by rememberSaveable{mutableStateOf(false)}
 Column(Modifier.fillMaxSize().background(if(isSystemInDarkTheme())Color(0xFF151515) else Color(0xFFF2F2F7)).safeDrawingPadding()) {
  Row(verticalAlignment=Alignment.CenterVertically) {TextButton(onBack){Text(if(language)"Back" else "Retour")};TextButton({language=!language}){Text(if(language)"EN" else "FR")};Text(if(language)"Gooey refresh example" else "Aperçu du rafraîchissement")}
  TenKGooeyRefresh({delay(700);refreshes++},Modifier.weight(1f).fillMaxWidth(),reduceMotion=reduceMotion,refreshLabel=if(language)"Refresh" else "Actualiser") {
   Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(18.dp)) {
    Text(if(language)"Local example — pull down to refresh" else "Exemple local — tire vers le bas pour actualiser")
    repeat(16){Text("${if(language)"Sample row"else"Ligne d’exemple"} ${it+1} · $refreshes",Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface,MaterialTheme.shapes.medium).padding(18.dp))}
   }
  }
 }
}
