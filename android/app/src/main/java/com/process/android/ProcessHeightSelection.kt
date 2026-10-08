package com.process.android

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** One-centimetre ruler, 140…220, original 8dp tick pitch and canonical centimetres. */
@Composable fun ProcessHeightSelection(
    valueCm: Double,
    onValueChange: (Double) -> Unit,
    onSave: (Double) -> Unit,
    modifier: Modifier = Modifier,
    profileHeightCm: Double? = null,
    initialUnit: ProcessHeightUnit = ProcessHeightUnit.CM,
    onValidationChange: (Boolean) -> Unit = {},
    english: Boolean = false,
    dark: Boolean = isSystemInDarkTheme()
) {
    val palette=InputPalette(dark)
    val initial=remember { OnboardingPickerRules.initialHeight(valueCm,profileHeightCm) }
    val pager=rememberPagerState(initialPage=initial-140) {81}
    var unitName by rememberSaveable {mutableStateOf(initialUnit.name)}
    val unit=ProcessHeightUnit.valueOf(unitName)
    val change by rememberUpdatedState(onValueChange)
    val save by rememberUpdatedState(onSave)
    val current by rememberUpdatedState(valueCm)
    var lastSaved by remember {mutableIntStateOf(initial)}
    var crossedRange by remember {mutableStateOf((initial-140)..(initial-140))}
    val scope=rememberCoroutineScope()
    val haptics=LocalHapticFeedback.current
    LaunchedEffect(Unit) {if(valueCm!=initial.toDouble()) change(initial.toDouble())}
    LaunchedEffect(valueCm) {
        val cm=OnboardingPickerRules.initialHeight(valueCm)
        onValidationChange(valueCm.isFinite() && valueCm in 140.0..220.0)
        if(!pager.isScrollInProgress && pager.currentPage!=cm-140) pager.animateScrollToPage(cm-140,animationSpec=spring(1f,438.65f))
        if(cm!=lastSaved) {delay(OnboardingPickerRules.HEIGHT_SAVE_DELAY_MS);save(cm.toDouble());lastSaved=cm}
    }
    LaunchedEffect(pager) {
        var previous=pager.currentPage
        snapshotFlow {pager.currentPage to pager.isScrollInProgress}.collect { (index,moving) ->
            crossedRange=if(moving)minOf(previous,index)..maxOf(previous,index) else index..index
            previous=index
            val cm=OnboardingPickerRules.heightForIndex(index).toDouble()
            if(current!=cm) {change(cm);haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)}
        }
    }
    Box(modifier.fillMaxSize().background(palette.background)) {
        Text(if(english) "What's your height?" else "Quelle est ta taille ?",Modifier.padding(start=40.dp,end=20.dp,top=54.dp),fontSize=26.sp,fontWeight=FontWeight.Bold,color=palette.primary)
        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(210.dp))
            InputUnitToggle("CM","FT",unit==ProcessHeightUnit.CM,{unitName=if(it)ProcessHeightUnit.CM.name else ProcessHeightUnit.FT.name},palette)
            Spacer(Modifier.height(60.dp))
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp,Alignment.CenterHorizontally)) {
                Text(OnboardingPickerRules.heightLabel(OnboardingPickerRules.initialHeight(valueCm),unit),Modifier.alignByBaseline(),fontSize=56.sp,fontWeight=FontWeight.Bold,color=palette.primary)
                if(unit==ProcessHeightUnit.CM)Text("cm",Modifier.alignByBaseline(),fontSize=20.sp,fontWeight=FontWeight.Medium,color=palette.body)
            }
            Spacer(Modifier.height(56.dp))
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal=15.dp)) {
                HorizontalPager(state=pager,pageSize=PageSize.Fixed(8.dp),contentPadding=PaddingValues(horizontal=(maxWidth-8.dp)/2),
                    modifier=Modifier.fillMaxWidth().height(72.dp).clearAndSetSemantics {
                        contentDescription=if(english) "Height" else "Taille"
                        stateDescription=OnboardingPickerRules.heightLabel(OnboardingPickerRules.initialHeight(valueCm),unit)+(if(unit==ProcessHeightUnit.CM) " cm" else "")
                        progressBarRangeInfo=ProgressBarRangeInfo(valueCm.toFloat(),140f..220f,79)
                        setProgress { requested->scope.launch {pager.animateScrollToPage(requested.roundToInt().coerceIn(140,220)-140,animationSpec=spring(1f,438.65f))};true }
                    }) { index ->
                    val active=pager.currentPage==index
                    val inside=index in crossedRange
                    val height by animateDpAsState(if(active||inside)32.dp else 17.6.dp,spring(1f,438.65f),label="height.tick.length")
                    val tint by animateColorAsState(palette.primary.copy(alpha=if(active)1f else (if(dark).35f else .22f)*(if(inside)1f else .4f)),spring(1f,438.65f),label="height.tick.color")
                    Box(Modifier.width(8.dp).height(72.dp),contentAlignment=Alignment.Center) {
                        Box(Modifier.height(32.dp),contentAlignment=Alignment.BottomCenter) { Box(Modifier.width(2.dp).height(height).background(tint)) }
                    }
                }
            }
        }
    }
}
