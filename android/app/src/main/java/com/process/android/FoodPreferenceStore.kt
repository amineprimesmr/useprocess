package com.process.android

import android.content.Context
import androidx.compose.runtime.*
import org.json.JSONArray
import org.json.JSONObject

/** Local account-scoped preferences. Host recreates the store when auth identity changes. */
class FoodPreferenceStore(context:Context,userId:String?) {
    private val preferences=context.applicationContext.getSharedPreferences(FoodStorageScope.key(userId),Context.MODE_PRIVATE)
    var state by mutableStateOf(read())
        private set
    private fun read():FoodPreferenceState = runCatching {
        val value=JSONObject(preferences.getString("preferences","{}") ?: "{}")
        fun strings(key:String):Set<String> {
            val array=value.optJSONArray(key) ?: return emptySet()
            return (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }.toSet()
        }
        FoodPreferenceState(strings("likedIDs"),strings("dislikedIDs"),strings("haveAtHomeIDs"))
    }.getOrDefault(FoodPreferenceState())
    fun reload() { state=read() }
    fun toggleLike(id:String) { save(state.toggleLike(id)) }
    fun toggleDislike(id:String) { save(state.toggleDislike(id)) }
    fun toggleAtHome(id:String) { save(state.toggleAtHome(id)) }
    private fun save(next:FoodPreferenceState) {
        state=next
        val value=JSONObject().put("likedIDs",JSONArray(next.likedIDs.sorted()))
            .put("dislikedIDs",JSONArray(next.dislikedIDs.sorted())).put("haveAtHomeIDs",JSONArray(next.haveAtHomeIDs.sorted()))
        preferences.edit().putString("preferences",value.toString()).apply()
    }
}
