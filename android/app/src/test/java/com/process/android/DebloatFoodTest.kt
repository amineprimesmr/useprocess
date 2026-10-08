package com.process.android
import org.junit.Assert.*
import org.junit.Test
class DebloatFoodTest {
 @Test fun scorePreservesHeroFloorModerationCapAndAvoidFallback() {
  assertEquals(82,DebloatFoodScore.score(147.0,2.0,13.0,FoodTier.hero))
  assertEquals(62,DebloatFoodScore.score(500.0,0.0,200.0,FoodTier.moderate))
  assertEquals(18,DebloatFoodScore.score(null,null,null,FoodTier.avoid))
  assertEquals(44,DebloatFoodScore.score(null,null,null,FoodTier.prefer))
  assertEquals(0,DebloatFoodScore.score(null,5000.0,null,FoodTier.avoid))
 }
 @Test fun processedAndEveningPenaltiesStack() {
  assertEquals(72,DebloatFoodScore.score(500.0,0.0,200.0,FoodTier.prefer,listOf("ultra-processed","evening-risk")))
 }
 @Test fun saltThresholdUsesStrictGreaterThanAndRatioAvoidsDivisionByZero() {
  val food=DebloatFood("id","name",FoodCategory.protein,FoodTier.prefer,200.0,600.0,null,"")
  assertFalse(food.exceedsSaltLabelThreshold)
  assertTrue(food.copy(sodium=601.0).exceedsSaltLabelThreshold)
  assertEquals(200.0,food.copy(sodium=0.0).potassiumSodiumRatio!!,0.0)
  assertNull(food.copy(sodium=null).potassiumSodiumRatio)
 }
 @Test fun exportedIdsAreUniqueAndOriginalCucumberIsPresent() {
  assertEquals(DebloatFoods.all.size,DebloatFoods.all.map { it.id }.toSet().size)
  assertEquals("Concombre",DebloatFoods.item("concombre")!!.name)
  assertEquals(82,DebloatFoods.item("concombre")!!.score)
 }
 @Test fun normalizationPreservesFrenchLigaturesAndDiacriticsMatching() {
  assertEquals("oeufs a la creme",FoodNames.normalize(" Œufs à la crème "))
  assertTrue(DebloatFoods.search("epinards").isNotEmpty())
 }
}
