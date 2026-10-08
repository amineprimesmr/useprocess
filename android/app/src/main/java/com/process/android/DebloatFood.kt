package com.process.android

import java.text.Normalizer
import java.util.Locale
import kotlin.math.*

enum class FoodTier { hero,prefer,moderate,avoid }
enum class FoodCategory { legumes,fruits,potassium,magnesium,protein,herbs,drinks,avoidSodium,avoidOther }
data class DebloatFood(
 val id:String,val name:String,val category:FoodCategory,val tier:FoodTier,
 val potassium:Double?,val sodium:Double?,val magnesium:Double?,val why:String,
 val tags:List<String> = emptyList(),val swaps:List<String> = emptyList(),val portion:String? = null
) {
 val score:Int get()=DebloatFoodScore.score(potassium,sodium,magnesium,tier,tags)
 val saltGrams:Double? get()=sodium?.div(400.0)
 val exceedsSaltLabelThreshold:Boolean get()=saltGrams?.let { it>1.5 } ?: false
 val potassiumSodiumRatio:Double? get()=if(potassium!=null && sodium!=null) potassium/max(sodium,1.0) else null
 val eveningSafe:Boolean get()="soir-safe" in tags
 val highPotassium:Boolean get()="high-K" in tags
 val trend:Boolean get()="tiktok-trend" in tags
}

/** Exact port of Process's curated scoring; this is product data, not a new model. */
object DebloatFoodScore {
 fun score(k:Double?,na:Double?,mg:Double?,tier:FoodTier,tags:List<String> = emptyList()):Int {
  if(tier==FoodTier.avoid) return (28-(na ?: 800.0)/80).coerceIn(0.0,35.0).roundToInt()
  val potassium=when { k==null->40.0;k>=400->100.0;k>=200->60+(k-200)/200*40;else->max(12.0,k/200*60) }
  val lowSodium=when { na==null->55.0;na<=50->100.0;na<=200->100-(na-50)/150*25;na>=800->8.0;else->75-(na-200)/600*67 }
  val magnesium=when { mg==null->35.0;mg>=150->100.0;mg>=50->55+(mg-50)/100*45;else->max(10.0,mg/50*55) }
  var raw=potassium*.45+lowSodium*.35+magnesium*.20
  if("ultra-processed" in tags) raw-=18
  if("evening-risk" in tags) raw-=10
  if(tier==FoodTier.hero) raw=max(raw,82.0)
  if(tier==FoodTier.moderate) raw=min(raw,62.0)
  return raw.coerceIn(0.0,100.0).roundToInt()
 }
}
object FoodNames {
 fun normalize(raw:String):String=Normalizer.normalize(raw,Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"").lowercase(Locale.FRENCH).replace("œ","oe").replace("æ","ae").trim()
 fun tokens(raw:String):List<String> = normalize(raw).split(Regex("[^\\p{L}\\p{N}]+" )).filter { it.length>=3 }
}
