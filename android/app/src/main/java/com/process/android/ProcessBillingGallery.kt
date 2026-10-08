package com.process.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import android.content.Intent
import android.net.Uri

@Composable internal fun ProcessBillingGallery(initialLifetime:Boolean,onClose:()->Unit,english:Boolean) {
 var lifetime by remember {mutableStateOf(initialLifetime)};var notice by remember {mutableStateOf<String?>(null)}
 val context=LocalContext.current
 val links=remember {ProcessLegalLinks()}
 fun legal(page:ProcessLegalPage){try {context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(links.page(page,if(english)"en"else"fr"))))}catch(_:android.content.ActivityNotFoundException){notice=if(english)"No browser is available."else"Aucun navigateur disponible."}catch(_:SecurityException){notice=if(english)"The browser could not be opened."else"Le navigateur n’a pas pu être ouvert."}}
 val unavailable=if(english)"Preview: Play products and verified purchase service are not connected."else"Aperçu : les produits Play et le service de vérification des achats ne sont pas raccordés."
 Column(Modifier.fillMaxSize().safeDrawingPadding()) {
  TextButton(onClick=onClose){Text(if(english)"Close development preview"else"Fermer l’aperçu de développement")}
  if(lifetime)ProcessLifetimeOffer(null,null,{ProcessBillingResult.Failed(unavailable)},{ProcessBillingResult.Failed(unavailable)},{},{if(initialLifetime)onClose()else lifetime=false},{legal(ProcessLegalPage.TERMS)},{legal(ProcessLegalPage.PRIVACY)},english=english)
  else ProcessPaywall(null,emptyList(),{ProcessBillingResult.Failed(unavailable)},{ProcessBillingResult.Failed(unavailable)},{},onClose,{lifetime=true},{notice="Code de parrainage : service Android à raccorder."},{legal(ProcessLegalPage.TERMS)},{legal(ProcessLegalPage.PRIVACY)},english=english)
 }
 notice?.let {AlertDialog(onDismissRequest={notice=null},title={Text(if(english)"Preview"else"Aperçu")},text={Text(it)},confirmButton={TextButton(onClick={notice=null}){Text("OK")}})}
}
