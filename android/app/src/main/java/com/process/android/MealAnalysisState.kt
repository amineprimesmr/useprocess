package com.process.android
import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay

enum class MealAnalysisStepStatus { PENDING,LOADING,COMPLETED }
data class MealAnalysisStep(val id:String,val french:String,val english:String){fun title(english:Boolean)=if(english)this.english else french}
val processMealAnalysisSteps=listOf(
 MealAnalysisStep("ingredients","Récolte des ingrédients","Collecting ingredients"),MealAnalysisStep("potassium","Analyse du potassium","Analyzing potassium"),MealAnalysisStep("sodium","Analyse du sodium","Analyzing sodium"),MealAnalysisStep("magnesium","Analyse du magnésium","Analyzing magnesium"),MealAnalysisStep("balance","Équilibre K / Na","K / Na balance"),MealAnalysisStep("score","Calcul du score debloat","Computing debloat score")
)
@Stable internal class MealAnalysisState {
 val statuses=mutableStateListOf(*Array(6){MealAnalysisStepStatus.PENDING})
 var activeIndex by mutableIntStateOf(0)
 var ready by mutableStateOf(false)
 var backendComplete by mutableStateOf(false)
 var notified=false
}
/** Visual stage timings are source choreography, not proof that individual backend phases finished. */
@Composable internal fun rememberMealAnalysisState(contextKey:String,complete:Boolean,failure:String?,onReveal:()->Unit):MealAnalysisState {
 require(contextKey.isNotBlank())
 val state=remember(contextKey){MealAnalysisState()};val lifecycle=LocalLifecycleOwner.current.lifecycle
 val latestError by rememberUpdatedState(failure);val callback by rememberUpdatedState(onReveal)
 SideEffect {if(complete)state.backendComplete=true}
 LaunchedEffect(state,lifecycle) {
  lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
   if(state.ready)return@repeatOnLifecycle
   val next=state.statuses.count {it==MealAnalysisStepStatus.COMPLETED}
   for(index in next..5) {
    while(latestError!=null)delay(120)
    state.activeIndex=index;state.statuses[index]=MealAnalysisStepStatus.LOADING
    delay(850)
    if(index==5)while(!state.backendComplete||latestError!=null)delay(120)
    else if(state.backendComplete)delay(180) // Preserve actual source timing,despite its "accelerate" comment.
    while(latestError!=null)delay(120)
    state.statuses[index]=MealAnalysisStepStatus.COMPLETED
   }
   delay(320)
   while(!state.backendComplete||latestError!=null)delay(120)
   state.ready=true
   if(!state.notified){state.notified=true;callback()}
  }
 }
 return state
}
