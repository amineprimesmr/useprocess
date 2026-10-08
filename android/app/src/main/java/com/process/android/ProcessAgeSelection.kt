package com.process.android

import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** Source 13…100 wheel, five 92dp slots, continuous distance transform and 500ms save debounce. */
@Composable fun ProcessAgeSelection(
    value: Int,
    onValueChange: (Int) -> Unit,
    onSave: (Int) -> Unit,
    modifier: Modifier = Modifier,
    onValidationChange: (Boolean) -> Unit = {},
    english: Boolean = false,
    dark: Boolean = isSystemInDarkTheme()
) {
    val palette = InputPalette(dark)
    val initial = remember { OnboardingPickerRules.initialAge(value) }
    val pager = rememberPagerState(initialPage = initial - 13) { 88 }
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val change by rememberUpdatedState(onValueChange)
    val save by rememberUpdatedState(onSave)
    var lastSaved by remember { mutableIntStateOf(initial) }
    val latestValue by rememberUpdatedState(value)
    LaunchedEffect(Unit) { if (value != initial) change(initial) }
    LaunchedEffect(value) {
        onValidationChange(value in 13..100)
        if (value in 13..100 && !pager.isScrollInProgress && pager.currentPage != value - 13) pager.animateScrollToPage(value - 13, animationSpec = tween(300))
        if (value in 13..100 && value != lastSaved) {
            delay(OnboardingPickerRules.AGE_SAVE_DELAY_MS)
            save(value); lastSaved = value
        }
    }
    LaunchedEffect(pager) {
        snapshotFlow { pager.currentPage }.collect { page ->
            val age = page + 13
            if (age != latestValue) { change(age); haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().background(palette.background)) {
        val wheelHeight = (maxHeight - 290.dp).coerceIn(184.dp, 460.dp)
        Text(if (english) "How old are you?" else "Quel est ton âge ?", Modifier.padding(start=40.dp,end=20.dp,top=54.dp), fontSize=26.sp,fontWeight=FontWeight.Bold,color=palette.primary)
        VerticalPager(
            state = pager,
            pageSize = PageSize.Fixed(92.dp),
            contentPadding = PaddingValues(vertical = (wheelHeight - 92.dp) / 2),
            flingBehavior = PagerDefaults.flingBehavior(pager, pagerSnapDistance = PagerSnapDistance.atMost(88)),
            modifier = Modifier.padding(top=250.dp,start=40.dp,end=40.dp).fillMaxWidth().height(wheelHeight)
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
                .drawWithContent { drawContent(); drawRect(Brush.verticalGradient(0f to Color.Transparent,.2f to Color.Black,.8f to Color.Black,1f to Color.Transparent),blendMode=BlendMode.DstIn) }
                .clearAndSetSemantics {
                    contentDescription = if (english) "Age" else "Âge"
                    stateDescription = value.toString()
                    progressBarRangeInfo = ProgressBarRangeInfo(value.toFloat(),13f..100f,86)
                    setProgress { requested -> scope.launch { pager.animateScrollToPage(requested.roundToInt().coerceIn(13,100)-13,animationSpec=tween(300)) };true }
                }
        ) { page ->
            Box(Modifier.fillMaxWidth().height(92.dp).clickable { scope.launch { pager.animateScrollToPage(page,animationSpec=tween(300)) } }
                .graphicsLayer {
                    val effect=OnboardingPickerRules.ageTransform((pager.currentPage-page)+pager.currentPageOffsetFraction)
                    scaleX=effect.scale;scaleY=effect.scale;alpha=effect.alpha
                },contentAlignment=Alignment.Center) {
                Text((page+13).toString(),style=TextStyle(fontSize=88.sp,fontWeight=FontWeight.Bold,letterSpacing=(-3).sp,
                    brush=Brush.linearGradient(listOf(palette.primary,palette.primary.copy(alpha=.95f),Color.Gray.copy(alpha=.6f)))))
            }
        }
    }
}
