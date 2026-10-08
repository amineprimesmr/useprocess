package com.process.android
import androidx.compose.runtime.*
import kotlinx.coroutines.*
import kotlin.coroutines.coroutineContext

/** UI adapter only. Host supplies purchase/restore and verifies Play/backend access before VerifiedAccess. */
@Stable internal class ProcessBillingActions {
 var busy by mutableStateOf(false)
 var completed by mutableStateOf(false)
 var error by mutableStateOf<String?>(null)
 var run:((suspend ()->ProcessBillingResult)->Unit)={}
}
@Composable internal fun rememberProcessBillingActions(accountKey:String?,onAccessVerified:()->Unit,english:Boolean):ProcessBillingActions {
 val actions=remember(accountKey){ProcessBillingActions()};val gate=remember(accountKey){ProcessBillingGate(accountKey)}
 val scope=rememberCoroutineScope();val currentAccount by rememberUpdatedState(accountKey);val completed by rememberUpdatedState(onAccessVerified)
 DisposableEffect(accountKey){onDispose {gate.cancel()}}
 actions.run={operation->
  if(gate.begin()) {
   actions.busy=true;actions.error=null
   scope.launch {
    try {
     val result=operation();coroutineContext.ensureActive()
     if(gate.finish(result,currentAccount)){actions.completed=true;completed()}
     else if(currentAccount==accountKey)actions.error=when(result) {
      is ProcessBillingResult.Failed->result.message
      ProcessBillingResult.Pending->if(english)"Purchase pending. Access will activate after verification."else"Achat en attente. L’accès sera activé après vérification."
      ProcessBillingResult.NoPurchases->if(english)"No active purchase was found."else"Aucun achat actif trouvé."
      is ProcessBillingResult.VerifiedAccess->if(english)"The account changed. Please try again."else"Le compte a changé. Réessaie."
      ProcessBillingResult.Cancelled->null
     }
    }catch(cancel:CancellationException){throw cancel}
    catch(_:Exception){if(currentAccount==accountKey)actions.error=if(english)"The purchase service is unavailable. Please try again."else"Le service d’achat est indisponible. Réessaie."}
    finally {gate.cancel();actions.busy=false}
   }
  }
 }
 return actions
}
