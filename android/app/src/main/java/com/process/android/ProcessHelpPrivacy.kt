package com.process.android
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Live Process help page, preserving the retirement of the third-party chat provider. */
@Composable fun ProcessHelpPrivacy(
    onBack:()->Unit,modifier:Modifier=Modifier,english:Boolean=false,
    coachEnabled:Boolean?=null,faceAnalysisEnabled:Boolean?=null,
    links:ProcessLegalLinks=remember {ProcessLegalLinks()},
    onScoresAndRecommendations:(()->Unit)?=null,
) {
    val context=LocalContext.current
    var support by remember {mutableStateOf(false)}
    var unavailable by remember {mutableStateOf(false)}
    fun open(uri:String) {
        try {context.startActivity(Intent(if(uri.startsWith("mailto:"))Intent.ACTION_SENDTO else Intent.ACTION_VIEW,Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))}
        catch(_:android.content.ActivityNotFoundException) {unavailable=true}
        catch(_:SecurityException) {unavailable=true}
    }
    fun page(page:ProcessLegalPage)=open(links.page(page,if(english)"en"else"fr"))
    fun status(value:Boolean?)=when(value) {true->if(english)"Enabled"else"Activé";false->if(english)"Disabled"else"Désactivé";null->if(english)"Unavailable"else"Indisponible"}
    BackHandler(support){support=false}
    if(support) {
        ProcessSettingsPage(if(english)"Support"else"Assistance",{support=false},modifier,english) {
            Column(Modifier.fillMaxWidth().padding(horizontal=24.dp).padding(top=80.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(24.dp)) {
                Icon(Icons.Default.Email,null,Modifier.size(40.dp))
                Text(if(english)"Contact our team by email."else"Contacte notre équipe par email.",textAlign=TextAlign.Center)
                SelectionContainer {Text(links.supportEmail)}
                Button(onClick={open(links.supportDraft())}) {Text(if(english)"Email support"else"Écrire à l’assistance")}
            }
        }
    } else ProcessSettingsPage(if(english)"Help & Privacy"else"Aide & confidentialité",onBack,modifier,english) {
        ProcessSettingsSection(if(english)"Legal"else"Légal")
        ProcessSettingsCard {
            ProcessSettingsRow(Icons.Default.Info,if(english)"Terms of Use"else"Conditions d'utilisation",external=true,onClick={page(ProcessLegalPage.TERMS)})
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Lock,if(english)"Privacy Policy"else"Politique de confidentialité",external=true,onClick={page(ProcessLegalPage.PRIVACY)})
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Face,if(english)"Facial Data"else"Données faciales",external=true,onClick={page(ProcessLegalPage.FACE_DATA)})
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Home,if(english)"Legal Notice"else"Mentions légales",external=true,onClick={page(ProcessLegalPage.NOTICE)})
        }
        ProcessSettingsSection(if(english)"Help"else"Aide")
        ProcessSettingsCard {
            ProcessSettingsRow(Icons.Default.Info,if(english)"Scores and Recommendations"else"Scores et recommandations",onClick={onScoresAndRecommendations?.invoke()?:page(ProcessLegalPage.SOURCES)})
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Email,if(english)"Support"else"Assistance",onClick={support=true})
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Email,if(english)"Send an email"else"Écrire un e-mail",external=true,onClick={open("mailto:${links.supportEmail}")})
        }
        ProcessSettingsSection(if(english)"Smart Services"else"Services intelligents")
        ProcessSettingsCard {
            ProcessSettingsRow(Icons.Default.Star,if(english)"AI Coach"else"Coach IA",status(coachEnabled))
            ProcessSettingsDivider()
            ProcessSettingsRow(Icons.Default.Face,if(english)"Face Scan Analysis"else"Analyse scan visage",status(faceAnalysisEnabled))
        }
    }
    if(unavailable)AlertDialog(onDismissRequest={unavailable=false},title={Text(if(english)"Can't open link"else"Impossible d’ouvrir le lien")},text={Text(if(english)"Install a browser or email app, then try again."else"Installe un navigateur ou une application e-mail, puis réessaie.")},confirmButton={TextButton(onClick={unavailable=false}){Text("OK")}})
}
