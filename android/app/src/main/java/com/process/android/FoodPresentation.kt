package com.process.android

import androidx.compose.ui.graphics.Color

internal data class FoodPalette(val dark:Boolean) {
    val background=if(dark) Color(.07f,.08f,.11f) else Color(.925f,.927f,.933f)
    val primary=if(dark) Color.White else Color.Black
    val secondary=if(dark) Color(235/255f,235/255f,245/255f,.6f) else Color(60/255f,60/255f,67/255f,.6f)
    // Android translucent surface approximation; iOS 26 refraction remains unverified.
    val surface=if(dark) Color.White.copy(alpha=.08f) else Color.White.copy(alpha=.58f)
    val stroke=if(dark) Color.White.copy(alpha=.08f) else Color(.72f,.78f,.93f,.72f)
}
internal fun foodText(fr:String,en:String,english:Boolean)=if(english) en else fr
internal fun FoodTier.badge(english:Boolean)=when(this) {
    FoodTier.hero->"Hero K"
    FoodTier.prefer->foodText("Drainant","Draining",english)
    FoodTier.moderate->foodText("Modéré","Moderate",english)
    FoodTier.avoid->foodText("À éviter","Avoid",english)
}
internal val FoodTier.tint:Color get()=when(this) {
    FoodTier.hero->Color(.24f,.70f,.46f)
    FoodTier.prefer->Color(.35f,.62f,.95f)
    FoodTier.moderate->Color(1f,.58f,0f)
    FoodTier.avoid->Color(1f,.23f,.19f,.85f)
}
internal fun FoodCategory.title(english:Boolean)=when(this) {
    FoodCategory.legumes->foodText("Légumes drainants","Draining vegetables",english)
    FoodCategory.fruits->foodText("Fruits drainants","Draining fruits",english)
    FoodCategory.potassium->foodText("Sources de potassium","Potassium sources",english)
    FoodCategory.magnesium->foodText("Sources de magnésium","Magnesium sources",english)
    FoodCategory.protein->foodText("Protéines de qualité","Quality proteins",english)
    FoodCategory.herbs->foodText("Herbes & condiments","Herbs & seasonings",english)
    FoodCategory.drinks->foodText("Boissons","Drinks",english)
    FoodCategory.avoidSodium->foodText("Très riches en sodium","Very high sodium",english)
    FoodCategory.avoidOther->foodText("Rétention / inflammation","Retention / inflammation",english)
}
