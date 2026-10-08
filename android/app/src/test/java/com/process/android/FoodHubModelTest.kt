package com.process.android
import org.junit.Test
import org.junit.Assert.*
class FoodHubModelTest {
 @Test fun illustratedOrderAndAccentSearch() {
  assertEquals(FoodHubModel.illustratedOrder,FoodHubModel.foods().take(12).map {it.id})
  assertEquals(listOf("epinards"),FoodHubModel.foods("éPiNaRdS").map {it.id})
  assertEquals(listOf("concombre","eau-concombre-menthe"),FoodHubModel.foods("cucumber",true).map {it.id})
  assertFalse(FoodHubModel.foods().any {it.tier==FoodTier.avoid||it.tier==FoodTier.moderate})
 }
 @Test fun absentSlotFallsBackAndInvalidConfigurationDoesNotLeak() {
  assertEquals(listOf("breakfast","lunch","dinner"),FoodHubModel.slots(emptyList()))
  assertEquals(listOf("dinner"),FoodHubModel.slots(listOf("dinner","invalid","dinner")))
  assertEquals("dinner",FoodHubModel.effectiveSlot("breakfast",listOf("dinner")))
 }
 @Test fun lunchDoesNotMergeOmadAndTodayHasDistinctIdentity() {
  val lunch=ProcessRecipeCatalog.meals.first {it.slot=="lunch"&&it.section=="lunch"}
  val entries=FoodHubModel.meals("lunch",listOf(lunch))
  assertTrue(entries.first().fromPlan)
  assertEquals(2,entries.count {it.meal.id==lunch.id})
  assertEquals(entries.size,entries.map {it.key}.distinct().size)
  assertFalse(entries.any {it.meal.section=="omad"})
 }
}
