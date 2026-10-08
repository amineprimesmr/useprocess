package com.process.android

/** Read-only browsing model. Today entries and assessments belong to the signed-in plan host. */
data class FoodHubMeal(val key:String,val meal:ProcessRecipe,val fromPlan:Boolean)
object FoodHubModel {
 val illustratedOrder=listOf("banane","avocat","tomate","concombre","carotte","epinards","brocoli","fraises","citron","kiwi","pasteque","aubergine")
 private val categoryOrder=listOf(FoodCategory.legumes,FoodCategory.potassium,FoodCategory.fruits,FoodCategory.drinks,FoodCategory.herbs,FoodCategory.protein,FoodCategory.magnesium)
 fun foods(query:String="",english:Boolean=false):List<DebloatFood> {
  val q=FoodNames.normalize(query)
  return DebloatFoods.all.filter {it.tier in setOf(FoodTier.hero,FoodTier.prefer)}.sortedWith(compareBy<DebloatFood> {if(it.id in illustratedOrder)0 else 1}.thenBy {illustratedOrder.indexOf(it.id).takeIf {i->i>=0}?:categoryOrder.indexOf(it.category).takeIf {i->i>=0}?:9}.thenByDescending {it.score}).filter {q.isEmpty()||FoodNames.normalize(FoodCopy.name(it,english)).contains(q)||FoodNames.normalize(it.name).contains(q)}
 }
 fun slots(configured:List<String>)=configured.filter {it in setOf("breakfast","lunch","dinner","snack")}.distinct().ifEmpty {listOf("breakfast","lunch","dinner")}
 fun effectiveSlot(selected:String,configured:List<String>)=slots(configured).let {if(selected in it)selected else it.first()}
 fun meals(slot:String,today:List<ProcessRecipe>):List<FoodHubMeal> {
  val section=ProcessRecipeCatalog.meals.firstOrNull {it.slot==slot}?.section
  return listOfNotNull(today.firstOrNull {it.slot==slot}?.let {FoodHubMeal("today:${it.id}",it,true)})+ProcessRecipeCatalog.meals.filter {it.slot==slot&&it.section==section}.map {FoodHubMeal("catalog:${it.id}",it,false)}
 }
 fun title(slot:String,english:Boolean)=when(slot){"breakfast"->if(english)"Breakfast"else"Petit déj";"lunch"->if(english)"Lunch"else"Déjeuner";"dinner"->if(english)"Dinner"else"Dîner";else->if(english)"Snack"else"Collation"}
}
