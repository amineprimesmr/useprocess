package com.process.android
import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.*
import kotlinx.coroutines.delay

/** Recreate by account identity. Host persists completion; this library never creates a missing plan. */
@Stable class HomeTutorialState internal constructor(completed:Boolean) {
 var progress by mutableStateOf(HomeTutorialProgress(completed=completed));private set
 internal val visibleCTA=mutableStateMapOf<HomeTutorialStep,Boolean>()
 internal var onCompleted:()->Unit={}
 fun begin(planAvailable:Boolean,suppressed:Boolean=false){progress=progress.begin(planAvailable,suppressed)}
 fun suspendPresentation(){progress=progress.copy(active=false);visibleCTA.clear()}
 fun advance(){val next=progress.advance();if(next.completed&&!progress.completed)complete()else progress=next}
 fun skip(){complete()}
 fun complete(){val changed=!progress.completed;progress=progress.finish();visibleCTA.clear();if(changed)onCompleted()}
 internal fun syncCompleted(){progress=progress.finish();visibleCTA.clear()}
}
@Composable fun rememberHomeTutorialState(contextKey:String,completed:Boolean,onCompleted:()->Unit):HomeTutorialState {
 require(contextKey.isNotBlank())
 val state=remember(contextKey){HomeTutorialState(completed)};val callback by rememberUpdatedState(onCompleted)
 SideEffect {state.onCompleted={callback()}}
 LaunchedEffect(state,completed){if(completed)state.syncCompleted()}
 return state
}
/** Mount beside the host's real home and tabs. Supplying selectedTab changes lets manual navigation end the tutorial. */
@Composable fun ProcessHomeTutorialCoordinator(
 state:HomeTutorialState,planAvailable:Boolean,homeMounted:Boolean,selectedTab:String,onTabRequested:(String)->Unit,
 onFocusRequested:(HomeTutorialStep)->Unit,previewSuppressed:Boolean=false,preferImmediate:Boolean=true,
) {
 val life by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
 val active=state.progress.active;val step=state.progress.step
 val tabCallback by rememberUpdatedState(onTabRequested);val focusCallback by rememberUpdatedState(onFocusRequested)
 LaunchedEffect(state,planAvailable,previewSuppressed,life) {
  if(previewSuppressed)state.suspendPresentation()
  if(planAvailable&&!previewSuppressed&&life.isAtLeast(Lifecycle.State.RESUMED)) {
   if(!preferImmediate)delay(180)
   state.begin(planAvailable,previewSuppressed)
  }
 }
 LaunchedEffect(state,active,step) {if(active){tabCallback(step.requestedTab);if(!step.isTabStep)focusCallback(step)}}
 // Key only the actual selected tab: a requested target must not turn the old tab into a false manual departure.
 var observedTab by remember(state){mutableStateOf(selectedTab)}
 LaunchedEffect(state,selectedTab){val changed=observedTab!=selectedTab;observedTab=selectedTab;if(changed&&state.progress.active&&selectedTab!=state.progress.step.requestedTab)state.skip()}
 val visible=state.visibleCTA[step]==true
 LaunchedEffect(state,active,step,homeMounted,visible,life) {
  if(active&&!step.isTabStep&&homeMounted&&!visible&&life.isAtLeast(Lifecycle.State.RESUMED)) {
   delay(1500)
   if(state.progress.active&&state.progress.step==step&&state.visibleCTA[step]!=true)state.complete()
  }
 }
}
