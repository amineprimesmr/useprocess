package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.snapping.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import kotlin.math.*
import java.text.NumberFormat
import java.util.Locale

/** Routine tab shell. Host supplies a real plan day, Health Connect step count, sessions and identity-checked completion. */
@Composable fun ProcessRoutineHome(
    day:RoutineHomeDay?,steps:Int?,onOpenExercise:(RoutineStep)->Unit,
    onStartSession:(String,String?)->Unit,onValidate:(RoutineCompletion)->Unit,onOpenPosture:(RoutinePostureItem)->Unit,
    modifier:Modifier=Modifier,english:Boolean=false,preview:Boolean=false,reduceMotion:Boolean=rememberProcessReducedMotion(),
) {
    val p=ProcessSurfacePalette(isSystemInDarkTheme());var appeared by remember {mutableStateOf(false)}
    LaunchedEffect(Unit){appeared=true}
    val entrance by animateFloatAsState(if(appeared)1f else 0f,if(reduceMotion)snap()else spring(.86f,194.96f),label="routine.title.entrance")
    val latestDay by rememberUpdatedState(day)
    Column(modifier.fillMaxSize().background(p.background).verticalScroll(rememberScrollState()).padding(horizontal=16.dp).padding(top=if(preview)32.dp else 26.dp,bottom=if(preview)28.dp else 102.dp),verticalArrangement=Arrangement.spacedBy(36.dp)) {
        Text(if(english)"Zero Lymph"else"Zéro Lymphe",fontSize=28.sp,lineHeight=34.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.primary,modifier=Modifier.fillMaxWidth().padding(top=6.dp,bottom=2.dp).graphicsLayer {alpha=entrance;translationY=(1f-entrance)*8.dp.toPx()})
        ProcessRoutineStepsBar(steps,english=english)
        if(day==null)Text(if(english)"Your routines will show up here once your plan is ready."else"Tes routines apparaîtront ici une fois ton plan prêt.",fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,color=p.secondary,modifier=Modifier.padding(top=8.dp))
        else key(day.contextKey) {
            Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment=Alignment.CenterVertically) {
                    Text(if(english)"Lymphatic circuit"else"Circuit lymphatique",Modifier.weight(1f),fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=p.primary)
                    if(day.editable)Row(Modifier.clip(CircleShape).background(p.primary).clickable {latestDay?.takeIf {it.contextKey==day.contextKey&&it.editable}?.let {onStartSession(it.contextKey,null)}}.padding(horizontal=12.dp,vertical=6.dp),verticalAlignment=Alignment.CenterVertically) {
                        Text("▶",fontSize=11.sp,color=p.background);Spacer(Modifier.width(6.dp));Text(if(english)"Start"else"Lancer",fontSize=14.sp,lineHeight=18.sp,fontWeight=FontWeight.Bold,color=p.background)
                    }
                }
                val list=rememberLazyListState()
                LazyRow(state=list,flingBehavior=rememberSnapFlingBehavior(list,snapPosition=SnapPosition.Start),horizontalArrangement=Arrangement.spacedBy(12.dp),contentPadding=PaddingValues(vertical=8.dp),modifier=Modifier.fillMaxWidth().height(288.dp)) {
                    itemsIndexed(ProcessRoutineCatalog.steps,key={_,s->s.id}) {index,step->
                        val context=LocalContext.current
                        val image=remember(step.imageResource){context.resources.getIdentifier(step.imageResource,"drawable",context.packageName)}
                        ProcessRoutineHoldCard(step.title(english),step.id in day.completedStepIds,day.editable,{onOpenExercise(step)},{latestDay?.takeIf {it.contextKey==day.contextKey&&it.editable&&step.id !in it.completedStepIds}?.let {onValidate(RoutineCompletion(it.contextKey,step.id))}},Modifier.graphicsLayer {
                            val info=list.layoutInfo.visibleItemsInfo.firstOrNull {it.index==index}
                            val fraction=if(info==null)0f else ((max(0,-info.offset)+max(0,info.offset+info.size-list.layoutInfo.viewportEndOffset)).toFloat()/info.size).coerceIn(0f,1f)
                            scaleX=1f-.08f*fraction;scaleY=scaleX;alpha=1f-.24f*fraction
                        },english,reduceMotion) {RoutinePreviewCard(step.title(english),step.durationLabel,image.takeIf {it!=0},p)}
                    }
                }
            }
            Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
                Text(if(english)"Posture circuit"else"Circuit posture",fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=p.primary)
                val list=rememberLazyListState()
                LazyRow(state=list,flingBehavior=rememberSnapFlingBehavior(list,snapPosition=SnapPosition.Start),horizontalArrangement=Arrangement.spacedBy(12.dp),contentPadding=PaddingValues(vertical=8.dp),modifier=Modifier.fillMaxWidth().height(288.dp)) {
                    items(day.postureItems.take(4),key={it.id}) {item->Box(Modifier.clickable(role=Role.Button){onOpenPosture(item)}) {RoutinePreviewCard(item.title,item.badge,item.imageResource,p)}}
                }
            }
        }
    }
}

@Composable private fun RoutinePreviewCard(title:String,badge:String?,image:Int?,p:ProcessSurfacePalette) {
    val shape=RoundedCornerShape(22.dp)
    Box(Modifier.size(156.dp,272.dp).shadow(9.dp,shape,ambientColor=Color.Black.copy(alpha=if(p.dark).34f else .11f),spotColor=Color.Black.copy(alpha=if(p.dark).34f else .11f)).clip(shape).background(p.accent.copy(alpha=.22f))) {
        if(image!=null)Image(painterResource(image),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop,alignment=Alignment.TopCenter)
        else Text("✦",fontSize=32.sp,color=p.accent,modifier=Modifier.align(Alignment.Center))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Black.copy(alpha=.06f),Color.Transparent,Color.Black.copy(alpha=.35f),Color.Black.copy(alpha=.88f)))))
        if(badge!=null)Text(badge,fontSize=11.sp,lineHeight=14.sp,letterSpacing=0.sp,fontWeight=FontWeight.Bold,color=Color.White.copy(alpha=.96f),modifier=Modifier.align(Alignment.TopEnd).padding(10.dp).background(Color.Black.copy(alpha=.45f),CircleShape).border(.5.dp,Color.White.copy(alpha=.12f),CircleShape).padding(horizontal=8.dp,vertical=4.dp))
        Text(title,fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,fontWeight=FontWeight.SemiBold,color=Color.White,maxLines=2,modifier=Modifier.align(Alignment.BottomStart).padding(horizontal=12.dp).padding(bottom=14.dp))
        Box(Modifier.fillMaxSize().border(.5.dp,Color.White.copy(alpha=if(p.dark).14f else .22f),shape))
    }
}

@Composable fun ProcessRoutineStepsBar(steps:Int?,modifier:Modifier=Modifier,english:Boolean=false) {
    val p=ProcessSurfacePalette(isSystemInDarkTheme());val percent=RoutineStepProgress.percent(steps)
    val color=when(percent?:0){in 75..100->Color(.30f,.80f,.42f);in 60..74->Color(.95f,.80f,.20f);in 40..59->Color(.96f,.58f,.20f);else->Color(.93f,.30f,.28f)}
    val format=remember(english){NumberFormat.getIntegerInstance(if(english)Locale.US else Locale.FRANCE)}
    val label=if(steps==null){if(english)"Step count unavailable"else"Nombre de pas indisponible"}else if(english)"${format.format(steps.coerceAtLeast(0))} steps of 10,000, $percent percent"else"${format.format(steps.coerceAtLeast(0))} pas sur 10 000, $percent pour cent"
    Row(modifier.fillMaxWidth().height(52.dp).background(if(p.dark)Color(0xff2e3037)else Color(.94f,.94f,.95f),RoundedCornerShape(18.dp)).padding(horizontal=16.dp).clearAndSetSemantics {contentDescription=label},verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
        Canvas(Modifier.size(20.dp)) {
            rotate(-20f,pivot=Offset(size.width*.35f,size.height*.35f)){drawOval(color,Offset(3.dp.toPx(),1.dp.toPx()),Size(5.dp.toPx(),10.dp.toPx()));drawOval(color,Offset(3.dp.toPx(),13.dp.toPx()),Size(4.dp.toPx(),4.dp.toPx()))}
            rotate(20f,pivot=Offset(size.width*.75f,size.height*.6f)){drawOval(color,Offset(12.dp.toPx(),5.dp.toPx()),Size(5.dp.toPx(),10.dp.toPx()));drawOval(color,Offset(12.dp.toPx(),17.dp.toPx()),Size(4.dp.toPx(),3.dp.toPx()))}
        }
        Canvas(Modifier.weight(1f).height(14.dp)) {
            val w=2.75.dp.toPx();val count=max(8,((size.width+w)/(2*w)).toInt());val gap=(size.width-count*w)/(count-1);val filled=RoutineStepProgress.filledTicks(percent,count)
            repeat(count){i->drawRoundRect(if(i<filled)color else if(p.dark)Color(0xff3b3c43)else Color.Black.copy(alpha=.12f),Offset(i*(w+gap),0f),Size(w,size.height),CornerRadius(w/2))}
        }
        Text(percent?.let {"$it%"}?:"—",fontSize=15.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,color=p.primary,modifier=Modifier.widthIn(min=36.dp),textAlign=androidx.compose.ui.text.style.TextAlign.End)
    }
}
