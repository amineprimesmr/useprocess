package com.tenkdesign.android

import android.os.SystemClock
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Original design: AnimatedButton.swift / Spinner.swift, Balaji Venkatesh, 18/03/25.
 * Host owns outcome/configuration. This component never performs payments itself.
 */
@Composable
fun TenKAsyncButton(
    title: String,
    background: Color,
    modifier: Modifier = Modifier,
    foreground: Color = Color.White,
    symbol: (@Composable () -> Unit)? = null,
    shape: Shape = CircleShape,
    horizontalPadding: Dp = 15.dp,
    verticalPadding: Dp = 10.dp,
    enabled: Boolean = true,
    reduceMotion: Boolean = false,
    loadingDescription: String = "Loading",
    onFailure: (Throwable) -> Unit,
    onClick: suspend () -> Unit,
) {
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.9f else 1f,
        tween(if (reduceMotion) 0 else 200, easing = LinearEasing), label = "buttonPress")
    val transition = tween<Color>(if (reduceMotion) 0 else 250, easing = CubicBezierEasing(.42f,0f,.58f,1f))
    val fill by animateColorAsState(background, transition, label = "buttonBackground")
    val ink by animateColorAsState(foreground, transition, label = "buttonForeground")
    Row(modifier.graphicsLayer { scaleX = scale; scaleY = scale }.clip(shape)
        .background(Brush.verticalGradient(listOf(fill.copy(red = (fill.red + .04f).coerceAtMost(1f), green = (fill.green + .04f).coerceAtMost(1f), blue = (fill.blue + .04f).coerceAtMost(1f)), fill)))
        .clickable(interactionSource = interaction, indication = null, enabled = enabled && !loading, role = Role.Button) {
            // The synchronous gate closes before launching, even for repeated accessibility activation.
            if (!loading) {
                loading = true
                scope.launch {
                    try { onClick() }
                    catch (cancelled: CancellationException) { throw cancelled }
                    catch (failure: Exception) { onFailure(failure) }
                    finally { loading = false }
                }
            }
        }
        .semantics { if (loading) stateDescription = loadingDescription; liveRegion = LiveRegionMode.Polite }
        .animateContentSize(tween(if (reduceMotion) 0 else 250))
        .padding(horizontal = horizontalPadding, vertical = verticalPadding),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        if (symbol != null) symbol()
        else if (loading) TenKAsyncSpinner(ink, Modifier.size(20.dp), reduceMotion = reduceMotion)
        AnimatedContent(title, transitionSpec = {
            fadeIn(tween(if (reduceMotion) 0 else 250)) togetherWith fadeOut(tween(if (reduceMotion) 0 else 250))
        }, label = "buttonTitle") { text -> Text(text, color = ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold) }
    }
}

@Composable
fun TenKAsyncSpinner(tint: Color, modifier: Modifier = Modifier, lineWidth: Dp = 4.dp, reduceMotion: Boolean = false) {
    var angle by remember { mutableFloatStateOf(0f) }
    val owner = LocalLifecycleOwner.current
    LaunchedEffect(owner, reduceMotion) {
        angle = 0f
        if (!reduceMotion) owner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            val start = SystemClock.uptimeMillis()
            while (true) withFrameNanos { angle = AsyncButtonModel.spinnerDegrees(SystemClock.uptimeMillis() - start) }
        }
    }
    Canvas(modifier) {
        val stroke = Stroke(lineWidth.toPx(), cap = StrokeCap.Round)
        drawCircle(tint.copy(alpha = tint.alpha * .3f), radius = size.minDimension / 2, style = stroke)
        drawArc(tint, startAngle = angle, sweepAngle = 108f, useCenter = false, style = stroke)
    }
}
