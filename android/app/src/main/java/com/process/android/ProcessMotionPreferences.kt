package com.process.android

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext

/** Android's remove-animations setting; observe changes without polling or owning an Activity. */
@Composable fun rememberProcessReducedMotion(): Boolean {
    val resolver=LocalContext.current.contentResolver
    fun read()=Settings.Global.getFloat(resolver,Settings.Global.ANIMATOR_DURATION_SCALE,1f)==0f
    var reduced by remember(resolver) {mutableStateOf(read())}
    DisposableEffect(resolver) {
        val observer=object:ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange:Boolean) {reduced=read()}
        }
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),false,observer)
        onDispose {resolver.unregisterContentObserver(observer)}
    }
    return reduced
}

/** TalkBack users receive complete lines, never a sequence of per-character announcements. */
@Composable fun rememberProcessScreenReader():Boolean {
    val context=LocalContext.current
    val manager=remember(context) {context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager}
    var enabled by remember(manager) {mutableStateOf(manager.isTouchExplorationEnabled)}
    DisposableEffect(manager) {
        val listener=android.view.accessibility.AccessibilityManager.TouchExplorationStateChangeListener {enabled=it}
        manager.addTouchExplorationStateChangeListener(listener)
        onDispose {manager.removeTouchExplorationStateChangeListener(listener)}
    }
    return enabled
}
