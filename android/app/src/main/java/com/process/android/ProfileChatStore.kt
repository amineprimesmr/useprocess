package com.process.android

import android.content.Context
import androidx.compose.runtime.*
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject

/** Local persistence only; authenticated synchronization is provided by the host callback. */
class ProfileChatStore(context:Context,userId:String?) {
    private val scope=MessageDigest.getInstance("SHA-256").digest((userId ?: "local-preview").toByteArray()).joinToString(""){"%02x".format(it)}
    private val preferences=context.applicationContext.getSharedPreferences("process-profile-chat-$scope",Context.MODE_PRIVATE)
    var progress by mutableStateOf(read());private set
    private fun read():ProfileChatProgress=runCatching {
        val json=JSONObject(preferences.getString("progress","{}") ?: "{}")
        val done=json.optJSONArray("completed") ?: JSONArray()
        val answers=json.optJSONObject("answers") ?: JSONObject()
        ProcessProfileChatModel.normalize(ProfileChatProgress((0 until done.length()).map {done.getString(it)}.toSet(),answers.keys().asSequence().associateWith {answers.getString(it)}))
    }.getOrDefault(ProfileChatProgress())
    fun save(value:ProfileChatProgress) {
        progress=ProcessProfileChatModel.normalize(value)
        preferences.edit().putString("progress",JSONObject().put("completed",JSONArray(progress.completed.toList())).put("answers",JSONObject(progress.answers)).toString()).apply()
    }
    fun wasPresented(id:String)=preferences.getString("presented",null)==id
    fun markPresented(id:String) {preferences.edit().putString("presented",id).apply()}
}
