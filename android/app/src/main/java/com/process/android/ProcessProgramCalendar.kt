package com.process.android

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.*
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.abs

/** The host supplies real plan/trajectory/scan state. No fabricated daily results or cloud writes. */
@Composable fun ProcessProgramCalendar(
    plan:ProgramCalendarPlan?, records:List<CalendarDayRecord>, scans:List<CalendarScan>,
    displayStreak:Int, onClose:()->Unit, modifier:Modifier=Modifier,
    today:LocalDate=LocalDate.now(), zone:ZoneId=ZoneId.systemDefault(),
    english:Boolean=false, dark:Boolean=isSystemInDarkTheme(),
    onDaySelected:(LocalDate)->Unit={}
) {
    val palette=InputPalette(dark);val locale=if(english)Locale.ENGLISH else Locale.FRENCH
    val initial=plan?.let {ProgramCalendarModel.preferredToday(today,it)}?:today
    var selectedText by rememberSaveable(plan?.startedOn?.toString()) {mutableStateOf(initial.toString())}
    var monthText by rememberSaveable(plan?.startedOn?.toString()) {mutableStateOf(YearMonth.from(initial).toString())}
    val selected=LocalDate.parse(selectedText);val month=YearMonth.parse(monthText)
    val haptics=LocalHapticFeedback.current
    fun select(date:LocalDate) {selectedText=date.toString();monthText=YearMonth.from(date).toString();onDaySelected(date);haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}
    fun shift(delta:Int) {if(plan!=null&&ProgramCalendarModel.canShift(month,delta,plan))monthText=month.plusMonths(delta.toLong()).toString()}
    BackHandler(onBack=onClose)
    Column(modifier.fillMaxSize().background(palette.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal=16.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(palette.primary.copy(alpha=.06f)).clickable(onClick=onClose).semantics {contentDescription=if(english)"Close calendar" else "Fermer le calendrier";role=Role.Button},contentAlignment=Alignment.Center) {Text("×",fontSize=24.sp,color=palette.primary)}
            Spacer(Modifier.weight(1f))
            if(selected!=today)TextButton(onClick={select(today)}) {Text(if(english)"Today" else "Aujourd’hui",color=CalendarBlue)}
        }
        if(plan==null||plan.days.isEmpty()) {
            Column(Modifier.fillMaxSize().padding(30.dp),verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally) {
                CalendarGridIcon(Modifier.size(44.dp),palette.muted)
                Spacer(Modifier.height(18.dp))
                Text(if(english)"No active plan" else "Aucun programme actif",fontWeight=FontWeight.Bold,fontSize=21.sp,color=palette.primary)
                Spacer(Modifier.height(10.dp))
                Text(if(english)"Finish setting up your program to see your calendar." else "Termine la création de ton programme pour voir ton calendrier.",color=palette.muted)
            }
        } else {
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal=16.dp).padding(top=4.dp,bottom=24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
                Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                    Text(month.month.getDisplayName(TextStyle.FULL,locale).replaceFirstChar {it.titlecase(locale)}+".",fontSize=34.sp,fontWeight=FontWeight.Bold,color=palette.primary)
                    Text(if(english)"Tap any day to see that scan." else "Appuie sur un jour pour voir ce scan.",fontSize=14.sp,color=palette.muted)
                    Row(Modifier.fillMaxWidth().padding(top=8.dp),horizontalArrangement=Arrangement.SpaceBetween) {
                        Text(if(english)"YOUR PROGRESS" else "TA PROGRESSION",fontSize=11.sp,fontWeight=FontWeight.SemiBold,color=palette.muted)
                        val count=ProgramCalendarModel.scansInMonth(month,scans,zone)
                        Text("$count scan${if(count==1)"" else "s"}",fontSize=11.sp,fontWeight=FontWeight.Bold,color=CalendarBlue)
                    }
                }
                var drag by remember {mutableFloatStateOf(0f)}
                val density=androidx.compose.ui.platform.LocalDensity.current.density
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(if(dark)Color.White.copy(alpha=.09f) else Color.White)
                    .semantics {
                        customActions=listOf(
                            CustomAccessibilityAction(if(english)"Previous month" else "Mois précédent") {if(ProgramCalendarModel.canShift(month,-1,plan)){shift(-1);true}else false},
                            CustomAccessibilityAction(if(english)"Next month" else "Mois suivant") {if(ProgramCalendarModel.canShift(month,1,plan)){shift(1);true}else false}
                        )
                    }
                    .pointerInput(month,plan) {detectHorizontalDragGestures(onDragStart={drag=0f},onHorizontalDrag={change,amount->drag+=amount/density;change.consume()},onDragEnd={if(abs(drag)>40)shift(if(drag<0)1 else -1)},onDragCancel={drag=0f})}
                    .padding(horizontal=18.dp,vertical=20.dp),verticalArrangement=Arrangement.spacedBy(18.dp)) {
                    Row(verticalAlignment=Alignment.CenterVertically) {
                        CalendarGridIcon(Modifier.size(14.dp),palette.primary);Spacer(Modifier.width(8.dp))
                        Text((if(english)"Scans & Journal — " else "Scans & Journal — ")+month.month.getDisplayName(TextStyle.FULL,locale),fontSize=15.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,modifier=Modifier.weight(1f))
                        Box(Modifier.size(28.dp).clip(CircleShape).clickable(enabled=ProgramCalendarModel.canShift(month,1,plan),onClick={shift(1)}).semantics {contentDescription=if(english)"Next month" else "Mois suivant";role=Role.Button},contentAlignment=Alignment.Center) {Text("⌄",color=palette.muted)}
                    }
                    Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                        (1..7).forEach {n->Box(Modifier.weight(1f),contentAlignment=Alignment.Center) {Text(DayOfWeek.of(n).getDisplayName(TextStyle.NARROW_STANDALONE,locale).uppercase(locale),fontSize=12.sp,fontWeight=FontWeight.SemiBold,color=palette.muted)}}
                    }
                    Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                        ProgramCalendarModel.grid(month).chunked(7).forEach {week->
                            Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {week.forEach {date->
                                val model=ProgramCalendarModel.day(date,today,plan,records,scans,zone)
                                Box(Modifier.weight(1f),contentAlignment=Alignment.Center) {
                                    CalendarDayCell(model,YearMonth.from(date)==month,date==selected,palette,locale,english) {select(date)}
                                }
                            }}
                        }
                    }

                }
                val day=ProgramCalendarModel.day(selected,today,plan,records,scans,zone)
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha=if(dark).08f else .88f)).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
                    Text(day.number?.let {if(english)"Day $it of the program" else "Jour $it du programme"}?:selected.format(DateTimeFormatter.ofPattern(if(english)"EEEE, MMMM d" else "EEEE d MMMM",locale)),fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
                    val dateLabel=selected.format(DateTimeFormatter.ofPattern(if(english)"MMMM d, yyyy" else "d MMMM yyyy",locale))
                    Text(listOfNotNull(dateLabel,day.programDay?.phaseTitle?.takeIf {it.isNotBlank()},day.programDay?.title?.takeIf {it.isNotBlank()}).joinToString(" · "),fontSize=13.sp,color=palette.muted)
                    val tint=calendarStatusColor(day)
                    Text(calendarStatusLabel(day,english),modifier=Modifier.clip(RoundedCornerShape(50)).background(tint.copy(alpha=.14f)).padding(horizontal=10.dp,vertical=6.dp),color=tint,fontSize=12.sp,fontWeight=FontWeight.SemiBold)
                }
            }
            Row(Modifier.fillMaxWidth().background(palette.background.copy(alpha=.96f)).padding(start=16.dp,end=16.dp,top=10.dp,bottom=12.dp),horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                val best=ProgramCalendarModel.bestDay(records)?.format(DateTimeFormatter.ofPattern("MMM d",locale))?:"—"
                listOf(Triple("STREAK","${displayStreak.coerceAtLeast(0)}${if(english)"d" else "j"}",false),Triple(if(english)"BEST DAY" else "MEILLEUR JOUR",best,false),Triple(if(english)"SKIPPED" else "MANQUÉS",ProgramCalendarModel.missedDays(records).toString(),true)).forEach {(label,value,blue)->
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(18.dp)).background(if(blue)CalendarBlue else if(dark)Color.White.copy(alpha=.08f) else Color.White).padding(14.dp),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                        Text(value,fontSize=22.sp,fontWeight=FontWeight.Bold,color=if(blue)Color.White else palette.primary,maxLines=1)
                        Text(label,fontSize=10.sp,fontWeight=FontWeight.SemiBold,color=if(blue)Color.White.copy(alpha=.8f) else palette.muted)
                    }
                }
            }
        }
    }
}

private val CalendarBlue=Color(.15f,.47f,.99f)
@Composable private fun CalendarDayCell(day:ProgramCalendarDayModel,inMonth:Boolean,selected:Boolean,palette:InputPalette,locale:Locale,english:Boolean,onClick:()->Unit) {
    val image=rememberCalendarThumbnail(day.scan?.thumbnailUri)
    val fill=if(!inMonth)palette.primary.copy(alpha=if(palette.dark).03f else .025f) else if(selected)Color.White.copy(alpha=if(palette.dark).10f else 1f) else palette.primary.copy(alpha=if(palette.dark).07f else .045f)
    Box(Modifier.size(40.dp).clip(CircleShape).background(fill).then(if(selected)Modifier.border(2.dp,CalendarBlue,CircleShape) else Modifier).clickable(onClick=onClick).semantics(mergeDescendants=true) {
        role=Role.Button;this.selected=selected;contentDescription=day.date.format(DateTimeFormatter.ofPattern("EEEE d MMMM yyyy",locale))+", "+calendarStatusLabel(day,english)
    },contentAlignment=Alignment.Center) {
        if(image!=null)Image(image,contentDescription=null,contentScale=ContentScale.Crop,modifier=Modifier.fillMaxSize().graphicsLayer {
            val scan=day.scan;scaleX=scan?.scale?.coerceIn(1f,8f)?:1f;scaleY=scaleX
            translationX=(scan?.offsetX?:0f)*size.width;translationY=(scan?.offsetY?:0f)*size.height;alpha=if(inMonth)1f else .42f
        })
        else Text(day.date.dayOfMonth.toString(),fontSize=14.sp,fontWeight=FontWeight.SemiBold,color=palette.primary.copy(alpha=if(inMonth)1f else .28f),modifier=Modifier.clearAndSetSemantics {})
    }
}

/** Local cached thumbnails only; never downloads or discloses a scan URI. */
@Composable private fun rememberCalendarThumbnail(value:String?):ImageBitmap? {
    val context=LocalContext.current
    val image by produceState<ImageBitmap?>(null,value) {
        this.value=null
        this.value=withContext(Dispatchers.IO) {
            if(value.isNullOrBlank())return@withContext null
            val uri=Uri.parse(value)
            if(uri.scheme !in listOf("content","file",null))return@withContext null
            runCatching {
                fun stream()=if(uri.scheme==null)java.io.File(value).inputStream() else context.contentResolver.openInputStream(uri)
                val options=BitmapFactory.Options().apply {inJustDecodeBounds=true}
                stream()?.use {BitmapFactory.decodeStream(it,null,options)}
                var sample=1
                while(options.outWidth/sample>256&&options.outHeight/sample>256)sample*=2
                options.inJustDecodeBounds=false;options.inSampleSize=sample
                stream()?.use {BitmapFactory.decodeStream(it,null,options)}?.asImageBitmap()
            }.getOrNull()
        }
    }
    return image
}
@Composable private fun CalendarGridIcon(modifier:Modifier,color:Color) {
    Canvas(modifier) {
        val stroke=androidx.compose.ui.graphics.drawscope.Stroke(size.width*.08f)
        drawRoundRect(color,topLeft=androidx.compose.ui.geometry.Offset(size.width*.08f,size.height*.18f),size=androidx.compose.ui.geometry.Size(size.width*.84f,size.height*.75f),cornerRadius=androidx.compose.ui.geometry.CornerRadius(size.width*.12f),style=stroke)
        drawLine(color,androidx.compose.ui.geometry.Offset(size.width*.08f,size.height*.4f),androidx.compose.ui.geometry.Offset(size.width*.92f,size.height*.4f),size.width*.08f)
        for(x in listOf(.32f,.68f))drawLine(color,androidx.compose.ui.geometry.Offset(size.width*x,0f),androidx.compose.ui.geometry.Offset(size.width*x,size.height*.3f),size.width*.08f)
        for(x in listOf(.3f,.5f,.7f))for(y in listOf(.58f,.76f))drawCircle(color,size.width*.04f,androidx.compose.ui.geometry.Offset(size.width*x,size.height*y))
    }
}
private fun calendarStatusLabel(day:ProgramCalendarDayModel,english:Boolean):String=when(day.status) {
    CalendarDayStatus.OUTSIDE_PLAN->if(english)"Outside plan" else "Hors plan"
    CalendarDayStatus.FUTURE->if(english)"Upcoming" else "À venir"
    CalendarDayStatus.TODAY->if(english)"Today" else "Aujourd’hui"
    CalendarDayStatus.PARTIAL->if(english)"Partial" else "Partiel"
    CalendarDayStatus.MISSED->if(english)"Missed" else "Manqué"
    CalendarDayStatus.VALIDATED->when(day.record?.verdict) {
        CalendarDayVerdict.EXCELLENT->"Excellent"
        CalendarDayVerdict.ON_TRACK->if(english)"On track" else "Sur la bonne voie"
        CalendarDayVerdict.PARTIAL->if(english)"Partial" else "Partiel"
        CalendarDayVerdict.REGRESSION->if(english)"Regression" else "Régression"
        CalendarDayVerdict.MISSED->if(english)"Missed" else "Manqué"
        CalendarDayVerdict.PAUSED->if(english)"Paused" else "Pause"
        else->if(english)"Pending" else "En attente"
    }
}
private fun calendarStatusColor(day:ProgramCalendarDayModel):Color=when(day.status) {
    CalendarDayStatus.OUTSIDE_PLAN->Color.Gray
    CalendarDayStatus.FUTURE->Color(.42f,.58f,.95f)
    CalendarDayStatus.TODAY->Color(.35f,.55f,.95f)
    CalendarDayStatus.PARTIAL->Color(1f,.72f,.28f)
    CalendarDayStatus.MISSED->Color(.92f,.38f,.38f)
    CalendarDayStatus.VALIDATED->when(day.record?.verdict) {
        CalendarDayVerdict.EXCELLENT->Color(.35f,.78f,.45f)
        CalendarDayVerdict.ON_TRACK->Color(.45f,.82f,.62f)
        CalendarDayVerdict.PARTIAL->Color(1f,.72f,.28f)
        CalendarDayVerdict.REGRESSION->Color(.92f,.38f,.38f)
        CalendarDayVerdict.MISSED->Color(.55f,.55f,.58f)
        CalendarDayVerdict.PAUSED->Color(.42f,.58f,.95f)
        else->Color(.55f,.58f,.65f)
    }
}
