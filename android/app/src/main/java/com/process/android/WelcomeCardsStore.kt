package com.process.android
import android.content.Context
import java.security.MessageDigest

/** Recreate on identity change. A null user ID is an isolated local gallery preview. */
class WelcomeCardsStore(context:Context,userId:String?) {
    private val identity=userId?.takeIf {it.isNotBlank()}?.let {MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString(""){b->"%02x".format(b)}}?:"preview"
    private val prefs=context.getSharedPreferences("process-welcome-cards-$identity",Context.MODE_PRIVATE)
    fun load()=WelcomeCardDismissal(prefs.getBoolean("plan.home.upgrade_pro.front_dismissed",false),prefs.getBoolean("plan.home.upgrade_pro.dismissed",false)).normalized()
    fun save(value:WelcomeCardDismissal) {val state=value.normalized();prefs.edit().putBoolean("plan.home.upgrade_pro.front_dismissed",state.frontDismissed).putBoolean("plan.home.upgrade_pro.dismissed",state.stackDismissed).apply()}
}
