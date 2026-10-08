package com.process.android

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

data class RecipeDraft(val contextKey:String,val meal:ProcessRecipe)

/** Host owns identity-checked persistence and nutrition estimates. Null draft context never emits a write event. */
@Composable fun ProcessRecipeDetail(
    initialMeal:ProcessRecipe,onClose:()->Unit,modifier:Modifier=Modifier,alternatives:List<ProcessRecipe> = emptyList(),
    editable:Boolean=false,draftContext:String?=null,onDraftChanged:(RecipeDraft)->Unit={},
    assessmentFor:(ProcessRecipe)->RecipeAssessment?={null},english:Boolean=false,reduceMotion:Boolean=rememberProcessReducedMotion(),
) {
    key(draftContext,initialMeal.id) {
        var meal by remember {mutableStateOf(initialMeal)}
        var edited by remember {mutableStateOf(false)}
        var closeFlushed by remember {mutableStateOf(false)}
        val latestMeal by rememberUpdatedState(meal);val latestDraft by rememberUpdatedState(onDraftChanged)
        val latestEditable by rememberUpdatedState(editable)
        fun flush() {if(latestEditable&&draftContext!=null)latestDraft(RecipeDraft(draftContext,latestMeal))}
        DisposableEffect(draftContext) {onDispose {if(!closeFlushed)flush()}}
        LaunchedEffect(meal.id,editable) {if(edited&&editable&&draftContext!=null){delay(350);flush()}}
        val pool=remember(initialMeal.id,alternatives) {(if(alternatives.none {it.id==initialMeal.id})listOf(initialMeal)+alternatives else alternatives).distinctBy {it.id}}
        val canChange=editable&&pool.size>1
        val haptic=LocalHapticFeedback.current;val palette=ProcessSurfacePalette(isSystemInDarkTheme())
        Box(modifier.fillMaxSize().background(palette.background)) {
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.fillMaxWidth().height(44.dp),verticalAlignment=Alignment.CenterVertically) {
                    TextButton(onClick={flush();closeFlushed=true;onClose()}) {Text(if(english)"Close"else"Fermer",color=palette.primary,fontSize=17.sp,lineHeight=22.sp,letterSpacing=0.sp)}
                }
                Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal=20.dp).padding(top=8.dp,bottom=if(canChange)96.dp else 32.dp)) {
                    Crossfade(meal,animationSpec=if(reduceMotion)tween(0)else spring(.86f,223.8f),label="recipe.replacement") {displayed ->
                        val assessment=assessmentFor(displayed)
                        Column(Modifier.fillMaxWidth(),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(22.dp)) {
                            Box(Modifier.padding(top=4.dp).size(152.dp),contentAlignment=Alignment.BottomCenter) {
                                Image(painterResource(displayed.imageResource),displayed.name.text(english),Modifier.fillMaxSize(),contentScale=ContentScale.Fit)
                                assessment?.let {RecipeScorePill(it,palette,Modifier.offset(y=10.dp))}
                            }
                            Text(displayed.name.text(english),fontSize=26.sp,lineHeight=31.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=palette.primary,textAlign=TextAlign.Center,modifier=Modifier.padding(horizontal=4.dp))
                            if(displayed.summary.text(english).isNotBlank())Text(displayed.summary.text(english),fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,color=palette.secondary,textAlign=TextAlign.Center,modifier=Modifier.padding(horizontal=8.dp))
                            if(assessment!=null)RecipeScoreCard(assessment,palette,english,reduceMotion)
                            else Text(if(english)"Nutrition estimate unavailable"else"Estimation nutritionnelle indisponible",fontSize=12.sp,lineHeight=16.sp,color=palette.secondary)
                            RecipeSurface(palette,12) {
                                Text(if(english)"Ingredients"else"Ingrédients",fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=palette.secondary)
                                Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {displayed.foodIngredients.forEach {item ->
                                    Row(Modifier.fillMaxWidth().background(palette.card.copy(alpha=palette.card.alpha*.45f),RoundedCornerShape(12.dp)).padding(horizontal=12.dp,vertical=10.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                                        RecipeIngredientIcon(item.role,palette.accent,Modifier.size(22.dp))
                                        Text(item.displayLine(english),Modifier.weight(1f),fontSize=15.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=palette.primary)
                                    }
                                }}
                            }
                            RecipeSurface(palette) {
                                Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                                    Text(if(english)"Preparation"else"Préparation",fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=palette.secondary,modifier=Modifier.weight(1f))
                                    if(displayed.preparationMinutes>0)Text("~${displayed.preparationMinutes} min",fontSize=12.sp,lineHeight=16.sp,color=palette.secondary,modifier=Modifier.background(palette.card.copy(alpha=palette.card.alpha*.55f),CircleShape).padding(horizontal=10.dp,vertical=5.dp))
                                }
                                val steps=remember(displayed.preparation,english){RecipePreparation.steps(displayed.preparation.text(english))}
                                if(steps.isEmpty())Text(if(english)"No preparation steps for this meal."else"Aucune étape de préparation pour ce repas.",fontSize=15.sp,lineHeight=20.sp,color=palette.primary)
                                else Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {steps.forEachIndexed {index,text ->
                                    Row(Modifier.fillMaxWidth().background(palette.card.copy(alpha=palette.card.alpha*.45f),RoundedCornerShape(14.dp)).padding(12.dp),horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                                        Box(Modifier.size(28.dp).background(palette.primary,CircleShape),contentAlignment=Alignment.Center) {Text("${index+1}",color=if(palette.dark)Color.Black else Color.White,fontSize=15.sp,lineHeight=20.sp,fontWeight=FontWeight.Bold)}
                                        Text(text,Modifier.weight(1f),fontSize=15.sp,fontWeight=FontWeight.Medium,lineHeight=20.sp,letterSpacing=0.sp,color=palette.primary)
                                    }
                                }}
                                if(displayed.tip.text(english).isNotBlank())Row(Modifier.fillMaxWidth().background(palette.accent.copy(alpha=if(palette.dark).14f else .10f),RoundedCornerShape(14.dp)).padding(12.dp),horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                                    Text("✦",color=palette.accent,fontSize=13.sp)
                                    Text(displayed.tip.text(english),fontSize=15.sp,lineHeight=20.sp,letterSpacing=0.sp,color=palette.primary.copy(alpha=.92f))
                                }
                            }
                        }
                    }
                }
            }
            if(canChange)Button(onClick={haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove);val i=pool.indexOfFirst {it.id==meal.id}.coerceAtLeast(0);edited=true;meal=pool[(i+1)%pool.size]},modifier=Modifier.align(Alignment.BottomCenter).padding(horizontal=20.dp).padding(bottom=12.dp).fillMaxWidth().height(52.dp).shadow(18.dp,CircleShape),shape=CircleShape,colors=ButtonDefaults.buttonColors(containerColor=if(palette.dark)Color(.20f,.21f,.24f,.94f)else Color.White.copy(alpha=.94f),contentColor=palette.primary.copy(alpha=.92f))) {
                Text("↻",fontSize=20.sp);Spacer(Modifier.width(10.dp));Text(if(english)"Change meal"else"Changez de repas",fontSize=16.sp,lineHeight=21.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp)
            }
        }
    }
}
@Composable private fun RecipeSurface(p:ProcessSurfacePalette,spacing:Int=14,content:@Composable ColumnScope.()->Unit) {
    Column(Modifier.fillMaxWidth().shadow(10.dp,RoundedCornerShape(20.dp),ambientColor=p.primary.copy(alpha=if(p.dark).12f else .04f),spotColor=p.primary.copy(alpha=if(p.dark).12f else .04f)).background(p.recipeCard,RoundedCornerShape(20.dp)).then(if(p.dark)Modifier else Modifier.border(.5.dp,p.stroke,RoundedCornerShape(20.dp))).padding(16.dp),verticalArrangement=Arrangement.spacedBy(spacing.dp),content=content)
}
@Composable private fun RecipeIngredientIcon(role:String,color:Color,modifier:Modifier) {
    Canvas(modifier.padding(4.dp)) {
        val r=role.lowercase();val w=size.width;val h=size.height
        val path=Path()
        when {
            r.contains("prot") -> {path.moveTo(w*.55f,0f);path.lineTo(w*.12f,h*.58f);path.lineTo(w*.45f,h*.58f);path.lineTo(w*.35f,h);path.lineTo(w*.9f,h*.38f);path.lineTo(w*.58f,h*.38f);path.close();drawPath(path,color)}
            r.contains("gras")||r.contains("gluc") -> {path.moveTo(w*.5f,0f);path.cubicTo(w*.5f,h*.3f,w,h*.45f,w*.85f,h*.75f);path.cubicTo(w*.7f,h*1.08f,w*.1f,h,w*.14f,h*.62f);path.close();drawPath(path,color)}
            r.contains("gume") -> {path.moveTo(0f,h);path.cubicTo(0f,0f,w,0f,w,0f);path.cubicTo(w,h,w*.3f,h,0f,h);path.close();drawPath(path,color)}
            else ->drawCircle(color,radius=size.minDimension*.3f)
        }
    }
}
