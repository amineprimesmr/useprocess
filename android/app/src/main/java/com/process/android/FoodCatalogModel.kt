package com.process.android

import java.security.MessageDigest

enum class FoodCatalogTab { Prefer,Avoid,Tastes }
data class FoodSection(val category:FoodCategory,val foods:List<DebloatFood>)

object FoodCatalogModel {
    fun sections(tiers:Set<FoodTier>,query:String="",english:Boolean=false):List<FoodSection> {
        val needle=FoodNames.normalize(query)
        return FoodCategory.entries.mapNotNull { category ->
            val foods=DebloatFoods.all.filter { food ->
                food.category==category && food.tier in tiers &&
                    (needle.isEmpty() || FoodNames.normalize(food.name).contains(needle) ||
                        FoodNames.normalize(FoodCopy.name(food,english)).contains(needle) ||
                        food.tags.any { FoodNames.normalize(it).contains(needle) })
            }.sortedWith(compareBy<DebloatFood> { it.tier.ordinal }.thenByDescending { it.score })
            foods.takeIf { it.isNotEmpty() }?.let { FoodSection(category,it) }
        }
    }
    fun swaps(food:DebloatFood)=food.swaps.mapNotNull(DebloatFoods::item)
}

data class FoodPreferenceState(
    val likedIDs:Set<String> = emptySet(),
    val dislikedIDs:Set<String> = emptySet(),
    val haveAtHomeIDs:Set<String> = emptySet()
) {
    fun toggleLike(id:String):FoodPreferenceState =
        if(id in likedIDs) copy(likedIDs=likedIDs-id)
        else copy(likedIDs=likedIDs+id,dislikedIDs=dislikedIDs-id)
    fun toggleDislike(id:String):FoodPreferenceState =
        if(id in dislikedIDs) copy(dislikedIDs=dislikedIDs-id)
        else copy(dislikedIDs=dislikedIDs+id,likedIDs=likedIDs-id)
    fun toggleAtHome(id:String)=copy(haveAtHomeIDs=if(id in haveAtHomeIDs) haveAtHomeIDs-id else haveAtHomeIDs+id)
    val likedFoods:List<DebloatFood> get()=likedIDs.mapNotNull(DebloatFoods::item).sortedByDescending { it.score }
    val homeFoods:List<DebloatFood> get()=haveAtHomeIDs.mapNotNull(DebloatFoods::item).sortedBy { FoodNames.normalize(it.name) }
}

object FoodStorageScope {
    fun key(userId:String?):String {
        val uid=userId?.takeIf { it.isNotBlank() } ?: "local-user"
        val hash=MessageDigest.getInstance("SHA-256").digest(uid.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        return "process.food.$hash"
    }
}
