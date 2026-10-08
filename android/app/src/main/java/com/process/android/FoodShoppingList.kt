package com.process.android

import android.content.Context
import androidx.compose.runtime.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class FoodShoppingEntry(val id:String,val foodId:String,val quantity:String,val checked:Boolean=false)

object FoodShoppingPolicy {
    /** Mirrors MealHubStore: unchecked-name deduplication, swaps, newest first, cap 80. */
    fun merge(existing:List<FoodShoppingEntry>,food:DebloatFood,newId:()->String={UUID.randomUUID().toString()}):List<FoodShoppingEntry> {
        if(existing.any { !it.checked && DebloatFoods.item(it.foodId)?.name.equals(food.name,ignoreCase=true) }) return existing
        val target=if(food.tier==FoodTier.avoid || food.exceedsSaltLabelThreshold) FoodCatalogModel.swaps(food).firstOrNull() ?: food else food
        if(existing.any { !it.checked && DebloatFoods.item(it.foodId)?.name.equals(target.name,ignoreCase=true) }) return existing
        return (listOf(FoodShoppingEntry(newId(),target.id,food.portion ?: "1"))+existing).take(80)
    }
}

/** Local preview adapter. Authenticated app must bind this state to its active plan repository. */
class FoodShoppingList(context:Context,userId:String?) {
    private val preferences=context.applicationContext.getSharedPreferences(FoodStorageScope.key(userId),Context.MODE_PRIVATE)
    var entries by mutableStateOf(read())
        private set
    private fun read():List<FoodShoppingEntry> = runCatching {
        val rows=JSONArray(preferences.getString("shopping","[]") ?: "[]")
        (0 until rows.length()).map { index ->
            val row=rows.getJSONObject(index)
            FoodShoppingEntry(row.getString("id"),row.getString("foodId"),row.getString("quantity"),row.optBoolean("checked"))
        }
    }.getOrDefault(emptyList())
    fun add(food:DebloatFood) { save(FoodShoppingPolicy.merge(entries,food)) }
    fun toggle(id:String) { save(entries.map { if(it.id==id) it.copy(checked=!it.checked) else it }) }
    fun remove(id:String) { save(entries.filter { it.id!=id }) }
    fun clearChecked() { save(entries.filterNot { it.checked }) }
    private fun save(next:List<FoodShoppingEntry>) {
        entries=next
        val rows=JSONArray()
        next.forEach { rows.put(JSONObject().put("id",it.id).put("foodId",it.foodId).put("quantity",it.quantity).put("checked",it.checked)) }
        preferences.edit().putString("shopping",rows.toString()).apply()
    }
}
