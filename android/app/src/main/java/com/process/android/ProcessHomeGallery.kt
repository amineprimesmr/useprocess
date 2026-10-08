package com.process.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.time.*
@Composable fun ProcessHomeGallery(onBack:()->Unit,onFood:()->Unit,onProfile:()->Unit,onRoutine:()->Unit,onReferral:()->Unit,english:Boolean=false,onScan:(()->Unit)?=null) {
 val today=LocalDate.now();var hasPlan by remember {mutableStateOf(true)};var water by remember {mutableIntStateOf(0)};var complete by remember {mutableStateOf(emptySet<String>())};var welcome by remember {mutableStateOf(WelcomeCardDismissal())};var message by remember {mutableStateOf<String?>(null)}
 val snapshot=ProcessHomeSnapshot("gallery:$today","",if(hasPlan)HomePlanCalendar("fixture-plan",today,28)else null,today,localWaterMl=water,hasLocalWaterAdjustment=true,meals=listOf(HomeMealTile("breakfast","recipe_meal_debloat_eggs_banana_kiwi"),HomeMealTile("lunch","recipe_meal_debloat_chicken_sweet_potato"),HomeMealTile("dinner","recipe_meal_debloat_salmon_quinoa_salad")),completedRoutineIds=complete)
 Column(Modifier.fillMaxSize().safeDrawingPadding()) {
  Row {TextButton(onBack){Text("Retour")};TextButton({hasPlan=!hasPlan}){Text(if(hasPlan)"Aperçu · avec plan"else"Aperçu · sans plan")}}
  ProcessHomeDashboard(snapshot,onProfile,{if(onScan!=null)onScan()else message="La capture visage réelle doit être connectée."},{message="Aucun scan personnel dans cet aperçu."},onFood,{_,ml->water=ml},{onRoutine()},{onRoutine()},{complete=complete+it.stepId},{},{},welcome,{welcome=it},onReferral,Modifier.weight(1f),english)
 }
 message?.let {text->AlertDialog(onDismissRequest={message=null},text={Text(text)},confirmButton={TextButton({message=null}){Text("Fermer")}})}
}
