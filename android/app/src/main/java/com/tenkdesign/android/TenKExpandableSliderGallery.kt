package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.*
import java.util.Locale
@Composable fun TenKExpandableSliderGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var volume by remember {mutableFloatStateOf(30f)};var brightness by remember {mutableFloatStateOf(70f)}
 Column(modifier.fillMaxSize().background(Color(0xfff2f2f2)).padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
  Text("Expandable Slider",fontSize=28.sp,lineHeight=34.sp,color=Color.Black)
  Text("Démonstration — les réglages du téléphone restent inchangés",color=Color.Gray)
  Column(Modifier.background(Color.White,RoundedCornerShape(10.dp)).padding(15.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
   TenKExpandableSlider(volume,{volume=it},reduceMotion=reduceMotion,accessibilityLabel="Volume") {tint->SliderOverlay(volume,tint,false)}
   TenKExpandableSlider(brightness,{brightness=it},config=ExpandableSliderConfig(activeTint=Color.Red),reduceMotion=reduceMotion,accessibilityLabel="Brightness") {tint->SliderOverlay(brightness,tint,true)}
  }
 }
}
@Composable private fun SliderOverlay(value:Float,tint:Color,bell:Boolean) {
 Row(Modifier.fillMaxWidth().padding(horizontal=20.dp),verticalAlignment=Alignment.CenterVertically) {
  if(bell)Icon(Icons.Default.Notifications,null,Modifier.size(22.dp),tint=tint)
  else Canvas(Modifier.size(22.dp)) {
   val p=Path().apply {moveTo(2.dp.toPx(),8.dp.toPx());lineTo(6.dp.toPx(),8.dp.toPx());lineTo(11.dp.toPx(),4.dp.toPx());lineTo(11.dp.toPx(),18.dp.toPx());lineTo(6.dp.toPx(),14.dp.toPx());lineTo(2.dp.toPx(),14.dp.toPx());close()};drawPath(p,tint)
   repeat(3){i->val r=(5+i*3).dp.toPx();drawArc(tint.copy(alpha=if(value>i*33f)1f else .2f),-45f,90f,false,Offset(9.dp.toPx()-r,11.dp.toPx()-r),Size(r*2,r*2),style=Stroke(1.4.dp.toPx()))}
  }
  Spacer(Modifier.weight(1f));Text(String.format(Locale.US,"%.1f%%",value),color=tint,fontSize=16.sp,lineHeight=21.sp,letterSpacing=0.sp)
 }
}
