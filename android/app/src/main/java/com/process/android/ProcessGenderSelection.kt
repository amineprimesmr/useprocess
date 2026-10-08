package com.process.android

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*

enum class ProcessGender { Male,Female }

/** Isolated port of GenderSelectionStepView; selection persistence belongs to host. */
@Composable
fun ProcessGenderSelection(selected:ProcessGender?,onSelect:(ProcessGender)->Unit,modifier:Modifier=Modifier,english:Boolean=false) {
    val haptics=LocalHapticFeedback.current
    Box(modifier.fillMaxSize()) {
        Text(if(english) "Choose your gender" else "Choisis ton genre",Modifier.align(Alignment.TopCenter).padding(top=54.dp),style=MaterialTheme.typography.headlineLarge,fontWeight=FontWeight.Bold)
        Row(Modifier.fillMaxWidth().selectableGroup().padding(top=210.dp,start=24.dp,end=24.dp).height(250.dp),horizontalArrangement=Arrangement.SpaceEvenly,verticalAlignment=Alignment.CenterVertically) {
            ProcessGender.entries.forEach { gender ->
                val active=selected==gender
                val width by animateDpAsState(if(active)150.dp else 120.dp,spring(.78f,(2*Math.PI/.3).let { (it*it).toFloat() }),label="gender.width")
                val height by animateDpAsState(if(active)210.dp else 170.dp,spring(.78f,(2*Math.PI/.3).let { (it*it).toFloat() }),label="gender.height")
                val scale by animateFloatAsState(if(active)1.1f else 1f,spring(.8f,(2*Math.PI/.4).let { (it*it).toFloat() }),label="gender.scale")
                val opacity by animateFloatAsState(if(active)1f else .6f,spring(.78f,(2*Math.PI/.3).let { (it*it).toFloat() }),label="gender.opacity")
                val title=if(english) { if(gender==ProcessGender.Male) "Male" else "Female" } else { if(gender==ProcessGender.Male) "Homme" else "Femme" }
                Column(Modifier.scale(scale).selectable(selected=active,role=Role.RadioButton,onClick={ haptics.performHapticFeedback(HapticFeedbackType.LongPress); onSelect(gender) }),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(4.dp)) {
                    Image(painterResource(if(gender==ProcessGender.Male)R.drawable.homme else R.drawable.femme),null,Modifier.size(width,height).alpha(opacity))
                    Text(title,fontSize=16.sp,fontWeight=FontWeight.Medium,modifier=Modifier.alpha(opacity))
                }
            }
        }
    }
}
