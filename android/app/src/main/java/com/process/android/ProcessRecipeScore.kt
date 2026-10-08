package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun scoreColor(score:Int)=when(score){in 88..100->Color(.25f,.78f,.52f);in 76..87->Color(.42f,.72f,.95f);in 64..75->Color(.95f,.72f,.24f);else->Color(.96f,.47f,.30f)}
private fun barColor(score:Int)=when(score){in 75..100->Color(.30f,.80f,.42f);in 60..74->Color(.95f,.80f,.20f);in 40..59->Color(.96f,.58f,.20f);else->Color(.93f,.30f,.28f)}
@Composable internal fun RecipeScorePill(a:RecipeAssessment,p:ProcessSurfacePalette,modifier:Modifier=Modifier) {
    Row(modifier.background(if(p.dark)Color(.17f,.18f,.21f,.9f)else Color.White.copy(alpha=.9f),CircleShape).border(.5.dp,p.stroke,CircleShape).padding(horizontal=12.dp,vertical=7.dp).semantics {contentDescription="${if(a.estimated)"≈"else""}${a.score}/100 Debloat"},verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(6.dp)) {
        Text("●",color=scoreColor(a.score),fontSize=10.sp)
        Text("${if(a.estimated)"≈"else""}${a.score}",color=p.primary,fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.ExtraBold)
        Text("Debloat",color=p.primary.copy(alpha=.72f),fontSize=11.sp,lineHeight=14.sp,fontWeight=FontWeight.SemiBold)
    }
}
@Composable internal fun RecipeScoreCard(a:RecipeAssessment,p:ProcessSurfacePalette,english:Boolean,reduceMotion:Boolean) {
    Column(Modifier.fillMaxWidth().background(p.strongCard,RoundedCornerShape(20.dp)).border(.5.dp,p.stroke,RoundedCornerShape(20.dp)).padding(16.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(13.dp)) {
            RecipeScorePill(a,p)
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                Text(a.label.text(english),fontSize=17.sp,lineHeight=22.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp,color=p.primary)
                Text(a.summary.text(english),fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=p.secondary)
            }
        }
        Column(verticalArrangement=Arrangement.spacedBy(11.dp)) {
            listOf((if(english)"Fluid balance"else"Équilibre hydrique") to a.fluidBalance,(if(english)"Digestive comfort"else"Confort digestif") to a.digestiveComfort,(if(english)"Nutritional quality"else"Qualité nutritionnelle") to a.foodQuality).forEach {(title,value)->
                val fraction by animateFloatAsState(value/100f,if(reduceMotion)snap()else tween(300,easing=CubicBezierEasing(.42f,0f,.58f,1f)),label="recipe.score.$title")
                Column(verticalArrangement=Arrangement.spacedBy(5.dp)) {
                    Row {Text(title,Modifier.weight(1f),fontSize=11.sp,lineHeight=14.sp,fontWeight=FontWeight.SemiBold,color=p.secondary);Text("$value",fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.Bold,color=p.primary)}
                    Box(Modifier.fillMaxWidth().height(7.dp).background(p.stroke.copy(alpha=p.stroke.alpha*.25f),CircleShape)) {Box(Modifier.fillMaxHeight().fillMaxWidth(fraction.coerceIn(0f,1f)).background(barColor(value),CircleShape))}
                }
            }
        }
        Text("K/Na ${a.ratioLabel}   ·   "+if(a.optimized){if(english)"Electrolytes optimized"else"Électrolytes optimisés"}else{if(english)"Electrolytes to adjust"else"Électrolytes à ajuster"},fontSize=11.sp,lineHeight=14.sp,fontWeight=FontWeight.SemiBold,color=p.secondary)
        a.caution?.let {Text(it.text(english),fontSize=12.sp,lineHeight=16.sp,color=p.secondary)}
        Text(if(a.estimated){if(english)"≈ Ingredient-based estimate. The score may vary with quantities and your tolerance."else"≈ Estimation basée sur les ingrédients. Le score peut varier selon les quantités et ta tolérance."}else{if(english)"Nutrition estimate — digestive tolerance is still individual."else"Estimation nutritionnelle — la tolérance digestive reste individuelle."},fontSize=11.sp,lineHeight=14.sp,color=p.secondary.copy(alpha=p.secondary.alpha*.78f))
    }
}
