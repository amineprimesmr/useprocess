package com.process.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext

@Composable internal fun ProcessFoodHubGallery(onClose:()->Unit,onHydration:()->Unit,english:Boolean) {
 val context=LocalContext.current;val prefs=remember {FoodPreferenceStore(context,"catalog-foodhub-preview")}
 var selectedFood by remember {mutableStateOf<DebloatFood?>(null)}
 var selectedRecipe by remember {mutableStateOf<ProcessRecipe?>(null)}
 var all by remember {mutableStateOf(false)};var notice by remember {mutableStateOf<String?>(null)}
 Column(Modifier.fillMaxSize().safeDrawingPadding()) {
  if(selectedRecipe!=null)ProcessRecipeDetail(selectedRecipe!!,{selectedRecipe=null},english=english)
  else if(all)ProcessFoodCatalogPage(prefs,{notice=if(english)"Preview: grocery persistence is not connected."else"Aperçu : la sauvegarde des courses n’est pas raccordée."},{all=false},english=english)
  else {
   TextButton(onClick=onClose){Text(if(english)"Close — browse preview, no connected plan"else"Fermer — aperçu sans plan connecté")}
   ProcessFoodHub({selectedFood=it},{selectedRecipe=it.meal},{all=true},onHydration,{notice=if(english)"The Android meal scanner is not connected yet."else"Le scanner alimentaire Android reste à raccorder."},english=english)
  }
 }
 selectedFood?.let {ProcessFoodDetailSheet(it,prefs,{notice=if(english)"Preview: grocery persistence is not connected."else"Aperçu : la sauvegarde des courses n’est pas raccordée."},{selectedFood=null},english)}
 notice?.let {AlertDialog(onDismissRequest={notice=null},title={Text(if(english)"Preview"else"Aperçu")},text={Text(it)},confirmButton={TextButton(onClick={notice=null}){Text("OK")}})}
}
