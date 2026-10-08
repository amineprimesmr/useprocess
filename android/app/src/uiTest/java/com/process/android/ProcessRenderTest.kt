package com.process.android

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.activity.ComponentActivity
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.annotation.LooperMode
import java.io.File

/** Host-render proof only. This is not iOS comparison, emulator or physical-device proof. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@LooperMode(LooperMode.Mode.PAUSED)
@Config(sdk=[34],qualifiers="w393dp-h852dp-mdpi")
class ProcessRenderTest {
    @get:Rule val compose=createAndroidComposeRule<ComponentActivity>()
    private fun capture(name:String) {
        compose.waitForIdle()
        val bitmap=compose.runOnIdle {
            val view=org.robolectric.shadows.ShadowDialog.getLatestDialog()?.takeIf {it.isShowing}?.window?.decorView?:compose.activity.window.decorView
            Bitmap.createBitmap(view.width,view.height,Bitmap.Config.ARGB_8888).also {view.draw(Canvas(it))}
        }
        val file=File("../parity/host-render/$name.png");file.parentFile?.mkdirs()
        file.outputStream().use {assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
        assertTrue(bitmap.width>300&&bitmap.height>500)
    }
    private fun layoutHostDialog() {
        // Robolectric has no real WindowManager traversal for a newly opened full-window dialog.
        compose.runOnIdle {
            val decor=org.robolectric.shadows.ShadowDialog.getLatestDialog().window!!.decorView
            val source=compose.activity.window.decorView
            decor.measure(android.view.View.MeasureSpec.makeMeasureSpec(source.width,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(source.height,android.view.View.MeasureSpec.EXACTLY))
            decor.layout(0,0,source.width,source.height)
        }
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
    }
    @Test fun realPlanJsonPreservesUnknownFieldsAndRejectsOtherOwner() {
        val raw="""{"id":"plan","userId":"u","createdAt":0,"lastUpdated":1.5,"headline":"Original","executiveSummary":"Text","futureField":{"nested":[1,2,3]}}"""
        val document=ProcessPlanJson.decode(raw,"u")
        assertEquals(raw,document.rawJson);assertEquals("plan",document.plan.id)
        assertThrows(IllegalArgumentException::class.java){ProcessPlanJson.decode(raw,"someone-else")}
        assertThrows(IllegalArgumentException::class.java){ProcessPlanJson.decode(" ".repeat(4*1024*1024+1),"u")}
        assertThrows(IllegalArgumentException::class.java){ProcessPlanJson.decode("[".repeat(10000)+"]".repeat(10000),"u")}
        assertEquals("plan",ProcessPlanJson.decode(raw.replace("Original","Title [with] {braces}"),"u").plan.id)
    }
    @Test fun backdropOriginalImagesSwipeAndSelection() {
        var selected=""
        compose.setContent {MaterialTheme {TenKBackdropCarousel(originalBackdropImages,Modifier.fillMaxSize().testTag("backdrop"),onSelection={selected=it}){Text("iJustine")}}}
        compose.runOnIdle{assertEquals("1",selected)}
        compose.onAllNodes(hasScrollAction()).onLast().performTouchInput{swipe(androidx.compose.ui.geometry.Offset(width*.8f,centerY),androidx.compose.ui.geometry.Offset(width*.2f,centerY),800)}
        compose.waitForIdle();compose.runOnIdle{assertEquals("2",selected)}
        capture("backdrop-original-second")
    }
    @Test fun wallpaperSelectionActionsAndContextReset() {
        var context by mutableStateOf("a");var selected="";var customized="";var added=0
        compose.setContent {MaterialTheme {TenKWallpaperCarousel(originalWallpapers,Modifier.fillMaxSize().testTag("wallpapers"),contextKey=context,reduceMotion=true,onSelect={selected=it.id},onCustomize={customized=it.id},onSecondary={added++})}}
        compose.runOnIdle{assertEquals("1",selected)}
        capture("wallpaper-original-first")
        compose.onAllNodes(hasScrollAction()).onLast().performTouchInput{swipe(androidx.compose.ui.geometry.Offset(width*.8f,centerY),androidx.compose.ui.geometry.Offset(width*.2f,centerY),800)}
        compose.waitForIdle();compose.runOnIdle{assertEquals("3",selected)}
        compose.onNodeWithContentDescription("Customize").performClick()
        compose.onNodeWithContentDescription("Add").performClick()
        compose.runOnIdle{assertEquals("3",customized);assertEquals(1,added)}
        capture("wallpaper-original-second")
        compose.runOnIdle{context="b"};compose.waitForIdle();compose.runOnIdle{assertEquals("1",selected)}
    }
    @Test fun scrollInteractionOriginalPagingAndEmptyData() {
        var images by mutableStateOf(originalScrollImages);var selected="";var reduced by mutableStateOf(false)
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color.Black),contentAlignment=androidx.compose.ui.Alignment.Center){TenKScrollInteraction(images,Modifier.fillMaxWidth().testTag("scrollfx"),reduceMotion=reduced,onSelection={selected=it})}}}
        capture("scroll-interaction-source-transform")
        compose.runOnIdle{reduced=true};compose.waitForIdle()
        compose.onNodeWithTag("scrollfx").performTouchInput{swipeLeft()}
        compose.waitForIdle();compose.runOnIdle{assertNotEquals("1",selected)}
        compose.onAllNodes(hasScrollAction()).onLast().performScrollToIndex(1)
        compose.waitForIdle();compose.runOnIdle{assertEquals("2",selected)}
        capture("scroll-interaction-reduced-motion")
        compose.runOnIdle{images=emptyList()};compose.waitForIdle()
        compose.onNodeWithContentDescription("Photo by SenuScape").assertDoesNotExist()
    }
    @Test fun viewSnapshotCapturesOnlyWrappedVisibleBoundsOnTriggerChange() {
        var trigger by mutableStateOf(false);var result:ViewSnapshotImage?=null;var failure:Throwable?=null
        compose.setContent {MaterialTheme {Column(Modifier.fillMaxSize().background(Color.Green)) {
            Button({trigger=!trigger}){Text("Capture")}
            TenKViewSnapshot(trigger,{result=it},{failure=it},method=ViewSnapshotMethod.SOFTWARE_VIEW){Box(Modifier.size(100.dp,50.dp).background(Color.Red))}
        }}}
        compose.runOnIdle {assertNull(result)}
        compose.onNodeWithText("Capture").performClick()
        compose.waitUntil(5000){result!=null||failure!=null};assertNull(failure)
        assertEquals(ViewSnapshotMethod.SOFTWARE_VIEW,result!!.method);assertEquals(100,result!!.bitmap.width);assertEquals(50,result!!.bitmap.height)
        assertEquals(android.graphics.Color.RED,result!!.bitmap.getPixel(50,25))
        File("../parity/host-render/view-snapshot-software-crop.png").outputStream().use {assertTrue(result!!.bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
    }
    @Test fun viewSnapshotRejectsSecureWindowEvenForSoftwareMode() {
        var trigger by mutableStateOf(false);var failure:Throwable?=null;var captures=0
        compose.setContent {MaterialTheme {TenKViewSnapshot(trigger,{captures++},{failure=it},Modifier.size(100.dp),method=ViewSnapshotMethod.SOFTWARE_VIEW){Text("Private")}}}
        compose.runOnIdle {compose.activity.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);trigger=true}
        try {compose.waitForIdle();compose.waitUntil(5000){failure!=null};assertEquals(0,captures);assertTrue(failure!!.message!!.contains("Secure"))}
        finally {compose.runOnIdle {compose.activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)}}
    }
    @Test fun viewSnapshotContextResetDoesNotCaptureInitialTrigger() {
        var trigger by mutableStateOf(false);var context by mutableStateOf("old");var captures=0
        compose.setContent {MaterialTheme {TenKViewSnapshot(trigger,{captures++},{throw it},Modifier.size(100.dp),contextKey=context,method=ViewSnapshotMethod.SOFTWARE_VIEW){Text("Current")}}}
        compose.runOnIdle {trigger=true;context="new"}
        compose.waitForIdle();assertEquals(0,captures)
    }
    @Test fun qrScannerPermissionAndDismissalRemainExplicit() {
        var permissions=0;var close=0;var dismissals=0
        compose.setContent {MaterialTheme {TenKQrScannerScreen(QrCameraPermission.UNREQUESTED,false,null,{permissions++},{},{close++},{dismissals++},reduceMotion=true){}}}
        compose.onNodeWithText("Allow camera").performClick();assertEquals(1,permissions)
        capture("qr-scanner-permission-light")
        compose.onNodeWithContentDescription("Close QR scanner").performClick()
        compose.runOnIdle {assertEquals(1,dismissals);assertEquals(1,close)}
    }
    @Test fun qrScannerDisplaysDeniedSettingsAndReadyFixture() {
        var permission by mutableStateOf(QrCameraPermission.DENIED);var settings=0
        compose.setContent {MaterialTheme {TenKQrScannerScreen(permission,true,null,{settings++},{},{},reduceMotion=true){Box(Modifier.fillMaxSize().background(Color(0xFF333333))){Text("Camera fixture",color=Color.White)}}}}
        compose.onNodeWithText("Go to Settings").performClick();assertEquals(1,settings)
        compose.runOnIdle {permission=QrCameraPermission.GRANTED}
        compose.onNodeWithText("Scan your QR code").assertIsDisplayed()
        capture("qr-scanner-ready-fixture-light")
    }
    @Test fun pdfSampleLayoutHasSevenPagesAndRendersOriginalRows() {
        // Host Robolectric has no PdfDocument native shadow: this verifies layout only.
        assertEquals(7,TenKPdfSample.pageCount)
        for(index in listOf(0,6)) {
            val bitmap=Bitmap.createBitmap(595,842,Bitmap.Config.ARGB_8888)
            TenKPdfSample.draw(Canvas(bitmap),index)
            val output=File("../parity/host-render/pdf-layout-page-${index+1}.png")
            output.outputStream().use {assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
            assertEquals(android.graphics.Color.WHITE,bitmap.getPixel(300,820))
        }
    }
    @Test fun downsizedImageKeysRevisionAndUsesCachedImageWithoutOriginal() {
        val root=java.nio.file.Files.createTempDirectory("tenk-image-host").toFile();val cache=TenKImageCache(root,"host")
        var revision by mutableStateOf("red");var original by mutableStateOf<Bitmap?>(Bitmap.createBitmap(40,20,Bitmap.Config.ARGB_8888).apply {eraseColor(android.graphics.Color.RED)})
        var color=0;var dimensions=androidx.compose.ui.unit.IntSize.Zero;var imageError:Throwable?=null
        compose.setContent {MaterialTheme {TenKDownsizedImage("image",revision,original,androidx.compose.ui.unit.IntSize(100,100),cache,onError={imageError=it}) {image->
            SideEffect {color=image.asAndroidBitmap().getPixel(0,0);dimensions=androidx.compose.ui.unit.IntSize(image.width,image.height)}
            androidx.compose.foundation.Image(image,"Loaded original")
        }}}
        compose.waitUntil(10000){color==android.graphics.Color.RED};assertEquals(androidx.compose.ui.unit.IntSize(100,50),dimensions)
        compose.runOnIdle {revision="blue";original=Bitmap.createBitmap(20,40,Bitmap.Config.ARGB_8888).apply {eraseColor(android.graphics.Color.BLUE)}}
        compose.waitForIdle();compose.waitUntil(10000){color==android.graphics.Color.BLUE||imageError!=null};assertNull(imageError?.stackTraceToString(),imageError);assertEquals(androidx.compose.ui.unit.IntSize(50,100),dimensions)
        compose.runOnIdle {color=0;original=null}
        compose.waitForIdle()
        compose.waitUntil(10000){color==android.graphics.Color.BLUE}
        root.deleteRecursively()
    }
    @Test fun downsizedImageMissingSourceReportsFailureInsteadOfSpinningForever() {
        val root=java.nio.file.Files.createTempDirectory("tenk-image-error").toFile();var failures=0
        compose.setContent {MaterialTheme {TenKDownsizedImage("missing","1",null,androidx.compose.ui.unit.IntSize(20,20),TenKImageCache(root,"missing"),onError={failures++}){}}}
        compose.waitUntil(10000){failures==1}
        compose.onNodeWithText("Image unavailable").assertIsDisplayed()
        root.deleteRecursively()
    }
    @Test fun downsizedGalleryUsesThreeOriginalPhotos() {
        compose.setContent {MaterialTheme {TenKImageCacheGallery {}}}
        compose.waitUntil(10000){compose.onAllNodesWithContentDescription("Original picture 3").fetchSemanticsNodes().isNotEmpty()}
        compose.onNodeWithContentDescription("Original picture 1").assertIsDisplayed()
        compose.onNodeWithContentDescription("Original picture 2").assertIsDisplayed()
        capture("downsized-original-images-light")
    }
    @Test fun timedPagingResetsPauseAndEmitsOneRequestWhenHostDoesNotChangeSelection() {
        compose.mainClock.autoAdvance=false
        var paused by mutableStateOf(false);var changes=0;var next=-1
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize(),contentAlignment=androidx.compose.ui.Alignment.Center) {
            TenKTimedPagingIndicator(3,2000,paused,0,{changes++;next=it},reduceMotion=true)
        }}}
        compose.mainClock.advanceTimeBy(1000);compose.waitForIdle();assertEquals(0,changes)
        compose.runOnIdle {paused=true};compose.mainClock.advanceTimeByFrame();compose.waitForIdle();compose.mainClock.advanceTimeBy(4000);compose.waitForIdle();assertEquals(0,changes)
        capture("timed-paging-paused-light")
        compose.runOnIdle {paused=false};compose.mainClock.advanceTimeByFrame();compose.waitForIdle();compose.mainClock.advanceTimeBy(1000);compose.waitForIdle();assertEquals(0,changes)
        capture("timed-paging-progress-light")
        compose.mainClock.advanceTimeBy(1200);compose.waitForIdle();assertEquals(1,changes);assertEquals(1,next)
        compose.mainClock.advanceTimeBy(6000);compose.waitForIdle();assertEquals(1,changes)
    }
    @Test fun timedPagingWrapsAndContextChangeCancelsOldCountdown() {
        compose.mainClock.autoAdvance=false
        var selection by mutableIntStateOf(2);var context by mutableStateOf("old");val changes=mutableListOf<Int>()
        compose.setContent {MaterialTheme {TenKTimedPagingIndicator(3,2000,false,selection,{changes+=it;selection=it},contextKey=context,reduceMotion=true)}}
        compose.mainClock.advanceTimeBy(1500);compose.waitForIdle()
        compose.runOnIdle {context="new"}
        compose.mainClock.advanceTimeBy(1000);compose.waitForIdle();assertTrue(changes.isEmpty())
        compose.mainClock.advanceTimeBy(1200);compose.waitForIdle();assertEquals(listOf(0),changes)
    }
    @Test fun scrollAwareNavigationHidesAfterDownDragAndReturnsOnReverse() {
        compose.setContent {MaterialTheme {
            val scroll=androidx.compose.foundation.rememberScrollState()
            TenKScrollAwareNavigation(scroll,Modifier.fillMaxSize(),reduceMotion=true,navigation={Text("Navigation bar",Modifier.fillMaxWidth().height(60.dp).background(Color.White))}) {
                Column(Modifier.fillMaxSize().verticalScroll(scroll).testTag("navigation-scroll")) {repeat(50){Text("Item $it",Modifier.height(50.dp))}}
            }
        }}
        compose.onNodeWithText("Navigation bar").assertIsDisplayed()
        compose.onNodeWithTag("navigation-scroll").performTouchInput {down(center);moveBy(androidx.compose.ui.geometry.Offset(0f,-25f))}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.onNodeWithTag("navigation-scroll").performTouchInput {moveBy(androidx.compose.ui.geometry.Offset(0f,-100f))}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.onNodeWithText("Navigation bar").assertDoesNotExist()
        capture("scroll-navigation-hidden-light")
        compose.onNodeWithTag("navigation-scroll").performTouchInput {moveBy(androidx.compose.ui.geometry.Offset(0f,15f))}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.onNodeWithTag("navigation-scroll").performTouchInput {moveBy(androidx.compose.ui.geometry.Offset(0f,25f))}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.onNodeWithText("Navigation bar").assertIsDisplayed()
        compose.onNodeWithTag("navigation-scroll").performTouchInput {up()}
        capture("scroll-navigation-restored-light")
    }
    @Test fun alertDrawerHonorsActionResultAndRestoresSource() {
        lateinit var state:AlertDrawerState;var primary=0;var secondary=0
        compose.setContent {MaterialTheme {
            state=rememberAlertDrawerState("first")
            TenKAlertDrawer(state,"Confirm","Cancel",{primary++;false},{secondary++;true},reduceMotion=true,drawerContent={Text("Are you sure?")}) {
                Box(Modifier.fillMaxSize().padding(20.dp)){TenKDrawerSourceButton("Open drawer",state,Modifier.align(androidx.compose.ui.Alignment.BottomCenter).fillMaxWidth())}
            }
        }}
        compose.onNodeWithText("Open drawer").performClick()
        compose.onNodeWithText("Are you sure?").assertIsDisplayed()
        compose.onNodeWithText("Confirm").performClick()
        compose.runOnIdle {assertEquals(1,primary);assertTrue(state.isPresented)}
        capture("alert-drawer-confirmation-light")
        compose.onNodeWithText("Cancel").performClick()
        compose.runOnIdle {assertEquals(1,secondary);assertFalse(state.isPresented)}
        compose.onNodeWithText("Open drawer").assertIsDisplayed().performClick()
        compose.onNodeWithContentDescription("Dismiss confirmation").performClick()
        compose.onNodeWithText("Open drawer").assertIsDisplayed()
    }
    @Test fun alertDrawerContextResetDiscardsPreviousPresentation() {
        var context by mutableStateOf("one")
        compose.setContent {MaterialTheme {
            val state=rememberAlertDrawerState(context)
            TenKAlertDrawer(state,"Confirm","Cancel",{true},{true},reduceMotion=true,drawerContent={Text("Sensitive previous context")}) {
                TenKDrawerSourceButton("Open drawer",state,Modifier.fillMaxWidth())
            }
        }}
        compose.onNodeWithText("Open drawer").performClick()
        compose.onNodeWithText("Sensitive previous context").assertIsDisplayed()
        compose.runOnIdle {context="two"}
        compose.onNodeWithText("Sensitive previous context").assertDoesNotExist()
        compose.onNodeWithText("Open drawer").assertIsDisplayed()
    }
    @Test fun alertDrawerOriginalGalleryRendersExpandedCard() {
        compose.setContent {MaterialTheme {TenKAlertDrawerGallery {}}}
        compose.onNodeWithText("Continue").performClick()
        compose.onNodeWithText("Are you sure?").assertIsDisplayed()
        compose.mainClock.advanceTimeBy(100);compose.waitForIdle()
        compose.onNodeWithText("Cancel").assertIsDisplayed()
        capture("alert-drawer-original-light")
    }
    @Test fun swipeActionsCoordinateRowsAndRespectActionCloseResult() {
        lateinit var coordinator:SwipeActionCoordinator
        var actions=0
        compose.setContent {MaterialTheme {
            coordinator=rememberSwipeActionCoordinator("test")
            Column {repeat(2){index->TenKSwipeActions("row:$index",coordinator,listOf(
                TenKSwipeAction("keep","Keep $index",Color.Blue,onAction={actions++;false}){Text("K")},
                TenKSwipeAction("close","Close $index",Color.Red,onAction={actions++;true}){Text("C")}
            ),Modifier.fillMaxWidth().height(80.dp).testTag("swipe-row-$index")){Text("Row $index",Modifier.fillMaxSize())}}}
        }}
        compose.onNodeWithTag("swipe-row-0").performTouchInput {swipeLeft()}
        compose.runOnIdle {assertEquals("row:0",coordinator.activeId)}
        compose.onNodeWithContentDescription("Keep 0").performClick()
        compose.runOnIdle {assertEquals(1,actions);assertEquals("row:0",coordinator.activeId)}
        compose.onNodeWithTag("swipe-row-1").performTouchInput {swipeLeft()}
        compose.runOnIdle {assertEquals("row:1",coordinator.activeId)}
        compose.onNodeWithContentDescription("Keep 0").assertDoesNotExist()
        capture("swipe-actions-open-light")
        compose.onNodeWithContentDescription("Close 1").performClick()
        compose.runOnIdle {assertEquals(2,actions);assertNull(coordinator.activeId)}
    }
    @Test fun swipeActionsCloseWhenVerticalContentMoves() {
        lateinit var coordinator:SwipeActionCoordinator
        compose.setContent {MaterialTheme {
            coordinator=rememberSwipeActionCoordinator("scroll-test")
            Column(Modifier.fillMaxSize().verticalScroll(androidx.compose.foundation.rememberScrollState()).testTag("messages-scroll")) {
                repeat(20){index->TenKSwipeActions("row:$index",coordinator,listOf(TenKSwipeAction("action","Action $index",Color.Blue,onAction={false}){Text("A")}),Modifier.fillMaxWidth().height(80.dp).testTag("scroll-row-$index")){Text("Row $index",Modifier.fillMaxSize())}}
            }
        }}
        compose.onNodeWithTag("scroll-row-0").performTouchInput {swipeLeft()}
        compose.runOnIdle {assertEquals("row:0",coordinator.activeId)}
        compose.onNodeWithTag("messages-scroll").performTouchInput {swipeUp()}
        compose.runOnIdle {assertNull(coordinator.activeId)}
    }
    @Test fun swipeGalleryUsesOriginalPortraitsWithoutPerformingActions() {
        compose.setContent {MaterialTheme {TenKSwipeActionsGallery {}}}
        compose.onNodeWithText("iJustine").assertIsDisplayed()
        capture("swipe-actions-original-portraits-light")
    }
    @Test fun scrollIndicatorControlsActualContentAndClampsEnds() {
        lateinit var state:androidx.compose.foundation.ScrollState
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize()) {
            state=androidx.compose.foundation.rememberScrollState()
            Column(Modifier.fillMaxSize().then(Modifier.verticalScroll(state))) {repeat(80){Text("Contact $it",Modifier.height(40.dp))}}
            TenKScrollIndicator(state,"A",Modifier.align(androidx.compose.ui.Alignment.CenterEnd).height(400.dp))
        }}}
        compose.onNodeWithContentDescription("Scroll position").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){assertTrue(it(.5f))}
        compose.runOnIdle {assertTrue(kotlin.math.abs(state.value-state.maxValue/2)<=2)}
        compose.onNodeWithContentDescription("Scroll position").performTouchInput {down(center);moveBy(androidx.compose.ui.geometry.Offset(0f,100f));up()}
        compose.runOnIdle {assertTrue(state.value>state.maxValue*.6f)}
        compose.onNodeWithContentDescription("Scroll position").performTouchInput {down(center);moveBy(androidx.compose.ui.geometry.Offset(0f,-30f))}
        capture("scroll-indicator-drag-popup-light")
        compose.onNodeWithContentDescription("Scroll position").performTouchInput {up()}
        compose.onNodeWithContentDescription("Scroll position").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){assertTrue(it(2f))}
        compose.runOnIdle {assertEquals(state.maxValue,state.value)}
        capture("scroll-indicator-end-light")
    }
    @Test fun scrollIndicatorGalleryPreservesOriginalContacts() {
        compose.setContent {MaterialTheme {TenKScrollIndicatorGallery {}}}
        compose.onNodeWithText("Alice Johnson").assertIsDisplayed()
        compose.onNodeWithText("Abigail Cooper").assertIsDisplayed()
        capture("scroll-indicator-original-contacts-light")
    }
    @Test fun thankYouRequiresVerifiedAccess() {
        var complete=0
        compose.setContent {MaterialTheme {ProcessPostPaymentThankYou(false,true,{ProcessAccountCompletion.Completed},{complete++},reduceMotion=true)}}
        compose.onNodeWithText("Continuer avec Apple").assertIsNotEnabled()
        compose.onNodeWithText("Ton accès Pro doit être vérifié avant de continuer.").assertIsDisplayed()
        capture("thank-you-unverified-light")
        assertEquals(0,complete)
    }
    @Test fun welcomeDeckDismissesInOrder() {
        var state by mutableStateOf(WelcomeCardDismissal())
        var referrals=0
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color(0xFFF7F8FC)).padding(20.dp)) {
            ProcessWelcomeCards(state,{state=it},{referrals++},reduceMotion=true)
        }}}
        compose.onNodeWithText("Bienvenue dans Process").assertIsDisplayed()
        compose.onAllNodesWithContentDescription("Fermer").assertCountEquals(1)
        capture("welcome-front-light")
        compose.onNodeWithContentDescription("Fermer").performClick()
        compose.onNodeWithText("Bienvenue dans Process").assertDoesNotExist()
        compose.onNodeWithText("🎁 Mois ou an offert").assertIsDisplayed().performClick()
        compose.runOnIdle {assertEquals(1,referrals);assertTrue(state.frontDismissed);assertFalse(state.stackDismissed)}
        capture("welcome-referral-light")
        compose.onNodeWithContentDescription("Fermer").performClick()
        compose.onNodeWithText("🎁 Mois ou an offert").assertDoesNotExist()
        compose.runOnIdle {assertTrue(state.stackDismissed)}
    }
    @Test fun routineStillAndClose() {
        var closed=0
        val step=ProcessRoutineCatalog.steps.first()
        compose.setContent {MaterialTheme {ProcessRoutineExerciseDetail(step,{closed++},reduceMotion=true)}}
        compose.onNodeWithText(step.title(false)).assertIsDisplayed()
        capture("routine-first-still-light")
        compose.onNodeWithContentDescription("Fermer").performClick()
        assertEquals(1,closed)
    }
    @Test @Config(qualifiers="w393dp-h852dp-night-mdpi") fun thankYouFailureCanRetry() {
        var attempts=0;var completed=0
        compose.setContent {MaterialTheme {ProcessPostPaymentThankYou(true,true,{attempts++;ProcessAccountCompletion.Failed("Connexion de test indisponible")},{completed++},reduceMotion=true)}}
        compose.onNodeWithText("Continuer avec Apple").performClick()
        compose.onNodeWithText("Connexion de test indisponible").assertIsDisplayed()
        compose.onNodeWithText("OK").performClick()
        compose.onNodeWithText("Continuer avec Apple").assertIsEnabled()
        capture("thank-you-verified-dark")
        compose.onNodeWithText("Continuer avec Apple").performClick()
        compose.runOnIdle {assertEquals(2,attempts);assertEquals(0,completed)}
    }
    @Test fun currentTransformationCopyAndContinue() {
        var completed=0
        compose.setContent {MaterialTheme {ProcessTransformationPreview({completed++})}}
        compose.onNodeWithText("Un suivi qui part de toi").assertIsDisplayed()
        compose.onNodeWithText("Les scores du scan sont des estimations de bien-être, pas des mesures médicales ni un diagnostic.").assertIsDisplayed()
        capture("tracking-disclosure-light")
        compose.onNodeWithText("CONTINUER").performClick()
        assertEquals(1,completed)
    }
    @Test fun expandableTextOpensAndCloses() {
        var collapsed by mutableStateOf(true)
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color.White).padding(20.dp)) {
            com.tenkdesign.android.TenKExpandableText(com.tenkdesign.android.expandableSampleText,collapsed,{collapsed=it},reduceMotion=true)
        }}}
        val node=compose.onNodeWithText(com.tenkdesign.android.expandableSampleText)
        val shortHeight=node.fetchSemanticsNode().boundsInRoot.height
        capture("expandable-text-collapsed-light")
        node.performClick()
        compose.runOnIdle {assertFalse(collapsed)}
        assertTrue(node.fetchSemanticsNode().boundsInRoot.height>shortHeight*2)
        capture("expandable-text-expanded-light")
        node.performClick()
        compose.runOnIdle {assertTrue(collapsed)}
        assertEquals(shortHeight,node.fetchSemanticsNode().boundsInRoot.height,.1f)
    }
    @Test fun staggeredShowAndInterruptedExit() {
        var shown by mutableStateOf(false)
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color.White).padding(20.dp)) {
            com.tenkdesign.android.TenKStaggeredColumn(shown,3) {index -> Text("Staggered row $index")}
        }}}
        compose.onNodeWithText("Staggered row 0").assertDoesNotExist()
        compose.mainClock.autoAdvance=false
        compose.runOnIdle {shown=true}
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(64)
        compose.waitForIdle()
        compose.onNodeWithText("Staggered row 0").assertExists()
        compose.onNodeWithText("Staggered row 2").assertDoesNotExist()
        compose.mainClock.advanceTimeBy(2000)
        compose.onNodeWithText("Staggered row 2").assertIsDisplayed()
        capture("staggered-visible-light")
        compose.runOnIdle {shown=false}
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(32)
        compose.runOnIdle {shown=true}
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(2000)
        compose.onAllNodesWithText("Staggered row 2").assertCountEquals(1)
        compose.runOnIdle {shown=false}
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        compose.mainClock.advanceTimeBy(2000)
        compose.onNodeWithText("Staggered row 0").assertDoesNotExist()
        compose.mainClock.autoAdvance=true
    }
    @Test fun chipsRetainSelectionOrderAndReflow() {
        var selected by mutableStateOf(emptyList<String>())
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color.White).padding(20.dp)) {
            com.tenkdesign.android.TenKChips(com.tenkdesign.android.originalChipTags,selected,{selected=it}) {tag,checked ->
                com.tenkdesign.android.TenKChip(tag,checked,reduceMotion=true)
            }
        }}}
        compose.onNodeWithText("SwiftUI").performClick().assertIsOn()
        compose.onNodeWithText("iOS 14").performClick().assertIsOn()
        compose.runOnIdle {assertEquals(listOf("SwiftUI","iOS 14"),selected)}
        capture("chips-selected-light")
        compose.onNodeWithText("SwiftUI").performClick().assertIsOff()
        compose.runOnIdle {assertEquals(listOf("iOS 14"),selected)}
        compose.onNodeWithText("Objective-C").assertIsDisplayed().performClick().assertIsOn()
        compose.runOnIdle {assertEquals(listOf("iOS 14","Objective-C"),selected)}
    }
    @Test fun keypadEntryDeleteAndHostCallback() {
        var value by mutableStateOf(com.tenkdesign.android.AnimatedKeypadValue())
        var submitted:Int?=null
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKAnimatedKeypad(value,{value=it},{submitted=it},reduceMotion=true)}}
        compose.onNodeWithText("0").performClick()
        compose.runOnIdle {assertEquals("",value.digits)}
        compose.onNodeWithText("1").performClick()
        repeat(3){compose.onNodeWithText("0").performClick()}
        compose.onNodeWithContentDescription("$1,000").assertIsDisplayed()
        capture("keypad-thousand-dark")
        compose.onNodeWithContentDescription("Delete last digit").performClick()
        compose.onNodeWithText("Continue").performClick()
        compose.runOnIdle {assertEquals(100,submitted)}
    }
    @Test fun heldDeleteRepeatsAndStopsAfterRelease() {
        var value by mutableStateOf(com.tenkdesign.android.AnimatedKeypadValue("12345"))
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKAnimatedKeypad(value,{value=it},{},reduceMotion=true)}}
        val key=compose.onNodeWithContentDescription("Delete last digit")
        compose.mainClock.autoAdvance=false
        key.performTouchInput {down(center)}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.mainClock.advanceTimeBy(1200);compose.waitForIdle()
        key.performTouchInput {up()}
        compose.mainClock.autoAdvance=true;compose.waitForIdle()
        compose.runOnIdle {assertEquals("",value.digits);value=com.tenkdesign.android.AnimatedKeypadValue("7")}
        compose.mainClock.advanceTimeBy(500);compose.waitForIdle()
        compose.runOnIdle {assertEquals("7",value.digits)}
    }
    @Test fun keypadOriginalAvatarPreview() {
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKAnimatedKeypadGallery({},reduceMotion=true)}}
        compose.onNodeWithContentDescription("iJustine").assertIsDisplayed()
        compose.onNodeWithText("Aperçu — aucun argent envoyé").assertIsDisplayed()
        capture("keypad-original-gallery-dark")
    }
    @Test fun recipeCyclesAndFlushesScopedDraft() {
        val meals=ProcessRecipeCatalog.forSlot("lunch");val drafts=mutableListOf<RecipeDraft>();var closed=0
        compose.setContent {MaterialTheme {ProcessRecipeDetail(meals.first(),{closed++},alternatives=meals,editable=true,draftContext="test-only/day-1",onDraftChanged={drafts.add(it)},reduceMotion=true)}}
        compose.onNodeWithText(meals.first().name.french).assertIsDisplayed()
        compose.onNodeWithText("Estimation nutritionnelle indisponible").assertIsDisplayed()
        capture("recipe-original-first-light")
        compose.onNodeWithText("Changez de repas").performClick()
        compose.onNodeWithText(meals[1].name.french).assertIsDisplayed()
        compose.onNodeWithText("Fermer").performClick()
        compose.runOnIdle {assertEquals(1,closed);assertEquals(meals[1].id,drafts.last().meal.id);assertEquals("test-only/day-1",drafts.last().contextKey)}
    }
    @Test fun recipePreviewNeverEmitsUnscopedDraft() {
        var drafts=0;val meals=ProcessRecipeCatalog.forSlot("lunch")
        compose.setContent {MaterialTheme {ProcessRecipeDetail(meals.first(),{},alternatives=meals,editable=true,onDraftChanged={drafts++},reduceMotion=true,english=true)}}
        compose.onNodeWithText("Change meal").performClick()
        compose.onNodeWithText("Close").performClick()
        compose.runOnIdle {assertEquals(0,drafts)}
    }
    @Test fun slideConfirmReturnsUnlessDraggedToEndAndOnlyConfirmsOnce() {
        var confirmations=0
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize(),contentAlignment=androidx.compose.ui.Alignment.Center) {
            com.tenkdesign.android.TenKSlideToConfirm({confirmations++},reduceMotion=true)
        }}}
        val slider=compose.onNodeWithContentDescription("Swipe to Pay")
        slider.performTouchInput {swipe(androidx.compose.ui.geometry.Offset(32f,centerY),androidx.compose.ui.geometry.Offset(145f,centerY),300)}
        compose.runOnIdle {assertEquals(0,confirmations)}
        slider.assert(SemanticsMatcher.expectValue(androidx.compose.ui.semantics.SemanticsProperties.ProgressBarRangeInfo,androidx.compose.ui.semantics.ProgressBarRangeInfo(0f,0f..1f)))
        capture("slide-confirm-idle-light")
        slider.performTouchInput {swipe(androidx.compose.ui.geometry.Offset(32f,centerY),androidx.compose.ui.geometry.Offset(width-1f,centerY),400)}
        compose.runOnIdle {assertEquals(1,confirmations)}
        compose.onNodeWithContentDescription("Success!").assertIsNotEnabled()
        capture("slide-confirm-completed-light")
        compose.onNodeWithContentDescription("Success!").performTouchInput {click()}
        compose.runOnIdle {assertEquals(1,confirmations)}
    }
    @Test fun waveformDragUsesRelativePositionAndReportsGestureEnd() {
        var progress by mutableFloatStateOf(.32f);val gestures=mutableListOf<Boolean>()
        val samples=FloatArray(1000){i->kotlin.math.sin(i*.12).toFloat()}
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().padding(20.dp),contentAlignment=androidx.compose.ui.Alignment.Center) {
            com.tenkdesign.android.TenKWaveformScrubber(samples,progress,{progress=it},onGestureActive={gestures.add(it)})
        }}}
        val waveform=compose.onNodeWithContentDescription("Audio position")
        waveform.performTouchInput {swipe(androidx.compose.ui.geometry.Offset(width*.5f,centerY),androidx.compose.ui.geometry.Offset(width*.8f,centerY),300)}
        compose.runOnIdle {assertTrue(progress>.5f&&progress<.7f);assertEquals(listOf(true,false),gestures)}
        waveform.performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){assertTrue(it(.9f))}
        compose.runOnIdle {assertEquals(.9f,progress,.001f)}
        capture("waveform-synthetic-host-light")
    }
    @Test fun settingsPreferencesAvoidDuplicateWritesAndStudioRemainsConditional() {
        var state by mutableStateOf(ProcessSettingsState());val actions=mutableListOf<ProcessSettingsAction>();var changes=0
        compose.setContent {MaterialTheme {ProcessSettingsHub(state,{},actions::add,{changes++;state=state.copy(appearance=it)},{changes++;state=state.copy(language=it)},reduceMotion=true,soundEnabled=false)}}
        compose.onNodeWithText("Mon compte").performClick()
        compose.runOnIdle {assertEquals(listOf(ProcessSettingsAction.ACCOUNT),actions)}
        compose.onNodeWithText("Apparence").performClick()
        compose.onNodeWithText("Sombre").performClick().assertIsSelected()
        compose.onNodeWithText("Sombre").performClick()
        compose.runOnIdle {assertEquals(1,changes);assertEquals(ProcessAppearance.DARK,state.appearance)}
        capture("settings-appearance-dark")
        compose.onNodeWithContentDescription("Retour").performClick()
        compose.onNodeWithText("Langue").performClick()
        compose.onNodeWithText("🇺🇸 English").performClick().assertIsSelected()
        compose.runOnIdle {assertEquals(2,changes);assertEquals(ProcessLanguage.ENGLISH,state.language)}
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithText("My Account").assertIsDisplayed()
        capture("settings-hub-english-dark")
        compose.onNode(hasScrollToIndexAction()).performScrollToNode(hasText("Refer friends"))
        compose.onNodeWithText("Refer friends").performClick()
        compose.runOnIdle {assertEquals(ProcessSettingsAction.REFERRAL,actions.last())}
        compose.onNodeWithText("Content Studio").assertDoesNotExist()
    }
    @Test fun routineHoldUsesFiveSecondsAndStopsAfterCancellation() {
        var day by mutableStateOf(RoutineHomeDay("test-plan/day-1",true));val events=mutableListOf<RoutineCompletion>();var details=0
        compose.setContent {MaterialTheme {ProcessRoutineHome(day,4567,{details++},{_,_->},{events.add(it);day=day.copy(completedStepIds=day.completedStepIds+it.stepId)},{},reduceMotion=true)}}
        val card=compose.onNodeWithContentDescription(ProcessRoutineCatalog.steps.first().title(false))
        card.performTouchInput {click()}
        compose.runOnIdle {assertEquals(1,details)}
        capture("routine-home-original-cards-light")
        compose.mainClock.autoAdvance=false
        card.performTouchInput {down(center)}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.mainClock.advanceTimeBy(3000);compose.waitForIdle()
        card.performTouchInput {cancel()}
        compose.mainClock.advanceTimeBy(3000);compose.waitForIdle()
        compose.runOnIdle {assertTrue(events.isEmpty());assertEquals(1,details)}
        card.performTouchInput {down(center)}
        compose.mainClock.advanceTimeByFrame();compose.waitForIdle()
        compose.mainClock.advanceTimeBy(5100);compose.waitForIdle()
        card.performTouchInput {up()}
        compose.mainClock.autoAdvance=true;compose.waitForIdle()
        compose.runOnIdle {assertEquals(listOf(RoutineCompletion("test-plan/day-1",ProcessRoutineCatalog.steps.first().id)),events)}
    }
    @Test fun elasticControlSupportsTapDragAndAccessibleSelection() {
        var selected by mutableStateOf("Play")
        compose.setContent {MaterialTheme {Column(Modifier.fillMaxSize().padding(15.dp)) {
            com.tenkdesign.android.TenKElasticSegmentedControl(listOf("Play","News","Library","Search"),selected,{selected=it},reduceMotion=true){Text(it)}
        }}}
        compose.onNodeWithContentDescription("Library").performTouchInput {click()}
        compose.runOnIdle {assertEquals("Library",selected)}
        compose.onNodeWithContentDescription("News").performClick().assertIsSelected()
        compose.runOnIdle {assertEquals("News",selected)}
        capture("elastic-library-host-light")
    }
    @Test fun expandableSliderTracksRelativeDragAndExternalValue() {
        var value by mutableFloatStateOf(30f);val events=mutableListOf<Boolean>()
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().padding(20.dp),contentAlignment=androidx.compose.ui.Alignment.Center) {
            com.tenkdesign.android.TenKExpandableSlider(value,{value=it},reduceMotion=true,onGestureActive={events.add(it)},accessibilityLabel="Test volume") {color->Text("${value.toInt()}%",color=color)}
        }}}
        val slider=compose.onNodeWithContentDescription("Test volume")
        slider.performTouchInput {swipe(androidx.compose.ui.geometry.Offset(width*.2f,centerY),androidx.compose.ui.geometry.Offset(width*.4f,centerY),300)}
        compose.runOnIdle {assertEquals(50f,value,2f);assertEquals(listOf(true,false),events);value=70f}
        slider.performTouchInput {down(center);moveTo(androidx.compose.ui.geometry.Offset(width*.6f,centerY))}
        compose.waitForIdle();capture("expandable-slider-active-host-light")
        slider.performTouchInput {up()}
        compose.runOnIdle {assertEquals(80f,value,2f)}
    }
    @Test fun tickPickerCentersInitialExternalAndDraggedSelections() {
        var selection by mutableIntStateOf(5)
        compose.setContent {MaterialTheme {Column(Modifier.fillMaxSize().padding(top=100.dp)) {
            com.tenkdesign.android.TenKTickPicker(100,selection,{selection=it},reduceMotion=true)
        }}}
        compose.mainClock.advanceTimeBy(100);compose.waitForIdle()
        val picker=compose.onNodeWithContentDescription("Tick value")
        compose.runOnIdle {assertEquals(5,selection)}
        capture("tick-picker-initial-light")
        compose.runOnIdle {selection=42}
        compose.waitForIdle()
        picker.performTouchInput {swipeLeft()}
        compose.waitForIdle()
        compose.runOnIdle {assertTrue("Drag must advance from the externally selected42: $selection",selection>42&&selection<=100)}
        picker.performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.SetProgress){assertTrue(it(9f))}
        compose.waitForIdle();compose.runOnIdle {assertEquals(9,selection)}
        capture("tick-picker-external-light")
    }
    @Test fun animatedConfirmationMapsCancelAndConfirmWithoutDeletingAnything() {
        val results=mutableListOf<com.tenkdesign.android.ConfirmationResult>()
        compose.setContent {MaterialTheme {Column(Modifier.fillMaxSize().padding(20.dp)) {
            com.tenkdesign.android.TenKAnimatedConfirmationButton({results.add(it)},reduceMotion=true,label={Text("Delete Account?",Modifier.fillMaxWidth().padding(20.dp))}) {Text("Are you sure?")}
        }}}
        capture("confirmation-source-host-light")
        compose.onNodeWithContentDescription("Open confirmation").performClick()
        layoutHostDialog()
        capture("confirmation-sheet-host-light")
        compose.onNodeWithText("Are you sure?").assertIsDisplayed()
        compose.onNodeWithText("Cancel").performClick()
        compose.runOnIdle {assertEquals(listOf(com.tenkdesign.android.ConfirmationResult.CANCELLED),results)}
        compose.onNodeWithContentDescription("Open confirmation").performClick()
        layoutHostDialog()
        compose.onNodeWithText("Delete").performClick()
        compose.runOnIdle {assertEquals(listOf(com.tenkdesign.android.ConfirmationResult.CANCELLED,com.tenkdesign.android.ConfirmationResult.CONFIRMED),results)}
    }
    @Test fun borderBeamCanDisableWithoutRemovingContent() {
        var enabled by mutableStateOf(true)
        compose.setContent {MaterialTheme {Box(Modifier.fillMaxSize().background(Color.Black).padding(30.dp)) {
            com.tenkdesign.android.TenKBorderBeam(Modifier.fillMaxWidth(),enabled=enabled,reduceMotion=true,beam=listOf(Color.Green,Color.Blue,Color.Magenta)) {Text("Beam content",Modifier.fillMaxWidth().padding(30.dp),color=Color.White)}
        }}}
        compose.onNodeWithText("Beam content").assertIsDisplayed()
        capture("border-beam-static-host-dark")
        compose.runOnIdle {enabled=false}
        compose.onNodeWithText("Beam content").assertIsDisplayed()
    }
    @Test fun foodHubSearchNavigationAndPlanSlotChanges() {
        var slots by mutableStateOf(listOf("breakfast","lunch","dinner"))
        var food:DebloatFood?=null;var meal:FoodHubMeal?=null;var all=0;var water=0;var scan=0
        compose.setContent {MaterialTheme {ProcessFoodHub({food=it},{meal=it},{all++},{water++},{scan++},configuredSlots=slots)}}
        compose.onNodeWithText("Banane").assertIsDisplayed()
        capture("foodhub-original-assets-light")
        compose.onNodeWithContentDescription("Rechercher un aliment…").performTextInput("épinards")
        compose.onNodeWithText("Épinards").performClick()
        assertEquals("epinards",food?.id)
        compose.onNodeWithText("Banane").assertDoesNotExist()
        compose.onNodeWithContentDescription("Effacer la recherche").performClick()
        compose.onNodeWithText("Banane").assertExists()
        compose.onNodeWithText("Aliments Debloat").performClick()
        compose.onNodeWithContentDescription("Ouvrir l’hydratation").performClick()
        compose.onNodeWithContentDescription("Scanner un aliment").performClick()
        assertEquals(1,all);assertEquals(1,water);assertEquals(1,scan)
        compose.runOnIdle {slots=listOf("dinner")}
        compose.onNodeWithText("Dîner").assertIsSelected()
        val dinner=ProcessRecipeCatalog.meals.first {it.slot=="dinner"}
        compose.onNodeWithText(dinner.name.french).performScrollTo().performClick()
        assertEquals(dinner.id,meal?.meal?.id);assertFalse(meal!!.fromPlan)
    }

    @Test fun lifetimeUnavailableNeverStartsPurchase() {
        var purchases=0;var verified=0
        compose.setContent {MaterialTheme {ProcessLifetimeOffer(null,null,{purchases++;ProcessBillingResult.Cancelled},{ProcessBillingResult.NoPurchases},{verified++},{},{},{})}}
        compose.onNodeWithText("Acheter l’accès à vie").assertIsNotEnabled()
        compose.onNodeWithText("Restaurer mes achats").assertIsNotEnabled()
        compose.onNodeWithText("—").assertIsDisplayed()
        capture("lifetime-unavailable-light")
        assertEquals(0,purchases);assertEquals(0,verified)
    }
    @Test fun lifetimePendingFailureRetryAndVerifiedCompletion() {
        val offer=ProcessBillingOffer("test-only-lifetime",ProcessBillingPlan.LIFETIME,"Prix de test","Achat unique de test")
        var attempts=0;var verified=0
        compose.setContent {MaterialTheme {ProcessLifetimeOffer("fixture-account",offer,{attempts++;when(attempts){1->ProcessBillingResult.Pending;2->ProcessBillingResult.Failed("Échec de test");else->ProcessBillingResult.VerifiedAccess("fixture-account")}},{ProcessBillingResult.NoPurchases},{verified++},{},{},{})}}
        compose.onNodeWithText("Acheter l’accès à vie").performClick()
        compose.onNodeWithText("Achat en attente. L’accès sera activé après vérification.").assertIsDisplayed()
        assertEquals(0,verified)
        compose.onNodeWithText("Acheter l’accès à vie").performClick()
        compose.onNodeWithText("Échec de test").assertIsDisplayed()
        compose.onNodeWithText("Acheter l’accès à vie").performClick()
        compose.runOnIdle {assertEquals(3,attempts);assertEquals(1,verified)}
        compose.onNodeWithText("Acheter l’accès à vie").assertIsNotEnabled()
    }
    @Test fun lifetimeRejectsResultAfterAccountChanges() {
        var account by mutableStateOf("old")
        val deferred=kotlinx.coroutines.CompletableDeferred<ProcessBillingResult>()
        var verified=0
        val offer=ProcessBillingOffer("test-only",ProcessBillingPlan.LIFETIME,"Test","Test")
        compose.setContent {MaterialTheme {ProcessLifetimeOffer(account,offer,{deferred.await()},{ProcessBillingResult.NoPurchases},{verified++},{},{},{})}}
        compose.onNodeWithText("Acheter l’accès à vie").performClick()
        compose.runOnIdle {account="new"}
        compose.waitForIdle()
        compose.runOnIdle {deferred.complete(ProcessBillingResult.VerifiedAccess("old"))}
        compose.waitForIdle()
        assertEquals(0,verified)
        compose.onNodeWithText("Acheter l’accès à vie").assertIsEnabled()
    }
    @Test fun paywallLiveProductsAndSelectionAreRequired() {
        var offers by mutableStateOf(emptyList<ProcessBillingOffer>())
        var bought:String?=null;var complete=0
        compose.setContent {MaterialTheme {ProcessPaywall("fixture",offers,{bought=it.productId;ProcessBillingResult.Pending},{ProcessBillingResult.NoPurchases},{complete++},{},{},{},{},{},reduceMotion=true)}}
        compose.onNodeWithText("Continuer, aucun engagement.").assertIsNotEnabled()
        capture("paywall-unavailable-light")
        compose.runOnIdle {offers=listOf(ProcessBillingOffer("annual-test",ProcessBillingPlan.ANNUAL,"Annuel de test","Conditions annuelles de test"),ProcessBillingOffer("monthly-test",ProcessBillingPlan.MONTHLY,"Mensuel de test","Conditions mensuelles de test"))}
        compose.onNodeWithText("Annuel").assertIsSelected()
        compose.onNodeWithText("Mensuel").performClick()
        compose.onNodeWithText("Conditions mensuelles de test").assertIsDisplayed()
        compose.onNodeWithText("Continuer, aucun engagement.").performClick()
        compose.runOnIdle {assertEquals("monthly-test",bought);assertEquals(0,complete)}
    }
    @Test fun profileEmptyAndRealHistoryRemainDistinct() {
        val today=java.time.LocalDate.of(2026,10,8)
        var snapshot by mutableStateOf<ProfileSnapshot?>(null)
        var settings=0;var calendar=0
        compose.setContent {MaterialTheme {ProcessProfileProgress(snapshot,{settings++},{calendar++},today=today,zone=java.time.ZoneId.of("Europe/Paris"),reduceMotion=true)}}
        compose.onNodeWithText("Scanne ton visage pour remplacer cette courbe d’exemple par ta vraie évolution.").assertExists()
        capture("profile-empty-sample-light")
        compose.onNodeWithContentDescription("Calendrier, choisir une date").performClick()
        compose.onNodeWithContentDescription("Réglages").performClick()
        assertEquals(1,settings);assertEquals(1,calendar)
        compose.runOnIdle {snapshot=ProfileSnapshot("fixture-user","Amine",listOf(ProfileScan("a",java.time.Instant.parse("2026-10-07T12:00:00Z"),50),ProfileScan("b",java.time.Instant.parse("2026-10-08T12:00:00Z"),65)))}
        compose.onNodeWithText("65%").assertExists()
        compose.onNodeWithText("Ton score a gagné +15 pts sur cette période.").assertExists()
        compose.onNodeWithText("Scanne ton visage pour remplacer cette courbe d’exemple par ta vraie évolution.").assertDoesNotExist()
        compose.onNodeWithText("Tout").performScrollTo().performClick().assertIsSelected()
        capture("profile-real-fixture-light")
    }

    @Test fun profileMetricChartsRenderRealValuesInSourceOrder() {
        val scans=(0..2).map {i->ProfileScan("fixture-$i",java.time.Instant.parse("2026-10-0${6+i}T12:00:00Z"),60+i*5,ProfileVisualMetric.entries.associateWith {listOf(62.0,50.0,47.8)[i]})}
        compose.setContent {MaterialTheme {ProcessProfileProgress(ProfileSnapshot("fixture-metrics","A",scans),{},{},today=java.time.LocalDate.of(2026,10,8),reduceMotion=true)}}
        compose.onNodeWithContentDescription("Progression du profil").performScrollToNode(hasText("Aspect gonflé"))
        compose.onNodeWithText("Aspect gonflé").assertIsDisplayed()
        capture("profile-metric-fixture-light")
        compose.onNodeWithContentDescription("Progression du profil").performScrollToNode(hasText("Capture"))
        compose.onNodeWithText("Capture").assertIsDisplayed()
        compose.onNodeWithText("Poids").assertDoesNotExist()
        compose.onNodeWithText("Effort").assertDoesNotExist()
    }

    @Test fun mealAnalysisNeverRevealsBeforeActualResultAndOnlyNotifiesOnce() {
        var complete by mutableStateOf(false);var reveals=0
        compose.mainClock.autoAdvance=false
        compose.setContent {MaterialTheme {ProcessMealAnalyzing("meal-request",complete,{reveals++},english=true,reduceMotion=true,photo={androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.recipe_meal_debloat_chicken_salad_bowl),null,Modifier.fillMaxSize(),contentScale=androidx.compose.ui.layout.ContentScale.Crop)})}}
        compose.mainClock.advanceTimeBy(8000);compose.waitForIdle();assertEquals(0,reveals)
        compose.onNodeWithContentDescription("Computing debloat score, in progress").assertIsDisplayed()
        capture("meal-analysis-waiting-original-light")
        compose.runOnIdle {complete=true};compose.mainClock.advanceTimeBy(600);compose.waitForIdle();assertEquals(1,reveals)
        capture("meal-analysis-completed-original-light")
        compose.mainClock.advanceTimeBy(2000);compose.waitForIdle();assertEquals(1,reveals)
    }
    @Test fun mealAnalysisPreservesSourceMinimumTimingAndCancelsOldRequest() {
        var request by mutableStateOf("first");var complete by mutableStateOf(true);var reveals=0
        compose.mainClock.autoAdvance=false
        compose.setContent {MaterialTheme {ProcessMealAnalyzing(request,complete,{reveals++},english=true,reduceMotion=true)}}
        compose.mainClock.advanceTimeBy(6000);compose.waitForIdle();assertEquals(0,reveals)
        compose.runOnIdle {request="second";complete=false};compose.mainClock.advanceTimeBy(1000);compose.waitForIdle();assertEquals(0,reveals)
        compose.runOnIdle {complete=true};compose.mainClock.advanceTimeBy(8000);compose.waitForIdle();assertEquals(1,reveals)
    }
    @Test fun mealAnalysisFailureBlocksRevealUntilHostRetry() {
        var failure by mutableStateOf<String?>("Analysis unavailable");var request by mutableStateOf("failed");var reveals=0;var retries=0
        compose.mainClock.autoAdvance=false
        compose.setContent {MaterialTheme {ProcessMealAnalyzing(request,true,{reveals++},english=true,analysisFailure=failure,onRetry={retries++;request="retry";failure=null},reduceMotion=true)}}
        compose.mainClock.advanceTimeBy(8000);compose.waitForIdle();assertEquals(0,reveals)
        capture("meal-analysis-failed-light")
        compose.onNodeWithText("Try again").performClick();assertEquals(1,retries)
        compose.mainClock.advanceTimeBy(8000);compose.waitForIdle();assertEquals(1,reveals)
    }
    @Test fun faceCapturePermissionGateExplainsAndroidSettings() {
        var requests=0;var permission by mutableStateOf(FaceCameraPermission.UNREQUESTED)
        compose.setContent {MaterialTheme {ProcessFaceCaptureScreen(FaceCaptureViewState(permission),{},{requests++},{},{},{},{},english=true){}}}
        compose.onNodeWithText("Camera required").assertIsDisplayed();compose.onNodeWithText("Take photo").assertDoesNotExist()
        capture("face-camera-permission-dark")
        compose.onNodeWithText("Allow camera").performClick();assertEquals(1,requests)
        compose.runOnIdle {permission=FaceCameraPermission.DENIED};compose.waitForIdle()
        compose.onNodeWithText("Open settings").assertIsDisplayed()
    }
    @Test fun faceCaptureBlocksPoorFramesAndEnablesOnlyReadyCamera() {
        var state by mutableStateOf(FaceCaptureViewState(FaceCameraPermission.GRANTED,hint=FaceCaptureHint.LOW_LIGHT,ready=true));var captures=0
        compose.setContent {MaterialTheme {ProcessFaceCaptureScreen(state,{},{},{},{captures++},{},{},english=true){Box(Modifier.fillMaxSize().background(Color(0xFF222222)))}}}
        compose.onNodeWithText("Take photo").assertIsNotEnabled()
        compose.runOnIdle {state=state.copy(hint=FaceCaptureHint.READY)};compose.waitForIdle()
        compose.onNodeWithText("Take photo").performClick();assertEquals(1,captures)
        capture("face-camera-ready-fixture-dark")
        compose.runOnIdle {state=state.copy(busy=true)};compose.waitForIdle();assertEquals(1,captures)
    }
    @Test fun faceCapturePhotoReviewUsesHostAcceptanceAndRetake() {
        var continuations=0;var retakes=0
        compose.setContent {MaterialTheme {ProcessFaceCaptureScreen(FaceCaptureViewState(FaceCameraPermission.GRANTED,hasPhoto=true),{},{},{},{},{retakes++},{continuations++},english=true){Box(Modifier.fillMaxSize(),contentAlignment=androidx.compose.ui.Alignment.Center){Text("Fixture photo",color=Color.White)}}}}
        compose.onNodeWithText("Retake").performClick();assertEquals(1,retakes)
        compose.onNodeWithText("Continue").performClick();assertEquals(1,continuations)
        capture("face-camera-review-fixture-dark")
    }
    @Composable private fun HomeTestHost(snapshot:ProcessHomeSnapshot,onScan:()->Unit={},onFood:()->Unit={},onWater:(String,Int)->Unit={_,_->},onRestore:suspend (String)->Unit={}) {
        ProcessHomeDashboard(snapshot,{ },onScan,{ },onFood,onWater,{ },{ },{ },{ },onRestore,WelcomeCardDismissal(true,true),{ },{ },english=true,now=java.time.Instant.parse("2026-10-08T12:00:00Z"),zone=java.time.ZoneId.of("UTC"),reduceMotion=true)
    }
    @Test fun homeWithoutPlanShowsRestoreAndDoesNotInventSections() {
        var restored=0
        val today=java.time.LocalDate.of(2026,10,8)
        compose.setContent {MaterialTheme {HomeTestHost(ProcessHomeSnapshot("account:missing","Ada",null,today,canRestore=true),onRestore={restored++})}}
        compose.onNodeWithText("Hi Ada").assertIsDisplayed()
        compose.onNodeWithText("First scan available").assertDoesNotExist()
        compose.onNodeWithText("Restore my personalized plan").performClick();compose.waitForIdle();assertEquals(1,restored)
        capture("home-no-plan-light")
    }
    @Test fun homePlanOriginalMealsAndHydrationEmitScopedChanges() {
        val today=java.time.LocalDate.of(2026,10,8);var scans=0;var food=0;var waterChange:Pair<String,Int>?=null
        val snapshot=ProcessHomeSnapshot("account:plan:day","Ada",HomePlanCalendar("plan",today,28),today,localWaterMl=500,meals=listOf(HomeMealTile("one","recipe_meal_debloat_eggs_banana_kiwi"),HomeMealTile("two","recipe_meal_debloat_chicken_sweet_potato"),HomeMealTile("three","recipe_meal_debloat_salmon_quinoa_salad")))
        compose.setContent {MaterialTheme {HomeTestHost(snapshot,{scans++},{food++},{key,ml->waterChange=key to ml})}}
        compose.onNodeWithText("Start my scan").performClick();assertEquals(1,scans)
        compose.onNodeWithContentDescription("Today's meals").performScrollTo().performClick();assertEquals(1,food)
        capture("home-original-nutrition-light")
        compose.onNodeWithContentDescription("Ajouter 500 millilitres d’eau").performClick();assertEquals("account:plan:day" to 1000,waterChange)
        compose.onNodeWithText("Lymphatic circuit").performScrollTo().assertIsDisplayed()
        capture("home-original-routine-light")
    }
    @Test fun homeFutureDayKeepsScanButHidesEditableMealsAndRoutine() {
        val today=java.time.LocalDate.of(2026,10,8)
        compose.setContent {MaterialTheme {HomeTestHost(ProcessHomeSnapshot("account:future","Ada",HomePlanCalendar("plan",today,28),today.plusDays(1)))}}
        compose.onNodeWithText("First scan available").assertIsDisplayed()
        compose.onNodeWithText("Upcoming day").assertIsDisplayed()
        compose.onNodeWithText("Today's meals").assertDoesNotExist()
        compose.onNodeWithText("Lymphatic circuit").assertDoesNotExist()
        capture("home-future-day-light")
    }
    @Test fun gridEdgeAutoScrollStopsAndCancellationRestoresBaseline() {
        var selected by mutableStateOf(setOf("8"))
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKDragSelectionGrid((0..79).toList(),{it.toString()},selected,{selected=it},true,{},{},{},Modifier.fillMaxSize(),reduceMotion=true) {
            Box(Modifier.fillMaxSize().background(Color.Blue))
        }}}
        compose.mainClock.autoAdvance=false
        val first=compose.onNodeWithContentDescription("Grid item 0").fetchSemanticsNode().boundsInRoot.center
        val root=compose.onRoot().fetchSemanticsNode().boundsInRoot
        compose.onRoot().performTouchInput {down(first);moveTo(first+androidx.compose.ui.geometry.Offset(25f,0f));moveTo(androidx.compose.ui.geometry.Offset(first.x,root.bottom-70f),delayMillis=200)}
        compose.mainClock.advanceTimeBy(1500);compose.waitForIdle()
        assertTrue("Auto-scroll selection: $selected",selected.map {it.toInt()}.max()>32)
        compose.onRoot().performTouchInput {cancel()};compose.waitForIdle()
        assertEquals(setOf("8"),selected)
        compose.mainClock.advanceTimeBy(500);compose.waitForIdle();assertEquals(setOf("8"),selected)
    }
    @Test fun gridDragAddsSubtractsAndPreservesUnrelatedSelection() {
        var selected by mutableStateOf(setOf("8"));var enabled by mutableStateOf(true);var share:Set<String>?=null
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKDragSelectionGrid((0..44).toList(),{it.toString()},selected,{selected=it},enabled,{enabled=it},{share=it},{},Modifier.fillMaxSize(),reduceMotion=true) {
            Box(Modifier.fillMaxSize().background(Color(0xFF007AFF),androidx.compose.foundation.shape.RoundedCornerShape(18.dp)))
        }}}
        val first=compose.onNodeWithContentDescription("Grid item 0").fetchSemanticsNode().boundsInRoot.center
        val third=compose.onNodeWithContentDescription("Grid item 2").fetchSemanticsNode().boundsInRoot.center
        compose.onRoot().performTouchInput {swipe(first,third,400)}
        compose.waitForIdle();assertEquals(setOf("0","1","2","8"),selected)
        capture("multi-selection-range-light")
        compose.onRoot().performTouchInput {swipe(first,third,400)}
        compose.waitForIdle();assertEquals(setOf("8"),selected)
        compose.onNodeWithContentDescription("Grid item 1").performClick();assertEquals(setOf("1","8"),selected)
        compose.onNodeWithContentDescription("Share selection").performClick();assertEquals(selected,share)
    }
    @Test fun mobileOtpRequiresProviderAndPreservesOriginalCountries() {
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKMobileOtpGallery()}}
        compose.onNodeWithText("Get OTP").assertIsNotEnabled()
        compose.onNodeWithText("+1 (US)").assertIsDisplayed()
        val countries=com.tenkdesign.android.loadMobileOtpCountries(compose.activity)
        assertEquals(242,countries.size);assertEquals("IL",countries.first().code)
        capture("mobile-otp-unavailable-light")
    }
    @Test fun mobileOtpCompletesOnlyAfterMatchingProviderVerification() {
        var sends=0;var completions=0;var attempts=0
        val service=object:com.tenkdesign.android.MobileOtpService {
            override suspend fun send(e164:String):com.tenkdesign.android.MobileOtpSendResult {sends++;return com.tenkdesign.android.MobileOtpSendResult.Sent(com.tenkdesign.android.MobileOtpChallenge("fixture-challenge",e164))}
            override suspend fun verify(challenge:com.tenkdesign.android.MobileOtpChallenge,code:String):com.tenkdesign.android.MobileOtpVerifiedSession {
                attempts++;if(code!="123456")throw IllegalArgumentException("fixture rejection")
                return com.tenkdesign.android.MobileOtpVerifiedSession("fixture-user",challenge.e164)
            }
        }
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKMobileOtpLogin("fixture",service,{_,phone->if(phone=="5555550123")"+15555550123"else null},{completions++},{},{},reduceMotion=true)}}
        compose.onNode(hasSetTextAction()).performTextInput("5555550123")
        compose.onNodeWithText("Get OTP").performClick()
        compose.mainClock.advanceTimeBy(2300);compose.waitForIdle();layoutHostDialog()
        assertEquals(1,sends);assertEquals(0,completions)
        compose.onNodeWithContentDescription("Verification code").performTextInput("000000")
        compose.waitForIdle();assertEquals(0,completions);assertEquals(1,attempts)
        capture("mobile-otp-verification-light")
        compose.onNodeWithContentDescription("Verification code").performTextReplacement("123456")
        compose.waitForIdle();assertEquals(1,completions);assertEquals(2,attempts)
    }
    @Test fun mobileOtpAbandonedContextDiscardsNonCooperativeSend() {
        var context by mutableStateOf("first");var completions=0;var started=false
        val gate=kotlinx.coroutines.CompletableDeferred<Unit>()
        val service=object:com.tenkdesign.android.MobileOtpService {
            override suspend fun send(e164:String):com.tenkdesign.android.MobileOtpSendResult=kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {started=true;gate.await();com.tenkdesign.android.MobileOtpSendResult.Verified(com.tenkdesign.android.MobileOtpVerifiedSession("fixture-user",e164))}
            override suspend fun verify(challenge:com.tenkdesign.android.MobileOtpChallenge,code:String):com.tenkdesign.android.MobileOtpVerifiedSession=error("unused")
        }
        compose.setContent {MaterialTheme {com.tenkdesign.android.TenKMobileOtpLogin(context,service,{_,phone->if(phone.isNotEmpty())"+15555550123"else null},{completions++},{},{},reduceMotion=true)}}
        compose.onNode(hasSetTextAction()).performTextInput("5555550123");compose.onNodeWithText("Get OTP").performClick()
        compose.mainClock.advanceTimeBy(2300);compose.waitForIdle();assertTrue(started)
        compose.runOnIdle {context="second"};compose.waitForIdle()
        compose.runOnIdle {gate.complete(Unit)};compose.waitForIdle();assertEquals(0,completions)
    }
    @Test fun verificationNormalizesInputAndChangesStyle() {
        var value by mutableStateOf("");var style by mutableStateOf(com.tenkdesign.android.VerificationCodeStyle.ROUNDED)
        compose.setContent {MaterialTheme {Column(Modifier.fillMaxSize().padding(20.dp)) {
            com.tenkdesign.android.TenKVerificationCode(value,{value=it},length=com.tenkdesign.android.VerificationCodeLength.FOUR,style=style,reduceMotion=true) {
                if(it.length<4)com.tenkdesign.android.VerificationCodeState.TYPING else if(it=="1235")com.tenkdesign.android.VerificationCodeState.VALID else com.tenkdesign.android.VerificationCodeState.INVALID
            }
        }}}
        compose.onNodeWithContentDescription("Verification code").performTextInput("١٢３５99")
        compose.waitForIdle();assertEquals("1235",value)
        compose.onNodeWithContentDescription("Verification code").assert(SemanticsMatcher.expectValue(androidx.compose.ui.semantics.SemanticsProperties.StateDescription,"Valid"))
        capture("verification-rounded-valid-light")
        compose.runOnIdle {style=com.tenkdesign.android.VerificationCodeStyle.UNDERLINED;value="0000"}
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Verification code").assert(SemanticsMatcher.expectValue(androidx.compose.ui.semantics.SemanticsProperties.StateDescription,"Invalid"))
        capture("verification-underlined-invalid-light")
    }
    @Test fun verificationDiscardsNonCooperativeStaleValidation() {
        var value by mutableStateOf("");var state=com.tenkdesign.android.VerificationCodeState.TYPING
        val first=kotlinx.coroutines.CompletableDeferred<Unit>()
        compose.setContent {MaterialTheme {
            com.tenkdesign.android.TenKVerificationCode(value,{value=it},reduceMotion=true,onStateChange={state=it}) {code ->
                if(code=="111111")kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable){first.await();com.tenkdesign.android.VerificationCodeState.VALID}
                else if(code.length==6)com.tenkdesign.android.VerificationCodeState.INVALID else com.tenkdesign.android.VerificationCodeState.TYPING
            }
        }}
        compose.runOnIdle {value="111111"};compose.waitForIdle()
        compose.runOnIdle {value="222222"};compose.waitForIdle()
        compose.runOnIdle {first.complete(Unit)};compose.waitForIdle()
        assertEquals(com.tenkdesign.android.VerificationCodeState.INVALID,state)
    }
    @Test fun homeTutorialStartsFromAnotherTabAndCompletesFiveStepsOnce() {
        var tab by mutableStateOf("profile");var completions=0
        compose.setContent {MaterialTheme {
            val state=rememberHomeTutorialState("fixture-tutorial",false,{completions++})
            ProcessHomeTutorialCoordinator(state,true,true,tab,{tab=it},{})
            Box(Modifier.fillMaxSize().background(Color(0xFFF7F8FC)).padding(22.dp)) {
                if(state.progress.active&&!state.progress.step.isTabStep)ProcessHomeTutorial(state,state.progress.step,reduceMotion=true) {Box(Modifier.fillMaxWidth().height(160.dp).background(Color(0xFF151A22))){Text("Fixture card",color=Color.White)}}
                if(state.progress.active&&state.progress.step.isTabStep)ProcessTutorialTabFooter(state,Modifier.align(androidx.compose.ui.Alignment.BottomCenter))
            }
        }}
        compose.onNodeWithText("Scan analyse").assertIsDisplayed()
        assertEquals("plan",tab);assertEquals(0,completions)
        capture("tutorial-first-step-light")
        repeat(4){compose.onNodeWithText("Continuer").performClick()}
        compose.onNodeWithText("Série").assertIsDisplayed()
        assertEquals("profile",tab)
        compose.onNodeWithText("C’est parti").performClick()
        compose.runOnIdle {assertEquals(1,completions)}
        compose.onNodeWithText("Série").assertDoesNotExist()
    }
    @Test fun tutorialManualNavigationEndsWithoutForcingHome() {
        var tab by mutableStateOf("plan");var completions=0
        compose.setContent {MaterialTheme {
            val state=rememberHomeTutorialState("fixture-navigation",false,{completions++})
            ProcessHomeTutorialCoordinator(state,true,false,tab,{tab=it},{})
        }}
        compose.runOnIdle {tab="food"}
        compose.waitForIdle()
        assertEquals(1,completions);assertEquals("food",tab)
    }

    @Test fun tutorialMissingCtaReleasesHomeInsteadOfLockingIt() {
        var completions=0;var tab by mutableStateOf("plan")
        compose.setContent {MaterialTheme {
            val state=rememberHomeTutorialState("fixture-missing-card",false,{completions++})
            ProcessHomeTutorialCoordinator(state,true,true,tab,{tab=it},{})
        }}
        compose.waitForIdle()
        assertEquals(0,completions)
        compose.mainClock.autoAdvance=false
        compose.mainClock.advanceTimeBy(1600)
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        assertEquals(1,completions)
        compose.mainClock.advanceTimeBy(2000)
        compose.mainClock.advanceTimeByFrame()
        compose.waitForIdle()
        assertEquals(1,completions)
    }

}
