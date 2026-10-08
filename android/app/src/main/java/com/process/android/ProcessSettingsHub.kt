package com.process.android

import android.content.res.Configuration
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay

/** Live EditProfileView hub. Host owns account/health/billing routes and durable preference synchronization. */
@Composable fun ProcessSettingsHub(
    state:ProcessSettingsState,onBack:()->Unit,onAction:(ProcessSettingsAction)->Unit,
    onAppearanceChange:(ProcessAppearance)->Unit,onLanguageChange:(ProcessLanguage)->Unit,
    modifier:Modifier=Modifier,english:Boolean=state.language!=ProcessLanguage.FRENCH,
    reduceMotion:Boolean=rememberProcessReducedMotion(),soundEnabled:Boolean=true,
    avatar:(@Composable ()->Unit)?=null,
) {
    val system=LocalConfiguration.current
    val config=remember(system,state.appearance) {Configuration(system).apply {
        if(state.appearance!=ProcessAppearance.SYSTEM)uiMode=(uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or if(state.appearance==ProcessAppearance.DARK)Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
    }}
    CompositionLocalProvider(LocalConfiguration provides config) {
        var route by remember {mutableStateOf("hub")}
        BackHandler(route!="hub"){route="hub"}
        val feedback=rememberSettingsFeedback(soundEnabled)
        when(route) {
            "appearance" -> SettingsChoicePage(if(english)"Appearance"else"Apparence",{route="hub"},ProcessAppearance.entries.map {it.name to if(english)it.english else it.french},state.appearance.name,{onAppearanceChange(ProcessAppearance.valueOf(it));feedback()},modifier,english,reduceMotion,appearance=true)
            "language" -> SettingsChoicePage(if(english)"Language"else"Langue",{route="hub"},ProcessLanguage.entries.map {it.code to it.label},state.language.code,{code->onLanguageChange(ProcessLanguage.entries.first {it.code==code});feedback()},modifier,english,reduceMotion)
            else -> SettingsHubContent(state,onBack,onAction,{route=it},modifier,english,avatar)
        }
    }
}

@Composable private fun SettingsHubContent(state:ProcessSettingsState,onBack:()->Unit,onAction:(ProcessSettingsAction)->Unit,onRoute:(String)->Unit,modifier:Modifier,english:Boolean,avatar:(@Composable ()->Unit)?) {
    val dark=isSystemInDarkTheme();val ink=if(dark)Color.White else Color.Black
    val list=rememberLazyListState()
    val titles=if(english)listOf("Personalize","Support","Permissions","Programs","Follow Us")else listOf("Personnaliser","Assistance","Autorisations","Programmes","Suis-nous")
    val activeSection by remember {derivedStateOf {((list.firstVisibleItemIndex-1)/2).takeIf {list.firstVisibleItemIndex>=2}?.coerceIn(0,4)}}
    fun copy(fr:String,en:String)=if(english)en else fr
    fun permission(value:Boolean?,yes:String,no:String)=when(value){true->yes;false->no;null->copy("Indisponible","Unavailable")}
    Column(modifier.fillMaxSize().background(if(dark)Color.Black else Color(0xfff2f2f7))) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal=16.dp,vertical=8.dp),contentAlignment=Alignment.Center) {
            activeSection?.let {Text(titles[it],fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,color=ink,modifier=Modifier.padding(horizontal=48.dp))}
            IconButton(onClick=onBack,modifier=Modifier.align(Alignment.CenterStart).size(40.dp).background(ink.copy(alpha=.06f),CircleShape)) {Icon(Icons.AutoMirrored.Filled.ArrowBack,copy("Retour","Back"),Modifier.size(18.dp),tint=ink)}
        }
        LazyColumn(state=list,modifier=Modifier.fillMaxWidth().weight(1f),contentPadding=PaddingValues(top=24.dp,bottom=90.dp)) {
            item("account") {ProcessSettingsCard {
                Row(Modifier.fillMaxWidth().clickable(role=Role.Button){onAction(ProcessSettingsAction.ACCOUNT)}.padding(horizontal=16.dp,vertical=9.dp).heightIn(min=46.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(26.dp).clip(CircleShape).background(Color(.71f,.69f,0f),CircleShape),contentAlignment=Alignment.Center) {
                        if(avatar!=null)avatar() else Text(state.firstName?.takeIf {it.isNotBlank()}?.take(1)?.uppercase()?:"?",fontSize=12.sp,lineHeight=15.sp,fontWeight=FontWeight.Bold,color=Color.White)
                    }
                    Text(copy("Mon compte","My Account"),fontSize=16.sp,lineHeight=21.sp,color=ink,modifier=Modifier.weight(1f))
                    Text("›",fontSize=24.sp,color=ink.copy(alpha=.32f))
                }
            }}
            item("personalize-title"){ProcessSettingsSection(titles[0])}
            item("personalize"){ProcessSettingsCard {
                ProcessSettingsRow(Icons.Default.Edit,copy("Apparence","Appearance"),onClick={onRoute("appearance")});ProcessSettingsDivider()
                ProcessSettingsRow(SettingsGlobeIcon,copy("Langue","Language"),state.language.label,onClick={onRoute("language")})
            }}
            item("support-title"){ProcessSettingsSection(titles[1])}
            item("support"){ProcessSettingsCard {
                ProcessSettingsRow(Icons.Default.Email,copy("Assistance","Support"),onClick={onAction(ProcessSettingsAction.SUPPORT)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Info,copy("Centre d'aide","Help Center"),onClick={onAction(ProcessSettingsAction.HELP_CENTER)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Star,copy("Noter Process","Rate Process"),onClick={onAction(ProcessSettingsAction.RATE)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Lock,copy("Aide & confidentialité","Help & Privacy"),onClick={onAction(ProcessSettingsAction.HELP_PRIVACY)})
            }}
            item("permissions-title"){ProcessSettingsSection(titles[2])}
            item("permissions"){ProcessSettingsCard {
                ProcessSettingsRow(Icons.Default.Favorite,"Health Connect",permission(state.healthConnected,copy("Connecté","Connected"),copy("Connecter","Connect")),onClick={onAction(ProcessSettingsAction.HEALTH)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Notifications,"Notifications",permission(state.notificationsEnabled,copy("Activées","Enabled"),copy("Désactivées","Disabled")),onClick={onAction(ProcessSettingsAction.NOTIFICATIONS)})
            }}
            item("programs-title"){ProcessSettingsSection(titles[3])}
            item("programs"){ProcessSettingsCard {
                ProcessSettingsRow(Icons.Default.Star,copy("Parrainage","Refer friends"),onClick={onAction(ProcessSettingsAction.REFERRAL)})
                if(state.showsStudio){ProcessSettingsDivider();ProcessSettingsRow(Icons.Default.PlayArrow,copy("Studio contenu","Content Studio"),onClick={onAction(ProcessSettingsAction.STUDIO)})}
            }}
            item("follow-title"){ProcessSettingsSection(titles[4])}
            item("follow"){ProcessSettingsCard {
                ProcessSettingsRow(Icons.Default.Share,copy("Partager Process","Share Process"),onClick={onAction(ProcessSettingsAction.SHARE)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Info,"TikTok",external=true,onClick={onAction(ProcessSettingsAction.TIKTOK)});ProcessSettingsDivider()
                ProcessSettingsRow(Icons.Default.Info,"Instagram",external=true,onClick={onAction(ProcessSettingsAction.INSTAGRAM)})
            }}
            item("version"){Text("v${state.version} (${state.build})",fontSize=13.sp,lineHeight=17.sp,color=ink.copy(alpha=.408f),modifier=Modifier.fillMaxWidth().padding(top=24.dp,bottom=8.dp),textAlign=androidx.compose.ui.text.style.TextAlign.Center)}
        }
    }
}

@Composable private fun SettingsChoicePage(title:String,onBack:()->Unit,choices:List<Pair<String,String>>,selected:String,onSelected:(String)->Unit,modifier:Modifier,english:Boolean,reduceMotion:Boolean,appearance:Boolean=false) {
    var highlighted by remember {mutableStateOf<String?>(null)}
    LaunchedEffect(highlighted){if(highlighted!=null){delay(280);highlighted=null}}
    ProcessSettingsPage(title,onBack,modifier,english) {
        ProcessSettingsSection(title)
        ProcessSettingsCard {
            choices.forEachIndexed {index,(id,label)->
                if(index>0)ProcessSettingsDivider()
                val active=selected==id;val flashed=highlighted==id
                val scale by animateFloatAsState(if(flashed)1.018f else 1f,if(reduceMotion)snap()else spring(.9f,504f),label="settings.selection.$id")
                val ink=if(isSystemInDarkTheme())Color.White else Color.Black
                Row(Modifier.fillMaxWidth().graphicsLayer {scaleX=scale;scaleY=scale;alpha=if(flashed||active)1f else .94f}.clickable(role=Role.RadioButton){if(!active){highlighted=id;onSelected(id)}}.semantics {this.selected=active}.padding(horizontal=16.dp,vertical=9.dp).heightIn(min=46.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                    if(appearance)Text(when(id){"DARK"->"☾";"LIGHT"->"☀";else->"◐"},fontSize=20.sp,color=ink.copy(alpha=.82f),modifier=Modifier.width(26.dp))
                    else Icon(SettingsGlobeIcon,null,Modifier.width(26.dp).size(19.dp),tint=ink.copy(alpha=.82f))
                    Text(label,Modifier.weight(1f),fontSize=16.sp,lineHeight=21.sp,color=ink)
                    if(active)Text(if(english)"Active"else"Actif",fontSize=17.sp,lineHeight=22.sp,color=ink.copy(alpha=.48f))
                }
            }
        }
    }
}

private val SettingsGlobeIcon=ImageVector.Builder("SettingsGlobe",24.dp,24.dp,24f,24f).apply {
    path(fill=null,stroke=SolidColor(Color.Black),strokeLineWidth=1.7f) {
        moveTo(22f,12f);curveTo(22f,17.52f,17.52f,22f,12f,22f);curveTo(6.48f,22f,2f,17.52f,2f,12f);curveTo(2f,6.48f,6.48f,2f,12f,2f);curveTo(17.52f,2f,22f,6.48f,22f,12f);close()
        moveTo(2f,12f);lineTo(22f,12f);moveTo(12f,2f);curveTo(18f,8f,18f,16f,12f,22f);curveTo(6f,16f,6f,8f,12f,2f)
    }
}.build()
