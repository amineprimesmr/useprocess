package com.process.android
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
@Composable fun ProcessMealAnalysisGallery(onBack:()->Unit,english:Boolean=false) {
 var complete by remember {mutableStateOf(false)};var revealed by remember {mutableStateOf(false)};var attempt by remember {mutableIntStateOf(0)}
 Column(Modifier.fillMaxSize().safeDrawingPadding()) {
  Row {TextButton(onBack){Text("Retour")};TextButton({complete=true}){Text("Résultat fictif prêt")};TextButton({attempt++;complete=false;revealed=false}){Text("Rejouer")}}
  ProcessMealAnalyzing("fixture:$attempt",complete,{revealed=true},Modifier.weight(1f),english,photo={Image(painterResource(R.drawable.recipe_meal_debloat_chicken_salad_bowl),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop)})
 }
 if(revealed)AlertDialog(onDismissRequest={revealed=false},text={Text("Aperçu de l’animation uniquement. Aucune analyse nutritionnelle effectuée.")},confirmButton={TextButton({revealed=false}){Text("OK")}})
}
