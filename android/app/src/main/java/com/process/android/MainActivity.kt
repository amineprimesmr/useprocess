package com.process.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.activity.compose.BackHandler
import com.tenkdesign.android.TenKTypewriter
import com.tenkdesign.android.TenKPositionPad
import com.tenkdesign.android.PadPosition
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate

class MainActivity:ComponentActivity() {
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store=getSharedPreferences("hydration",MODE_PRIVATE)
        val day=LocalDate.now().toString()
        setContent {
            MaterialTheme(colorScheme=if(isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()) {
                var water by remember { mutableIntStateOf(if(store.getString("day",null)==day) store.getInt("ml",0) else 0) }
                var demo by rememberSaveable { mutableStateOf("hydration") }
                var gender by remember { mutableStateOf<ProcessGender?>(null) }
                
                val foodPreferences=remember { FoodPreferenceStore(this@MainActivity,null) }
                val chatStore=remember {ProfileChatStore(this@MainActivity,null)}
                val groceries=remember { FoodShoppingList(this@MainActivity,null) }
                var english by rememberSaveable { mutableStateOf(false) }
                val inputStore=remember { getSharedPreferences("onboarding-input-preview",MODE_PRIVATE) }
                var firstName by rememberSaveable { mutableStateOf(inputStore.getString("name","") ?: "") }
                var weightKg by rememberSaveable { mutableDoubleStateOf(inputStore.getFloat("weight",0f).toDouble()) }
                var age by rememberSaveable { mutableIntStateOf(inputStore.getInt("age",25)) }
                var heightCm by rememberSaveable { mutableDoubleStateOf(inputStore.getFloat("height",170f).toDouble()) }
                var padPosition by remember {mutableStateOf(PadPosition(.5f,.5f))}
                var navigationTab by rememberSaveable {mutableStateOf(ProcessMainSection.PLAN)}
                var inputValid by remember { mutableStateOf(false) }
                BackHandler(demo!="hydration") {
                    if(demo=="age")inputStore.edit().putInt("age",age).apply()
                    if(demo=="height")inputStore.edit().putFloat("height",heightCm.toFloat()).apply()
                    demo="hydration"
                }
                if(demo in listOf("name","weight","age","height")) {
                    Box(Modifier.fillMaxSize().background(if(isSystemInDarkTheme()) Color.Black else Color(.968f,.972f,.988f)).safeDrawingPadding().imePadding()) {
                        if(demo=="name") ProcessFirstNameInput(firstName,{firstName=it},{inputStore.edit().putString("name",it).apply()},{demo="weight"},onValidationChange={inputValid=it},english=english)
                        else if(demo=="weight") ProcessWeightInput(weightKg,{weightKg=it},{inputStore.edit().putFloat("weight",weightKg.toFloat()).apply();demo="hydration"},onValidationChange={inputValid=it},english=english)
                        else if(demo=="age") ProcessAgeSelection(age,{age=it},{inputStore.edit().putInt("age",it).apply()},onValidationChange={inputValid=it},english=english)
                        else ProcessHeightSelection(heightCm,{heightCm=it},{inputStore.edit().putFloat("height",it.toFloat()).apply()},onValidationChange={inputValid=it},english=english)
                        TextButton(onClick={if(demo=="age")inputStore.edit().putInt("age",age).apply();if(demo=="height")inputStore.edit().putFloat("height",heightCm.toFloat()).apply();demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english) "Back" else "Retour")}
                        Button(onClick={when(demo) {
                            "name" -> demo="weight"
                            "weight" -> {inputStore.edit().putFloat("weight",weightKg.toFloat()).apply();demo="hydration"}
                            "age" -> {inputStore.edit().putInt("age",age).apply();demo="hydration"}
                            "height" -> {inputStore.edit().putFloat("height",heightCm.toFloat()).apply();demo="hydration"}
                        }},enabled=inputValid,modifier=Modifier.align(Alignment.BottomCenter).padding(bottom=16.dp)) {Text(if(english) "Continue" else "Continuer")}
                    }
                } else if(demo=="confirmation"||demo=="borderBeam") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        if(demo=="confirmation")com.tenkdesign.android.TenKAnimatedConfirmationGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        else com.tenkdesign.android.TenKBorderBeamGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}){Text("Fermer")}
                    }
                } else if(demo=="tickPicker") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKTickPickerGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}){Text("Fermer")}
                    }
                } else if(demo=="elastic"||demo=="expandableSlider") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        if(demo=="elastic")com.tenkdesign.android.TenKElasticGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        else com.tenkdesign.android.TenKExpandableSliderGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}){Text("Fermer")}
                    }
                } else if(demo=="gooeyRefresh") {
                    TenKGooeyRefreshGallery({demo="hydration"},rememberProcessReducedMotion())
                } else if(demo in listOf("backdropCarousel","wallpaperCarousel","scrollInteraction")) {
                    TenKThreeCarouselsGallery(demo,{demo="hydration"},rememberProcessReducedMotion())
                } else if(demo=="viewSnapshot") {
                    TenKViewSnapshotGallery {demo="hydration"}
                } else if(demo=="qrScanner") {
                    TenKQrScannerGallery {demo="hydration"}
                } else if(demo=="pdfExport") {
                    TenKPdfGallery {demo="hydration"}
                } else if(demo=="imageCache") {
                    TenKImageCacheGallery {demo="hydration"}
                } else if(demo=="timedPaging") {
                    TenKTimedPagingGallery {demo="hydration"}
                } else if(demo=="scrollNavigation") {
                    TenKScrollNavigationGallery {demo="hydration"}
                } else if(demo=="alertDrawer") {
                    TenKAlertDrawerGallery {demo="hydration"}
                } else if(demo=="swipeActions") {
                    TenKSwipeActionsGallery {demo="hydration"}
                } else if(demo=="scrollIndicator") {
                    TenKScrollIndicatorGallery {demo="hydration"}
                } else if(demo=="mealAnalysis") {
                    ProcessMealAnalysisGallery({demo="hydration"},english)
                } else if(demo=="faceCapture") {
                    ProcessFaceCaptureGallery({demo="hydration"},english)
                } else if(demo=="homeDashboard") {
                    ProcessHomeGallery({demo="hydration"},{demo="foodHub"},{demo="profileProgress"},{demo="routineExercise"},{demo="referral"},english,onScan={demo="faceCapture"})
                } else if(demo=="multiSelect") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {com.tenkdesign.android.TenKDragSelectionGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion());TextButton(onClick={demo="hydration"}) {Text("Retour")}}
                } else if(demo=="mobileOtp") {
                    Column {TextButton(onClick={demo="hydration"}) {Text("Retour")};com.tenkdesign.android.TenKMobileOtpGallery(reduceMotion=rememberProcessReducedMotion())}
                } else if(demo=="verification") {
                    Column {TextButton(onClick={demo="hydration"}) {Text("Retour")};com.tenkdesign.android.TenKVerificationGallery(reduceMotion=rememberProcessReducedMotion())}
                } else if(demo=="homeTutorial") {
                    ProcessTutorialGallery({demo="hydration"},english)
                } else if(demo=="profileProgress") {
                    ProcessProfileGallery({demo="hydration"},{demo="settings"},english)
                } else if(demo=="paywall"||demo=="lifetime") {
                    ProcessBillingGallery(demo=="lifetime",{demo="hydration"},english)
                } else if(demo=="foodHub") {
                    ProcessFoodHubGallery({demo="hydration"},{demo="hydration"},english)
                } else if(demo=="routineHome") {
                    var day by remember {mutableStateOf(RoutineHomeDay("preview-only/day",true))}
                    var detail by remember {mutableStateOf<RoutineStep?>(null)}
                    var session by remember {mutableStateOf(false)}
                    if(detail!=null)ProcessRoutineExerciseDetail(detail!!,{detail=null},english=english,reduceMotion=rememberProcessReducedMotion())
                    else Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                        TextButton(onClick={demo="hydration"}){Text("Fermer — plan de démonstration")}
                        ProcessRoutineHome(day,null,{detail=it},{_,_->session=true},{event->if(event.contextKey==day.contextKey)day=day.copy(completedStepIds=day.completedStepIds+event.stepId)},{},english=english,preview=true)
                    }
                    if(session)AlertDialog(onDismissRequest={session=false},title={Text("Aperçu de routine")},text={Text("Session caméra et suivi corporel Android à raccorder. Les validations de cet aperçu restent en mémoire.")},confirmButton={TextButton(onClick={session=false}){Text("OK")}})
                } else if(demo=="settings") {
                    var settings by remember {mutableStateOf(ProcessSettingsState())}
                    var action by remember {mutableStateOf<ProcessSettingsAction?>(null)}
                    ProcessSettingsHub(settings.copy(notificationsEnabled=rememberProcessNotificationsEnabled()),{demo="hydration"},{action=it},{settings=settings.copy(appearance=it)},{settings=settings.copy(language=it)},Modifier.safeDrawingPadding())
                    action?.let {AlertDialog(onDismissRequest={action=null},title={Text("Aperçu des réglages")},text={Text("Action ${it.name} : connexion au service hôte à terminer. Aucun compte modifié.")},confirmButton={TextButton(onClick={action=null}){Text("OK")}})}
                } else if(demo=="waveform") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKWaveformGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}) {Text("Fermer")}
                    }
                } else if(demo=="slideConfirm") {
                    var confirmed by remember {mutableStateOf(false)}
                    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(20.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
                        TextButton(onClick={demo="hydration"}) {Text("Fermer")}
                        Text("Slide to Confirm")
                        Text("Aperçu — aucun paiement effectué")
                        Spacer(Modifier.weight(1f))
                        com.tenkdesign.android.TenKSlideToConfirm({confirmed=true},reduceMotion=rememberProcessReducedMotion())
                        if(confirmed)Text("Geste confirmé")
                    }
                } else if(demo=="recipe") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessRecipeDetail(ProcessRecipeCatalog.forSlot("lunch").first(),{demo="hydration"},alternatives=ProcessRecipeCatalog.forSlot("lunch"),editable=true,english=english)}
                } else if(demo=="keypad") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKAnimatedKeypadGallery({demo="hydration"},reduceMotion=rememberProcessReducedMotion(),english=english)
                    }
                } else if(demo=="chips") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKChipGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="staggered") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKStaggeredGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="expandableText") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKExpandableTextGallery(Modifier.padding(top=48.dp),rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"}) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="transformation") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessTransformationPreview({demo="hydration"},english=english)}
                } else if(demo=="welcomeCards") {
                    val cardsStore=remember {WelcomeCardsStore(this@MainActivity,null)}
                    var dismissed by remember {mutableStateOf(cardsStore.load())}
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        Column(Modifier.padding(20.dp).padding(top=80.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
                            Text(if(english)"Original deck preview — no plan or reward created"else"Aperçu des cartes originales — aucun plan ou cadeau créé",fontSize=12.sp)
                            ProcessWelcomeCards(dismissed,{dismissed=it;cardsStore.save(it)},{demo="referralCard"},english=english)
                            TextButton(onClick={dismissed=WelcomeCardDismissal();cardsStore.save(dismissed)}) {Text(if(english)"Replay preview"else"Rejouer l’aperçu")}
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="routineExercise") {
                    var step by remember {mutableIntStateOf(0)}
                    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {ProcessRoutineCatalog.steps.forEachIndexed {index,routine ->TextButton(onClick={step=index}){Text(routine.title(english))}}}
                        ProcessRoutineExerciseDetail(ProcessRoutineCatalog.steps[step],{demo="hydration"},Modifier.weight(1f),english=english)
                    }
                } else if(demo=="stackedToasts") {
                    val toasts=remember {mutableStateListOf<com.tenkdesign.android.TenKStackedToast>()}
                    var autoDismiss by remember {mutableStateOf(false)}
                    var glassTint by remember {mutableFloatStateOf(.5f)}
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
                            TextButton(onClick={demo="hydration"}) {Text(if(english)"Back"else"Retour")}
                            Text("Toasts",fontSize=28.sp)
                            Text("Glass Tint Opacity");Slider(glassTint,{glassTint=it})
                            Row(verticalAlignment=Alignment.CenterVertically) {Text("Add Auto Dismiss");Switch(autoDismiss,{autoDismiss=it})}
                            Button(onClick={if(toasts.size<3)toasts.add(when(toasts.size) {
                                0 -> com.tenkdesign.android.TenKStackedToast("Connection Failed","Something went wrong. Please try again!",Color.Red,if(autoDismiss)5.0 else null)
                                1 -> com.tenkdesign.android.TenKStackedToast("Pending Action","Your file has still pending changes.",Color.Yellow,if(autoDismiss)5.0 else null)
                                else -> com.tenkdesign.android.TenKStackedToast("Success","Your changes have been saved.",Color.Green,if(autoDismiss)5.0 else null)
                            })}) {Text("Add Toast")}
                            Text(if(english)"Original sample messages — no file is modified"else"Messages d’exemple originaux — aucun fichier modifié",fontSize=12.sp)
                        }
                        com.tenkdesign.android.TenKStackedToasts(toasts.toList(),{id ->toasts.removeAll {it.id==id}},Modifier.align(Alignment.BottomCenter),glassTintOpacity=glassTint,reduceMotion=rememberProcessReducedMotion(),dismissLabel=if(english)"Dismiss"else"Fermer") {toast ->Text(if(toast.tint==Color.Green)"✓"else"!",color=toast.tint,fontSize=28.sp)}
                    }
                } else if(demo=="verticalPicker") {
                    var selected by remember {mutableIntStateOf(0)}
                    val labels=if(english)listOf("Explore","Driving","Satellite")else listOf("Explorer","Conduite","Satellite")
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        Column(Modifier.align(Alignment.Center).padding(30.dp),horizontalAlignment=Alignment.CenterHorizontally) {
                            Text(labels[selected],fontSize=28.sp)
                            Text(if(english)"Picker preview — connect your map provider through the selection callback."else"Aperçu du sélecteur — la carte est fournie par l’application hôte.")
                        }
                        com.tenkdesign.android.TenKVerticalSegmentedControl(listOf(0,1,2),selected,{selected=it},{labels[it]},Modifier.align(Alignment.BottomEnd).padding(end=15.dp,bottom=5.dp),reduceMotion=rememberProcessReducedMotion()) {item ->
                            Text(listOf("⌖","↗","◎")[item],fontSize=18.sp)
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="helpPrivacy") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessHelpPrivacy({demo="hydration"},english=english)}
                } else if(demo=="thankYou") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        ProcessPostPaymentThankYou(true,true,{ProcessAccountCompletion.Failed(if(english)"Apple sign-in is not configured for this preview."else"La connexion Apple n’est pas configurée pour cet aperçu.")},{demo="hydration"},english=english)
                        Text(if(english)"Screen preview — no subscription activated"else"Aperçu d’écran — aucun abonnement activé",fontSize=10.sp,modifier=Modifier.align(Alignment.TopCenter))
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="referralCard") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        Column(Modifier.padding(24.dp)) {
                            Text(if(english)"Invite friends."else"Invite tes amis.",fontSize=28.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.ExtraBold)
                            Text(if(english)"Get rewarded."else"Gagne des récompenses.",fontSize=28.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.ExtraBold)
                            ProcessReferralMetalCard("DEMO5","",english=english)
                            Text(if(english)"Sample code — no referral reward created"else"Code d’exemple — aucune récompense créée",fontSize=12.sp)
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back"else"Retour")}
                    }
                } else if(demo=="coverFlow") {
                    var selectedCard by remember {mutableIntStateOf(0)}
                    var elevation by remember {mutableFloatStateOf(0f)}
                    val colors=listOf(Color(0xffff453a),Color(0xff0a84ff),Color(0xff30d158),Color(0xffffd60a),Color(0xffbf5af2),Color(0xff5e5ce6),Color(0xff66d4cf),Color(0xffac8e68),Color(0xffff9f0a),Color(0xff64d2ff))
                    val names=listOf("RED","BLUE","GREEN","YELLOW","PURPLE","INDIGO","MINT","BROWN","ORANGE","CYAN")
                    Box(Modifier.fillMaxSize().background(Color.Black).background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(colors[selectedCard],colors[selectedCard].copy(alpha=.5f),Color.Transparent,Color.Transparent,Color.Transparent))).safeDrawingPadding()) {
                        Column(Modifier.align(Alignment.Center),horizontalAlignment=Alignment.CenterHorizontally) {
                            Text("Current Color",color=Color.Gray);Text(names[selectedCard],color=Color.White)
                            Spacer(Modifier.height(40.dp))
                            com.tenkdesign.android.TenKCoverFlow(colors.size,selectedCard,{selectedCard=it},Modifier.fillMaxWidth().height(220.dp),config=com.tenkdesign.android.CoverFlowConfig(activeElevation=elevation),reduceMotion=rememberProcessReducedMotion()) {i ->
                                Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(androidx.compose.ui.graphics.lerp(colors[i],Color.White,.12f),colors[i],androidx.compose.ui.graphics.lerp(colors[i],Color.Black,.12f)))))
                            }
                        }
                        Column(Modifier.align(Alignment.BottomCenter).padding(horizontal=40.dp).padding(bottom=10.dp)) {
                            Text("Active Card Focus",color=Color.Gray,fontSize=12.sp)
                            Slider(elevation,{elevation=it},valueRange=0f..60f)
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="skeleton") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKSkeletonGallery(Modifier.padding(top=40.dp),reduceMotion=rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="networkMonitor") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        com.tenkdesign.android.TenKNetworkMonitorPage(Modifier.padding(top=40.dp),english=english,reduceMotion=rememberProcessReducedMotion())
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="flipCard") {
                    var captureError by remember {mutableStateOf(false)}
                    Box(Modifier.fillMaxSize().safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(18.dp)) {
                            Text(if(english)"Long press the card, then Edit"else"Appui long sur la carte, puis Modifier")
                            com.tenkdesign.android.TenKFlipTransition(this@MainActivity,reduceMotion=rememberProcessReducedMotion(),contextMenuTitle=if(english)"Edit"else"Modifier",onCaptureFailure={captureError=true},content={
                                Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainer,androidx.compose.foundation.shape.RoundedCornerShape(20.dp)).padding(15.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                                    Text("Distance",fontSize=20.sp);Text("Today");Text("0.54KM",color=Color.Cyan,fontSize=28.sp)
                                    Spacer(Modifier.height(40.dp));Text("12 AM         6 AM         12 PM         6 PM",fontSize=11.sp,color=Color.Gray)
                                }
                            },destination={dismiss ->
                                Column(Modifier.fillMaxSize().padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                                    Text("Distance",fontSize=20.sp)
                                    Text("Not enough metric available to display.",modifier=Modifier.weight(1f))
                                    TextButton(onClick=dismiss){Text(if(english)"Close"else"Fermer")}
                                }
                            })
                            if(captureError)Text(if(english)"The card couldn't be captured. Please try again."else"La capture de la carte a échoué. Réessaie.")
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="sleepSlider") {
                    var sleep by remember {mutableStateOf(com.tenkdesign.android.SleepRange())}
                    Box(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
                            Row(Modifier.fillMaxWidth().padding(horizontal=30.dp),horizontalArrangement=Arrangement.SpaceBetween) {
                                Column {Text("BEDTIME",color=Color.Gray);Text(com.tenkdesign.android.SleepSliderModel.time(sleep.start),color=Color.White,fontSize=25.sp)}
                                Column {Text("WAKE UP",color=Color.Gray);Text(com.tenkdesign.android.SleepSliderModel.time(sleep.end),color=Color.White,fontSize=25.sp)}
                            }
                            com.tenkdesign.android.TenKSleepSlider(sleep,{sleep=it},reduceMotion=rememberProcessReducedMotion())
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="scanToast") {
                    val toast=rememberProcessToastState()
                    Box(Modifier.fillMaxSize().safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(16.dp)) {
                            Text(if(english)"Notification preview — no scan recorded" else "Aperçu de notification — aucun scan enregistré")
                            Button(onClick={toast.show(ProcessToastMessage.scanCompleted(2,3,7,english))}) {Text(if(english)"Show notification" else "Afficher la notification")}
                            TextButton(onClick={demo="hydration"}) {Text(if(english)"Back" else "Retour")}
                        }
                        ProcessToastHost(toast,dismissDescription=if(english)"Dismiss notification" else "Fermer la notification")
                    }
                } else if(demo=="programCreation") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        ProcessProgramCreation(false,false,{false},{},{demo="hydration"},english=english)
                        Text(if(english)"Animation preview — no saved program" else "Aperçu animé — aucun programme enregistré",fontSize=10.sp,modifier=Modifier.align(Alignment.TopCenter))
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="reactionPicker") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        var reaction by remember {mutableStateOf<String?>(null)}
                        var forcePopover by remember {mutableStateOf(false)}
                        var insert by remember {mutableStateOf(false)}
                        var inserted by remember {mutableStateOf(false)}
                        Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(24.dp)) {
                            Row(verticalAlignment=Alignment.CenterVertically) {Text("Force Popover");Switch(forcePopover,{forcePopover=it})}
                            Row(verticalAlignment=Alignment.CenterVertically) {Text("Add Insert Button");Switch(insert,{insert=it})}
                            com.tenkdesign.android.TenKReactionPicker(listOf("👍","👌","🎉","❤️","🔥"),reaction,{reaction=it},forcePopover=forcePopover,addsInsertButton=insert,reduceMotion=rememberProcessReducedMotion(),onInsertTapped={inserted=true})
                            if(inserted) Text(if(english)"Insert callback received" else "Action d’insertion reçue")
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="asyncButton") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding(), contentAlignment=Alignment.Center) {
                        var phase by remember { mutableStateOf(com.tenkdesign.android.AsyncButtonModel.DemoPhase.IDLE) }
                        val title=when(phase) {
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.IDLE -> "Click to pay"
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.ANALYZING -> "Analyzing Transaction"
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.PROCESSING -> "Processing Transaction"
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.FAILED -> "Transaction Failed"
                        }
                        val color=when(phase) {
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.IDLE -> Color.Black
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.ANALYZING -> Color.Blue
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.PROCESSING -> Color(.8f,.35f,.2f)
                            com.tenkdesign.android.AsyncButtonModel.DemoPhase.FAILED -> Color.Red
                        }
                        Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
                            Text(if(english) "Original sample — simulated transaction" else "Exemple original — transaction simulée")
                            com.tenkdesign.android.TenKAsyncButton(title,color,reduceMotion=rememberProcessReducedMotion(),onFailure={phase=com.tenkdesign.android.AsyncButtonModel.DemoPhase.IDLE}) {
                                try {
                                    phase=com.tenkdesign.android.AsyncButtonModel.DemoPhase.ANALYZING
                                    kotlinx.coroutines.delay(3000)
                                    phase=com.tenkdesign.android.AsyncButtonModel.DemoPhase.PROCESSING
                                    kotlinx.coroutines.delay(3000)
                                    phase=com.tenkdesign.android.AsyncButtonModel.DemoPhase.FAILED
                                    kotlinx.coroutines.delay(1000)
                                } finally {phase=com.tenkdesign.android.AsyncButtonModel.DemoPhase.IDLE}
                            }
                        }
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="positionPad") {
                    Box(Modifier.fillMaxSize().background(Color(.97f,.97f,.97f)).safeDrawingPadding(),contentAlignment=Alignment.Center) {
                        Box(Modifier.background(Color(.08f,.08f,.08f),androidx.compose.foundation.shape.RoundedCornerShape(28.dp)).padding(24.dp)) {TenKPositionPad(padPosition,{padPosition=it},reduceMotion=rememberProcessReducedMotion(),label="Position XY")}
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english)"Back" else "Retour")}
                    }
                } else if(demo=="estimation") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        ProcessEstimation(ProcessEstimationContext(age,heightCm,weightKg),inputStore.getBoolean("estimationCompleted",false),{inputValid=it},english=english)
                        Button(onClick={inputStore.edit().putBoolean("estimationCompleted",true).apply();demo="hydration"},enabled=inputValid,modifier=Modifier.align(Alignment.BottomCenter).padding(bottom=16.dp)) {Text(if(english)"Continue" else "Continuer")}
                    }
                } else if(demo=="commitSlider") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessCommitSlider(firstName,{demo="hydration"},english=english)}
                } else if(demo=="hold") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessCommitHold({demo="hydration"},english=english)}
                } else if(demo=="streak") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessStreakPage(ProcessStreakSummary(0,0,0,false),ProcessStreakModel.week(LocalDate.now(),null,emptyList(),emptySet()),LocalDate.now(),{},{demo="hydration"},english=english)}
                } else if(demo=="calendar") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {ProcessProgramCalendar(null,emptyList(),emptyList(),0,{demo="hydration"},english=english)}
                } else if(demo=="tabs") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
                            TextButton(onClick={demo="hydration"}) {Text(if(english) "Back" else "Retour")}
                            Text(if(english) "Navigation preview" else "Aperçu de la navigation",style=MaterialTheme.typography.titleLarge)
                            Text(navigationTab.label(english),style=MaterialTheme.typography.headlineMedium)
                        }
                        ProcessTabBar(navigationTab,{navigationTab=it},Modifier.align(Alignment.BottomCenter),english=english)
                    }
                } else if(demo=="chat") {
                    Box(Modifier.fillMaxSize().background(if(isSystemInDarkTheme())Color.Black else Color(.968f,.972f,.988f)).safeDrawingPadding()) {
                        ProcessProfileChat(chatStore,firstName,{demo="hydration"},{demo="hydration"},english=english)
                    }
                } else if(demo=="face") {
                    Box(Modifier.fillMaxSize().background(if(isSystemInDarkTheme())Color.Black else Color(.968f,.972f,.988f)).safeDrawingPadding()) {
                        ProcessFaceLeverageIntro(firstName,{demo="chat"},female=gender==ProcessGender.Female,onViewed={inputStore.edit().putBoolean("faceViewed",true).apply()},english=english)
                        TextButton(onClick={demo="hydration"},modifier=Modifier.align(Alignment.TopStart)) {Text(if(english) "Back" else "Retour")}
                    }
                } else if(demo=="foods") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        ProcessFoodCatalogPage(foodPreferences,{groceries.add(it)},{demo="hydration"},english=english)
                    }
                } else if(demo=="groceries") {
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {FoodShoppingListPage(groceries,{demo="hydration"},english)}
                } else Surface(Modifier.fillMaxSize()) {
                    Column(Modifier.safeDrawingPadding().padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
                        Text("Process",style=MaterialTheme.typography.headlineLarge)
                        Row(Modifier.horizontalScroll(rememberScrollState())) {
                            TextButton(onClick={demo="hydration"}) { Text("Gourde") }
                            TextButton(onClick={demo="gender"}) { Text("Genre") }
                            TextButton(onClick={demo="typewriter"}) { Text("Texte") }
                            TextButton(onClick={demo="foods"}) { Text(if(english) "Foods" else "Aliments") }
                            TextButton(onClick={demo="groceries"}) { Text(if(english) "Groceries" else "Courses") }
                            TextButton(onClick={inputValid=false;demo="name"}) { Text(if(english) "Name" else "Prénom") }
                            TextButton(onClick={inputValid=false;demo="weight"}) { Text(if(english) "Weight" else "Poids") }
                            TextButton(onClick={inputValid=false;demo="age"}) { Text(if(english) "Age" else "Âge") }
                            TextButton(onClick={inputValid=false;demo="height"}) { Text(if(english) "Height" else "Taille") }
                            TextButton(onClick={demo="face"}) {Text(if(english) "Face" else "Visage")}
                            TextButton(onClick={demo="chat"}) {Text(if(english) "Chat" else "Questions")}
                            TextButton(onClick={demo="confirmation"}) {Text("Confirmation animée")}
                            TextButton(onClick={demo="borderBeam"}) {Text("Bordure lumineuse")}
                            TextButton(onClick={demo="tickPicker"}) {Text("Sélecteur horizontal")}
                            TextButton(onClick={demo="elastic"}) {Text("Sélecteur élastique")}
                            TextButton(onClick={demo="expandableSlider"}) {Text("Slider extensible")}
                            TextButton(onClick={demo="gooeyRefresh"}) {Text("Actualisation Gooey")}
                            TextButton(onClick={demo="backdropCarousel"}) {Text("Carrousel lumineux")}
                            TextButton(onClick={demo="wallpaperCarousel"}) {Text("Carrousel avec reflet")}
                            TextButton(onClick={demo="scrollInteraction"}) {Text("Transitions au scroll")}
                            TextButton(onClick={demo="viewSnapshot"}) {Text("Capture de vue")}
                            TextButton(onClick={demo="qrScanner"}) {Text("Scanner QR")}
                            TextButton(onClick={demo="pdfExport"}) {Text("Export PDF")}
                            TextButton(onClick={demo="imageCache"}) {Text("Cache d’images")}
                            TextButton(onClick={demo="timedPaging"}) {Text("Pagination automatique")}
                            TextButton(onClick={demo="scrollNavigation"}) {Text("Navigation au scroll")}
                            TextButton(onClick={demo="alertDrawer"}) {Text("Boîte de confirmation")}
                            TextButton(onClick={demo="swipeActions"}) {Text("Actions au swipe")}
                            TextButton(onClick={demo="scrollIndicator"}) {Text("Indicateur de scroll")}
                            TextButton(onClick={demo="mealAnalysis"}) {Text("Analyse du repas")}
                            TextButton(onClick={demo="faceCapture"}) {Text("Capture visage")}
                            TextButton(onClick={demo="homeDashboard"}) {Text("Accueil quotidien")}
                            TextButton(onClick={demo="multiSelect"}) {Text("Sélection multiple")}
                            TextButton(onClick={demo="mobileOtp"}) {Text("Connexion SMS")}
                            TextButton(onClick={demo="verification"}) {Text("Code animé")}
                            TextButton(onClick={demo="homeTutorial"}) {Text("Tutoriel accueil")}
                            TextButton(onClick={demo="profileProgress"}) {Text("Progression du profil")}
                            TextButton(onClick={demo="paywall"}) {Text("Abonnements")}
                            TextButton(onClick={demo="lifetime"}) {Text("Offre à vie")}
                            TextButton(onClick={demo="foodHub"}) {Text("Hub nutrition")}
                            TextButton(onClick={demo="routineHome"}) {Text("Page routine")}
                            TextButton(onClick={demo="settings"}) {Text("Réglages")}
                            TextButton(onClick={demo="waveform"}) {Text("Onde audio")}
                            TextButton(onClick={demo="slideConfirm"}) {Text("Slider de confirmation")}
                            TextButton(onClick={demo="recipe"}) {Text("Recettes")}
                            TextButton(onClick={demo="keypad"}) {Text("Clavier animé")}
                            TextButton(onClick={demo="chips"}) {Text("Sélection tags")}
                            TextButton(onClick={demo="staggered"}) {Text("Apparition cascade")}
                            TextButton(onClick={demo="expandableText"}) {Text("Texte extensible")}
                            TextButton(onClick={demo="transformation"}) {Text("Suivi personnel")}
                            TextButton(onClick={demo="welcomeCards"}) {Text("Cartes accueil")}
                            TextButton(onClick={demo="routineExercise"}) {Text("Exercices")}
                            TextButton(onClick={demo="stackedToasts"}) {Text("Toasts empilés")}
                            TextButton(onClick={demo="verticalPicker"}) {Text("Sélecteur vertical")}
                            TextButton(onClick={demo="helpPrivacy"}) {Text("Aide")}
                            TextButton(onClick={demo="thankYou"}) {Text("Bienvenue")}
                            TextButton(onClick={demo="referralCard"}) {Text("Carte métal")}
                            TextButton(onClick={demo="coverFlow"}) {Text("Cover Flow")}
                            TextButton(onClick={demo="skeleton"}) {Text("Skeleton")}
                            TextButton(onClick={demo="networkMonitor"}) {Text("Réseau")}
                            TextButton(onClick={demo="flipCard"}) {Text("Carte 3D")}
                            TextButton(onClick={demo="sleepSlider"}) {Text("Sommeil")}
                            TextButton(onClick={demo="scanToast"}) {Text("Notification")}
                            TextButton(onClick={demo="programCreation"}) {Text("Création")}
                            TextButton(onClick={demo="reactionPicker"}) {Text("Réactions")}
                            TextButton(onClick={demo="asyncButton"}) {Text("Bouton async")}
                            TextButton(onClick={demo="positionPad"}) {Text("Pad XY")}
                            TextButton(onClick={inputValid=false;demo="estimation"}) {Text(if(english)"Check-in date" else "Date de bilan")}
                            TextButton(onClick={demo="commitSlider"}) {Text(if(english)"Slide" else "Glisser")}
                            TextButton(onClick={demo="hold"}) {Text(if(english)"Hold" else "Engagement")}
                            TextButton(onClick={demo="streak"}) {Text(if(english)"Streak" else "Série")}
                            TextButton(onClick={demo="calendar"}) {Text(if(english)"Calendar" else "Calendrier")}
                            TextButton(onClick={demo="tabs"}) {Text("Navigation")}
                            TextButton(onClick={english=!english}) { Text(if(english) "FR" else "EN") }
                        }
                        if(demo=="typewriter") {
                            Box(Modifier.fillMaxWidth().weight(1f),contentAlignment=androidx.compose.ui.Alignment.Center) {
                                TenKTypewriter(listOf("Welcome to Apple","Discover iPhone","Explore Mac","Experience Airpods","Meet Apple Watch"))
                            }
                        } else if(demo=="gender") {
                            ProcessGenderSelection(gender,{gender=it},Modifier.weight(1f))
                        } else {
                        Text("Hydratation",style=MaterialTheme.typography.titleLarge)
                        ProcessHydrationCard(water,{ value -> water=value; store.edit().putString("day",day).putInt("ml",value).apply() })
                        Text("${water} ml / 2000 ml",style=MaterialTheme.typography.titleMedium)
                        TextButton(onClick={ water=0; store.edit().putString("day",day).putInt("ml",0).apply() }) { Text("Remettre à zéro") }
                        }
                    }
                }
            }
        }
    }
}
