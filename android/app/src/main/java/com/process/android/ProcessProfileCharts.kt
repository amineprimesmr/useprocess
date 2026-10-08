package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.*

internal class ProfileIntroSession {private var played=false;fun claim():Boolean {val result=!played;played=true;return result}}
internal fun profileColor(metric:ProfileVisualMetric)=when(metric){ProfileVisualMetric.VISUAL_INDEX->Color(1f,.55f,.35f);ProfileVisualMetric.RECOVERY->Color(.55f,.45f,.95f);ProfileVisualMetric.PUFFINESS->Color(.33f,.72f,1f);ProfileVisualMetric.DEFINITION->Color(.95f,.78f,.35f);ProfileVisualMetric.CAPTURE->Color(1f,.65f,.72f)}
internal fun profilePath(values:List<Double>,width:Float,height:Float,low:Double,high:Double,area:Boolean=false):Path {
 val path=Path();if(values.isEmpty())return path
 val span=max(high-low,.5)
 val points=values.mapIndexed {i,v->Offset(if(values.size==1)width/2 else width*i/(values.size-1),height*(1-(v-low)/span).toFloat())}
 if(area){path.moveTo(points[0].x,height);path.lineTo(points[0].x,points[0].y)}else path.moveTo(points[0].x,points[0].y)
 points.zipWithNext().forEach {(a,b)->val mid=(a.x+b.x)/2;path.cubicTo(mid,a.y,mid,b.y,b.x,b.y)}
 if(area){path.lineTo(points.last().x,height);path.close()};return path
}
@Composable internal fun ProfileNativeChart(points:List<ProfileDayPoint>,p:ProcessSurfacePalette,english:Boolean,modifier:Modifier=Modifier,metric:ProfileVisualMetric?=null,sample:Boolean=false,reduceMotion:Boolean=true,session:ProfileIntroSession?=null) {
 val values=points.map {it.value};val color=metric?.let(::profileColor)?:p.primary
 val range=if(metric==null)0.0 to 100.0 else ProcessProfileModel.axis(values)
 val animate=remember(metric){metric!=null&&session?.claim()==true&&!reduceMotion};val progress=remember {Animatable(if(animate)0f else 1f)}
 LaunchedEffect(Unit){if(animate)progress.animateTo(1f,tween(if(metric==ProfileVisualMetric.VISUAL_INDEX)850 else 900,easing=LinearOutSlowInEasing))}
 val locale=if(english)Locale.US else Locale.FRANCE;val formatter=remember(locale){DateTimeFormatter.ofPattern("EEE",locale)}
 val maxLabels=if(metric==null)5 else 7
 val indexes=if(points.size<=maxLabels)points.indices.toList()else if(metric==null)(0 until maxLabels).map {(it.toDouble()/(maxLabels-1)*(points.size-1)).roundToInt()}else listOf(0,points.size/2,points.size-1)
 val labels=indexes.map {points[it].date.format(formatter).let {s->if(metric==null)s.replaceFirstChar {it.titlecase(locale)}else s.replace(".","").uppercase(locale)}}
 Column(modifier.semantics {contentDescription=(if(sample){if(english)"Sample curve"else"Courbe d’exemple"}else metric?.title(english)?:if(english)"Debloat score evolution"else"Évolution du score debloat")+": "+points.joinToString {"${it.date}: ${it.value.roundToInt()}"}},verticalArrangement=Arrangement.spacedBy(8.dp)) {
  Row(Modifier.weight(1f),horizontalArrangement=Arrangement.spacedBy(if(metric==null)8.dp else 0.dp)) {
   Canvas(Modifier.weight(1f).fillMaxHeight()) {
    val rows=if(metric==null)3 else if(metric==ProfileVisualMetric.PUFFINESS)5 else 4
    repeat(rows){i->val y=size.height*i/(rows-1);drawLine(p.primary.copy(alpha=if(p.dark).14f else .10f),Offset(0f,y),Offset(size.width,y),.5.dp.toPx(),pathEffect=if(metric==null)null else PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(),5.dp.toPx())))}
    if(metric==null)repeat(max(labels.size,2)){i->val x=size.width*i/(max(labels.size,2)-1);drawLine(p.primary.copy(alpha=if(p.dark).14f else .10f),Offset(x,0f),Offset(x,size.height),.5.dp.toPx())}
    if(metric==ProfileVisualMetric.PUFFINESS) {
     val span=max(range.second-range.first,.5);val barWidth=max(6.dp.toPx(),min(18.dp.toPx(),size.width/max(values.size*2,1)))
     values.forEachIndexed {i,v->val x=if(values.size==1)size.width/2 else size.width*i/(values.size-1);val h=(size.height*(v-range.first)/span).toFloat()*progress.value;drawRoundRect(if(i==values.lastIndex)color else p.secondary.copy(alpha=if(p.dark).22f else .16f),Offset(x-barWidth/2,size.height-h),Size(barWidth,max(h,4.dp.toPx())),CornerRadius(4.dp.toPx()))}
    }else {
     val area=profilePath(values,size.width,size.height,range.first,range.second,true)
     drawPath(area,Brush.verticalGradient(listOf(color.copy(alpha=(if(metric==null){if(p.dark).22f else .12f}else .34f)*progress.value),Color.Transparent)))
    }
    val line=profilePath(values,size.width,size.height,range.first,range.second);val partial=Path();val measure=PathMeasure();measure.setPath(line,false);measure.getSegment(0f,measure.length*progress.value,partial,true)
    val dashed=sample||metric==ProfileVisualMetric.PUFFINESS
    drawPath(partial,if(metric==ProfileVisualMetric.PUFFINESS)p.primary.copy(alpha=.85f)else color.copy(alpha=if(sample).72f else .92f),style=Stroke((if(sample)1.35f else if(metric==null)1.8f else if(dashed)1.5f else 2.5f).dp.toPx(),cap=StrokeCap.Round,join=StrokeJoin.Round,pathEffect=if(dashed)PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(),4.dp.toPx()))else null))
    if(metric!=null&&metric!=ProfileVisualMetric.VISUAL_INDEX&&metric!=ProfileVisualMetric.PUFFINESS)values.forEachIndexed {i,v->val x=if(values.size==1)size.width/2 else size.width*i/(values.size-1);val y=(size.height*(1-(v-range.first)/max(range.second-range.first,.5))).toFloat();drawCircle(color.copy(alpha=progress.value),3.dp.toPx(),Offset(x,y))}
   }
   if(metric==null)Column(Modifier.width(28.dp).fillMaxHeight(),verticalArrangement=Arrangement.SpaceBetween){listOf("100","50","0").forEach {Text(it,fontSize=11.sp,lineHeight=13.sp,color=p.secondary.copy(alpha=p.secondary.alpha*.72f),letterSpacing=0.sp)}}
  }
  Row(Modifier.fillMaxWidth().padding(end=if(metric==null)36.dp else 0.dp),horizontalArrangement=Arrangement.SpaceBetween){labels.forEach {Text(it,fontSize=(if(metric==null)11 else 10).sp,lineHeight=13.sp,letterSpacing=0.sp,fontWeight=if(metric==null)FontWeight.Normal else FontWeight.SemiBold,color=p.secondary.copy(alpha=p.secondary.alpha*.72f),textAlign=TextAlign.Center)}}
 }
}
