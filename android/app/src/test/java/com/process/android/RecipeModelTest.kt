package com.process.android
import org.junit.Test
import org.junit.Assert.*
class RecipeModelTest {
 @Test fun allOriginalMealsHaveBilingualContentAndNumberedPreparation() {
  val meals=ProcessRecipeCatalog.meals;assertEquals(18,meals.size);assertEquals(18,meals.map {it.id}.distinct().size)
  meals.forEach {meal ->assertTrue(meal.name.english.isNotBlank());assertTrue(meal.foodIngredients.isNotEmpty());assertEquals("Original numbered steps for ${meal.id}",Regex("(?m)^\\d+[.)] ").findAll(meal.preparation.french).count(),RecipePreparation.steps(meal.preparation.french).size);assertTrue("Preparation for ${meal.id}",RecipePreparation.steps(meal.preparation.french).isNotEmpty());assertEquals(RecipePreparation.steps(meal.preparation.french).size,RecipePreparation.steps(meal.preparation.english).size)}
 }
 @Test fun beveragesStayOutOfFoodAndQuantitiesAreNotDuplicated() {
  assertTrue(RecipeIngredient(RecipeCopy("Eau de coco","Coconut water"),RecipeCopy("200 ml","200 ml"),"Hydratation").isBeverage)
  assertFalse(RecipeIngredient(RecipeCopy("Pastèque","Watermelon"),RecipeCopy("200 g","200 g"),"Glucide").isBeverage)
  assertEquals("3 œufs",RecipeIngredient(RecipeCopy("3 œufs","3 eggs"),RecipeCopy("3","3"),"Protéine").displayLine(false))
 }
 @Test fun preparationKeepsCookingRangesAndRejectsJsonPayloads() {
  assertEquals(listOf("Cuire 4–5 min.","Servir chaud."),RecipePreparation.steps("1. Cuire 4–5 min\n2. Servir chaud"))
  assertTrue(RecipePreparation.steps("{\"steps\":[]}").isEmpty())
 }
}
