package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.unit.*

@Composable internal fun ProcessTutorialGallery(onClose:()->Unit,english:Boolean) {
 var completed by remember {mutableStateOf(false)};var tab by remember {mutableStateOf("plan")}
 val state=rememberHomeTutorialState("tutorial-gallery-fixture",completed,{completed=true})
 ProcessHomeTutorialCoordinator(state,true,true,tab,{tab=it},{})
 val p=ProcessSurfacePalette(isSystemInDarkTheme())
 Column(Modifier.fillMaxSize().background(p.background).safeDrawingPadding()) {
  TextButton(onClick=onClose){Text(if(english)"Close — tutorial preview"else"Fermer — aperçu du tutoriel")}
  if(completed)Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Text(if(english)"Preview complete. No account was modified."else"Aperçu terminé. Aucun compte modifié.")}
  else Box(Modifier.weight(1f).fillMaxWidth().padding(22.dp)) {
   if(!state.progress.step.isTabStep)Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
    ProcessHomeTutorial(state,state.progress.step,english=english) {
     Box(Modifier.fillMaxWidth().height(190.dp).background(p.strongCard,RoundedCornerShape(30.dp)),contentAlignment=Alignment.Center){Text(if(english)"Host card preview"else"Aperçu de carte hôte",color=p.secondary)}
    }
   }else {
    Text(if(english)"Profile tab preview"else"Aperçu de l’onglet Profil",Modifier.align(Alignment.TopCenter),color=p.primary)
    ProcessTutorialTabFooter(state,Modifier.align(Alignment.BottomCenter),english)
   }
  }
 }
}
