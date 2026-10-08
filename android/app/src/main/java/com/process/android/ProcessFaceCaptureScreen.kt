package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlin.math.*

enum class FaceCameraPermission { UNREQUESTED,DENIED,GRANTED }
data class FaceCaptureViewState(val permission:FaceCameraPermission,val hint:FaceCaptureHint=FaceCaptureHint.SEARCHING,val ready:Boolean=false,val busy:Boolean=false,val hasPhoto:Boolean=false,val flash:Boolean=false,val error:String?=null)
internal object ProcessFaceOval:Shape {
 override fun createOutline(size:Size,layoutDirection:LayoutDirection,density:Density):Outline {
  val path=Path();repeat(96){i->val(x,y)=FaceCaptureGeometry.contour(i/96.0*2*PI);if(i==0)path.moveTo(x*size.width,y*size.height)else path.lineTo(x*size.width,y*size.height)};path.close();return Outline.Generic(path)
 }
}
@Composable fun ProcessFaceCaptureScreen(
 state:FaceCaptureViewState,onBack:()->Unit,onPermission:()->Unit,onFlash:()->Unit,onCapture:()->Unit,onRetake:()->Unit,onContinue:()->Unit,
 modifier:Modifier=Modifier,english:Boolean=false,preview:@Composable ()->Unit
) {
 val background=if(state.flash)Color.White else Color(0xFF0B0D10);val foreground=if(state.flash)Color.Black else Color.White
 Column(modifier.fillMaxSize().background(background).safeDrawingPadding().padding(horizontal=24.dp),horizontalAlignment=Alignment.CenterHorizontally) {
  Row(Modifier.fillMaxWidth().height(56.dp),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) {
   IconButton(onBack){Icon(Icons.Default.ArrowBack,if(english)"Back"else"Retour",tint=foreground)}
   if(!state.hasPhoto)IconButton(onFlash){CaptureFlashGlyph(if(state.flash)Color(0xFFFFAB00)else foreground,if(english)"Toggle screen light"else"Éclairage de l’écran")}
  }
  Spacer(Modifier.height(16.dp))
  Text(if(state.hasPhoto){if(english)"Photo ready"else"Photo prête"}else{if(english)"Your face scan"else"Ton scan visage"},fontSize=30.sp,lineHeight=35.sp,fontWeight=FontWeight.Bold,letterSpacing=(-.4).sp,color=foreground,textAlign=androidx.compose.ui.text.style.TextAlign.Center)
  Spacer(Modifier.weight(1f))
  BoxWithConstraints(Modifier.fillMaxWidth(),contentAlignment=Alignment.Center) {
   val width=minOf(maxWidth-30.dp,280.dp)
   Box(Modifier.width(width).height(width*1.36f).clip(ProcessFaceOval).background(Color.Black.copy(alpha=.84f))) {
    if(state.permission==FaceCameraPermission.GRANTED)preview()
    else Column(Modifier.align(Alignment.Center).padding(22.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(14.dp)) {
     CaptureCameraGlyph(Color.White.copy(alpha=.88f))
     Text(if(state.permission==FaceCameraPermission.UNREQUESTED){if(english)"Camera required"else"Caméra requise"}else{if(english)"Camera disabled"else"Caméra désactivée"},fontSize=16.sp,fontWeight=FontWeight.SemiBold,color=Color.White.copy(alpha=.94f),textAlign=androidx.compose.ui.text.style.TextAlign.Center,letterSpacing=0.sp)
     Text(if(state.permission==FaceCameraPermission.UNREQUESTED){if(english)"Allow access to start your face scan."else"Autorise l’accès pour lancer ton scan visage."}else{if(english)"Turn on camera access for Process in Android Settings."else"Active la caméra pour Process dans les réglages Android."},fontSize=13.sp,lineHeight=18.sp,color=Color.White.copy(alpha=.58f),textAlign=androidx.compose.ui.text.style.TextAlign.Center,letterSpacing=0.sp)
     Button(onPermission,colors=ButtonDefaults.buttonColors(containerColor=Color.White.copy(alpha=.15f),contentColor=Color.White),modifier=Modifier.fillMaxWidth()) {Text(if(state.permission==FaceCameraPermission.DENIED){if(english)"Open settings"else"Ouvrir les réglages"}else{if(english)"Allow camera"else"Autoriser la caméra"},fontSize=15.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp)}
    }
   }
   Canvas(Modifier.width(width+24.dp).height(width*1.36f+24.dp).clearAndSetSemantics {}) {
    val inset=12.dp.toPx();val active=state.hasPhoto
    repeat(72) {i->
     val angle=i/72.0*2*PI;val(x,y)=FaceCaptureGeometry.contour(angle)
     val center=androidx.compose.ui.geometry.Offset(inset+x*(size.width-2*inset),inset+y*(size.height-2*inset))
     val vector=androidx.compose.ui.geometry.Offset(cos(angle).toFloat(),sin(angle).toFloat());val gap=6.dp.toPx();val length=(if(active)10 else 7).dp.toPx()
     drawLine(if(active)Color(.19f,.82f,.35f)else foreground.copy(alpha=.24f),center+vector*gap,center+vector*(gap+length),2.dp.toPx(),StrokeCap.Round)
    }
   }
  }
  Spacer(Modifier.height(26.dp))
  val hint=when(state.hint){
   FaceCaptureHint.SEARCHING->if(english)"Move closer so your face fills the frame."else"Rapproche-toi pour que ton visage remplisse le cadre."
   FaceCaptureHint.MULTIPLE->if(english)"Only one face should be in the frame."else"Garde un seul visage dans le cadre."
   FaceCaptureHint.TOO_FAR->if(english)"Your face needs to fill the frame."else"Ton visage doit bien remplir le cadre."
   FaceCaptureHint.TOO_CLOSE->if(english)"Move back just a little."else"Recule d’un tout petit peu."
   FaceCaptureHint.OFF_CENTER->if(english)"Center your face in the frame."else"Centre ton visage dans le cadre."
   FaceCaptureHint.TURN_FORWARD->if(english)"Look straight at the camera."else"Regarde la caméra de face."
   FaceCaptureHint.LOW_LIGHT->if(english)"Move to better light."else"Place-toi dans une meilleure lumière."
   FaceCaptureHint.READY->if(english)"Perfect. Hold this distance."else"Parfait. Garde cette distance."
   FaceCaptureHint.UNAVAILABLE->if(english)"Face detection unavailable."else"Détection du visage indisponible."
  }
  Text(state.error?:if(state.hasPhoto){if(english)"Continue with this photo, or take another."else"Continue avec cette photo ou reprends-en une."}else hint,fontSize=17.sp,lineHeight=23.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp,color=foreground.copy(alpha=.88f),textAlign=androidx.compose.ui.text.style.TextAlign.Center,modifier=Modifier.heightIn(min=50.dp))
  Spacer(Modifier.weight(1f))
  if(state.permission==FaceCameraPermission.GRANTED) {
   Button(if(state.hasPhoto)onContinue else onCapture,enabled=!state.busy&&(state.hasPhoto||state.ready&&state.hint==FaceCaptureHint.READY),shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=foreground,contentColor=background),modifier=Modifier.fillMaxWidth().height(54.dp)) {
    if(state.busy)CircularProgressIndicator(Modifier.size(20.dp),strokeWidth=2.dp)else Text(if(state.hasPhoto){if(english)"Continue"else"Continuer"}else{if(english)"Take photo"else"Prendre la photo"},fontSize=17.sp,fontWeight=FontWeight.Bold)
   }
   if(state.hasPhoto)TextButton(onRetake,enabled=!state.busy){Text(if(english)"Retake"else"Reprendre",color=foreground.copy(alpha=.7f))}
  }
  Spacer(Modifier.height(20.dp))
 }
}

@Composable private fun CaptureCameraGlyph(tint:Color) {
 Canvas(Modifier.size(28.dp)) {
  val w=size.width;val h=size.height
  drawRoundRect(tint,androidx.compose.ui.geometry.Offset(0f,h*.25f),Size(w,h*.58f),androidx.compose.ui.geometry.CornerRadius(w*.12f))
  drawRoundRect(tint,androidx.compose.ui.geometry.Offset(w*.28f,h*.13f),Size(w*.44f,h*.24f),androidx.compose.ui.geometry.CornerRadius(w*.06f))
  drawCircle(Color.Black,w*.19f,androidx.compose.ui.geometry.Offset(w*.5f,h*.54f));drawCircle(tint,w*.11f,androidx.compose.ui.geometry.Offset(w*.5f,h*.54f))
 }
}
@Composable private fun CaptureFlashGlyph(tint:Color,label:String) {
 Canvas(Modifier.size(22.dp).semantics {contentDescription=label}) {
  val path=Path().apply {moveTo(size.width*.60f,0f);lineTo(size.width*.16f,size.height*.56f);lineTo(size.width*.48f,size.height*.56f);lineTo(size.width*.38f,size.height);lineTo(size.width*.86f,size.height*.40f);lineTo(size.width*.54f,size.height*.40f);close()};drawPath(path,tint)
 }
}
