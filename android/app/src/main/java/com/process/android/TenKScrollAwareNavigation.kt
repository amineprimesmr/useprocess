package com.process.android
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*

/** Root overlay; host supplies actual tab bar, optional accessory and scroll content. */
@Composable fun TenKScrollAwareNavigation(
 scrollState:ScrollState,modifier:Modifier=Modifier,contextKey:Any=Unit,
 reduceMotion:Boolean=rememberProcessReducedMotion(),navigation:@Composable ()->Unit,content:@Composable ()->Unit,
) {
 var model by remember(contextKey,scrollState){mutableStateOf(ScrollNavigationModel())}
 val interacting by scrollState.interactionSource.collectIsDraggedAsState();val density=LocalDensity.current
 LaunchedEffect(scrollState,contextKey,density) {
  snapshotFlow {scrollState.value to interacting}.collect {(offset,active)->model=model.update(with(density){offset.toDp().value},active)}
 }
 val progress by animateFloatAsState(if(model.hidden)1f else 0f,if(reduceMotion)snap()else tween(300),label="navigation visibility")
 var height by remember {mutableIntStateOf(0)}
 Box(modifier.clipToBounds()) {
  content()
  Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().onSizeChanged {height=it.height}.offset {IntOffset(0,(height*progress).toInt())}.then(if(model.hidden)Modifier.clearAndSetSemantics {}else Modifier)) {navigation()}
 }
}
