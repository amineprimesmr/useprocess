package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** ChipSelection / ChipsView, Balaji Venkatesh,10/03/25. Selection order follows tap order. */
@OptIn(ExperimentalLayoutApi::class)
@Composable fun <T:Any> TenKChips(
    tags:List<T>,selection:List<T>,onSelectionChange:(List<T>)->Unit,modifier:Modifier=Modifier,
    spacing:androidx.compose.ui.unit.Dp=10.dp,content:@Composable (T,Boolean)->Unit,
) {
    require(tags.distinct().size==tags.size) {"Tags must have unique identities"}
    FlowRow(modifier,horizontalArrangement=Arrangement.spacedBy(spacing),verticalArrangement=Arrangement.spacedBy(spacing)) {
        tags.forEach {tag ->key(tag) {
            val selected=tag in selection
            Box(Modifier.toggleable(selected,role=Role.Checkbox,onValueChange={value ->onSelectionChange(if(value)(selection+tag).distinct()else selection.filterNot {it==tag})})) {content(tag,selected)}
        }}
    }
}

@Composable fun TenKChip(label:String,selected:Boolean,modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    val duration=if(reduceMotion)0 else 200
    val fraction by animateFloatAsState(if(selected)1f else 0f,tween(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f)),label="chip.selection")
    val dark=isSystemInDarkTheme()
    val surface=if(dark)Color.Black else Color.White
    val ink=if(dark)Color.White else Color.Black
    val textColor=androidx.compose.ui.graphics.lerp(ink,Color.White,fraction)
    Box(modifier.background(surface,CircleShape).background(Brush.verticalGradient(listOf(Color(0xFF34C759).copy(alpha=fraction),Color(0xFF248A3D).copy(alpha=fraction))),CircleShape)) {
        Row(Modifier.padding(horizontal=12.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)) {
            Text(label,fontSize=16.sp,letterSpacing=0.sp,color=textColor)
            AnimatedVisibility(selected,enter=fadeIn(tween(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f)))+expandHorizontally(tween(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f))),exit=fadeOut(tween(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f)))+shrinkHorizontally(tween(duration,easing=CubicBezierEasing(.42f,0f,.58f,1f)))) {
                Icon(Icons.Default.CheckCircle,null,Modifier.size(17.dp),tint=Color.White)
            }
        }
    }
}
val originalChipTags=listOf("iOS 14","SwiftUI","macOS","watchOS","tvOS","Xcode","macCatalyst","UIKit","AppKit","Cocoa","Objective-C")
@Composable fun TenKChipGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    var selected by remember {mutableStateOf(emptyList<String>())}
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(15.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text("Chips Selection",fontSize=30.sp)
        Spacer(Modifier.height(30.dp))
        Text("Select more than two tags:",fontSize=11.sp,color=Color.Gray)
        TenKChips(originalChipTags,selected,{selected=it},Modifier.fillMaxWidth().background(Color.Gray.copy(alpha=.12f),androidx.compose.foundation.shape.RoundedCornerShape(20.dp)).padding(10.dp)) {tag,isSelected ->TenKChip(tag,isSelected,reduceMotion=reduceMotion)}
    }
}
