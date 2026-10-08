package com.process.android
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/** Read actual system state again on resume; this never grants or requests notification permission. */
@Composable fun rememberProcessNotificationsEnabled():Boolean? {
    val context=LocalContext.current;val owner=LocalLifecycleOwner.current
    fun read():Boolean?=runCatching {context.getSystemService(NotificationManager::class.java)?.areNotificationsEnabled()}.getOrNull()
    var enabled by remember(context){mutableStateOf(read())}
    DisposableEffect(owner,context){
        enabled=read()
        val observer=LifecycleEventObserver {_,event->if(event==Lifecycle.Event.ON_RESUME)enabled=read()}
        owner.lifecycle.addObserver(observer);onDispose {owner.lifecycle.removeObserver(observer)}
    }
    return enabled
}
fun openProcessNotificationSettings(context:Context):Boolean=runCatching {
    context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));true
}.getOrDefault(false)
