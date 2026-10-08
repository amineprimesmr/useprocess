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
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import java.time.*

@Composable fun ProcessHomeScanCard(scan:HomeScanSummary?,now:Instant,zone:ZoneId,onScan:()->Unit,onOpenScan:(String)->Unit,media:(@Composable (HomeScanSummary?,Boolean)->Unit)?=null,english:Boolean=false,modifier:Modifier=Modifier) {
 val p=ProcessSurfacePalette(isSystemInDarkTheme());val due=HomeScanCadence.due(scan?.createdAt,now,zone);val shape=RoundedCornerShape(26.dp)
 BoxWithConstraints(modifier.fillMaxWidth().height(if(due)100.dp else 136.dp).clip(shape).background(p.card).then(if(!due&&scan!=null)Modifier.clickable(role=Role.Button){onOpenScan(scan.id)}else Modifier)) {
  val width=if(due)minOf(118.dp,maxWidth*.36f)else 138.dp
  Row(Modifier.fillMaxSize()) {
   if(due||scan?.showsMedia==true)Box(Modifier.width(width).fillMaxHeight().clip(RoundedCornerShape(topEnd=18.dp,bottomEnd=18.dp)).background(p.primary.copy(alpha=.05f)),contentAlignment=Alignment.Center) {
    if(media!=null)media(scan,due)else Column(horizontalAlignment=Alignment.CenterHorizontally) {Icon(Icons.Default.Person,null,tint=p.secondary,modifier=Modifier.size(28.dp));Text(if(english)"Preview unavailable"else"Aperçu indisponible",fontSize=10.sp,lineHeight=12.sp,color=p.secondary,modifier=Modifier.padding(6.dp))}
   }
   Column(Modifier.weight(1f).fillMaxHeight().padding(start=if(due)14.dp else 10.dp,end=14.dp,top=if(due)14.dp else 10.dp,bottom=10.dp),verticalArrangement=Arrangement.spacedBy(if(due)10.dp else 8.dp)) {
    if(due) {
     Text(if(scan==null){if(english)"First scan available"else"Premier scan disponible"}else{if(english)"Today's scan available"else"Scan du jour disponible"},fontSize=15.sp,lineHeight=18.sp,fontWeight=FontWeight.SemiBold,color=p.primary,letterSpacing=0.sp)
     Box(Modifier.fillMaxWidth().height(34.dp).background(p.strongCard,RoundedCornerShape(12.dp)).clickable(role=Role.Button,onClick=onScan),contentAlignment=Alignment.Center) {
      Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(5.dp)){Icon(Icons.Default.AddCircle,null,Modifier.size(14.dp),tint=p.primary);Text(if(english)"Start my scan"else"Faire mon scan",fontSize=13.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=p.primary)}
     }
    } else if(scan!=null) {
     Text(scan.score?.takeIf {it>0}?.let {"$it%"}?:"—",fontSize=48.sp,lineHeight=54.sp,fontWeight=FontWeight.Bold,letterSpacing=(-.45).sp,color=p.primary,modifier=Modifier.semantics {contentDescription=if(english)"Scan score ${scan.score?:"unavailable"}"else"Score du scan ${scan.score?:"indisponible"}"})
     Spacer(Modifier.weight(1f))
     Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text(if(english)"Next scan"else"Prochain scan",fontSize=12.sp,color=p.secondary,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp);Text(HomeScanCadence.countdown(scan.createdAt,now,zone),fontSize=12.sp,color=p.secondary,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp)}
     val progress=HomeScanCadence.progress(scan.createdAt,now,zone)
     Box(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape).background(p.primary.copy(alpha=.10f)).semantics {progressBarRangeInfo=ProgressBarRangeInfo(progress,0f..1f)}){Box(Modifier.fillMaxHeight().fillMaxWidth(progress).background(Color(0xFF69A9FF)))}
    }
   }
  }
 }
}
