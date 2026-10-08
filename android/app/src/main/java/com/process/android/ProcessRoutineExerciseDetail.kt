package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable fun ProcessRoutineExerciseDetail(
    step:RoutineStep,onClose:()->Unit,modifier:Modifier=Modifier,
    english:Boolean=false,sessionActionTitle:String?=null,onOpenSession:(()->Unit)?=null,
    reduceMotion:Boolean=rememberProcessReducedMotion(),
) {
    val dark=isSystemInDarkTheme();val ink=if(dark)Color.White else Color.Black
    val background=if(dark)Color(.07f,.08f,.11f) else Color(.968f,.972f,.988f)
    val accent=Color(.655f,.769f,.949f)
    val card=ink.copy(alpha=if(dark).06f else .07f)
    val stroke=ink.copy(alpha=if(dark).10f else .12f)
    val hasCTA=sessionActionTitle!=null&&onOpenSession!=null
    fun label(pair:Pair<String,String>)=if(english)pair.second else pair.first
    Box(modifier.fillMaxSize().background(background)) {
        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().height(50.dp).padding(end=20.dp),horizontalArrangement=Arrangement.End,verticalAlignment=Alignment.CenterVertically) {
                CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
                IconButton(onClick=onClose,modifier=Modifier.size(34.dp).background(ink.copy(alpha=if(dark).1f else .06f),CircleShape)) {Icon(Icons.Default.Close,if(english)"Close"else"Fermer",Modifier.size(14.dp),tint=ink.copy(alpha=.85f))}
                }
            }
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal=20.dp).padding(top=8.dp,bottom=if(hasCTA)108.dp else 32.dp),verticalArrangement=Arrangement.spacedBy(28.dp)) {
                val hero=RoundedCornerShape(24.dp)
                Box(Modifier.fillMaxWidth().aspectRatio(3f/4f).shadow(16.dp,hero,ambientColor=Color.Black.copy(alpha=if(dark).35f else .12f),spotColor=Color.Black.copy(alpha=if(dark).35f else .12f)).clip(hero).border(.5.dp,Color.White.copy(alpha=if(dark).12f else .08f),hero)) {
                    ProcessRoutineMedia(step,english,Modifier.fillMaxSize(),reduceMotion)
                    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color.Transparent,.5f to Color.Transparent,.75f to Color.Black.copy(alpha=.35f),1f to Color.Black.copy(alpha=.82f))))
                    Column(Modifier.align(Alignment.BottomStart).padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
                        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                            Text((if(english)"Exercise "else"Exercice ")+"${step.number}/${ProcessRoutineCatalog.steps.size}",fontSize=12.sp,fontWeight=FontWeight.Bold,color=Color.White.copy(alpha=.92f),modifier=Modifier.background(Color.White.copy(alpha=.18f),CircleShape).padding(horizontal=10.dp,vertical=5.dp))
                            Text("◷ ${step.durationLabel}",fontSize=12.sp,fontWeight=FontWeight.Bold,color=Color.White.copy(alpha=.92f),modifier=Modifier.background(Color.Black.copy(alpha=.38f),CircleShape).padding(horizontal=10.dp,vertical=5.dp))
                        }
                        Text(step.title(english),fontSize=26.sp,fontWeight=FontWeight.Bold,color=Color.White)
                    }
                }
                Column(verticalArrangement=Arrangement.spacedBy(14.dp)) {
                    Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(8.dp)) {Icon(Icons.Default.PlayArrow,null,Modifier.size(17.dp),tint=accent);Text(if(english)"The movement"else"Le mouvement",fontSize=17.sp,fontWeight=FontWeight.Bold,color=ink)}
                    Column(Modifier.fillMaxWidth().background(card,RoundedCornerShape(18.dp)).border(.5.dp,stroke,RoundedCornerShape(18.dp))) {
                        step.instructions.forEachIndexed {index,line ->
                            Row(Modifier.fillMaxWidth().padding(horizontal=16.dp,vertical=14.dp),horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.Top) {
                                Box(Modifier.size(26.dp).background(accent.copy(alpha=.14f),CircleShape),contentAlignment=Alignment.Center) {Text("${index+1}",fontSize=12.sp,fontWeight=FontWeight.Bold,color=accent)}
                                Text(label(line),fontSize=15.sp,color=ink,modifier=Modifier.weight(1f).padding(top=3.dp))
                            }
                            if(index<step.instructions.lastIndex)HorizontalDivider(Modifier.padding(start=56.dp),color=ink.copy(alpha=if(dark).22f else .45f),thickness=.5.dp)
                        }
                    }
                }
                Column(verticalArrangement=Arrangement.spacedBy(14.dp)) {
                    Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(8.dp)) {Icon(Icons.Default.Star,null,Modifier.size(17.dp),tint=accent);Text(if(english)"Benefits"else"Bénéfices",fontSize=17.sp,fontWeight=FontWeight.Bold,color=ink)}
                    Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                        step.benefits.forEach {benefit ->
                            Row(Modifier.fillMaxWidth().background(card,RoundedCornerShape(18.dp)).border(.5.dp,stroke,RoundedCornerShape(18.dp)).padding(horizontal=16.dp,vertical=13.dp),horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                                Icon(Icons.Default.CheckCircle,null,Modifier.size(18.dp).padding(top=1.dp),tint=accent)
                                Text(label(benefit),fontSize=15.sp,color=ink,modifier=Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }
        if(hasCTA)Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth()) {
            Box(Modifier.fillMaxWidth().height(28.dp).background(Brush.verticalGradient(listOf(background.copy(alpha=0f),background.copy(alpha=.92f),background))))
            Box(Modifier.fillMaxWidth().background(background).padding(horizontal=20.dp).padding(bottom=16.dp)) {
                Button(onClick={onOpenSession?.invoke()},modifier=Modifier.fillMaxWidth().height(54.dp),shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=ink,contentColor=if(dark)Color.Black else Color.White),border=BorderStroke(.5.dp,ink.copy(alpha=.12f))) {
                    Icon(Icons.Default.PlayArrow,null,Modifier.size(16.dp));Spacer(Modifier.width(10.dp));Text(sessionActionTitle.orEmpty(),fontSize=17.sp,fontWeight=FontWeight.Bold)
                }
            }
        }
    }
}
