package com.process.android

import org.junit.Assert.*
import org.junit.Test

class FoodCatalogModelTest {
    @Test fun preferenceTransitionsAreReversibleAndMutuallyExclusive() {
        val initial=FoodPreferenceState()
        val liked=initial.toggleLike("concombre")
        assertTrue("concombre" in liked.likedIDs)
        assertEquals(initial,liked.toggleLike("concombre"))
        val disliked=liked.toggleDislike("concombre")
        assertFalse("concombre" in disliked.likedIDs)
        assertTrue("concombre" in disliked.dislikedIDs)
        assertTrue(disliked.toggleLike("concombre").dislikedIDs.isEmpty())
        assertEquals(liked,liked.toggleAtHome("concombre").toggleAtHome("concombre"))
    }
    @Test fun storageScopesSeparateUsersAndKeepAnonymousStable() {
        assertNotEquals(FoodStorageScope.key("alice"),FoodStorageScope.key("bob"))
        assertEquals(FoodStorageScope.key(null),FoodStorageScope.key(""))
        assertEquals(FoodStorageScope.key("alice"),FoodStorageScope.key("alice"))
        assertFalse(FoodStorageScope.key("alice").contains("alice"))
    }
    @Test fun originalTierAndCategoryOrderingIsPreserved() {
        val sections=FoodCatalogModel.sections(setOf(FoodTier.hero,FoodTier.prefer))
        assertEquals(FoodCategory.legumes,sections.first().category)
        assertEquals("epinards",sections.first().foods.first().id)
        assertTrue(sections.flatMap { it.foods }.none { it.tier==FoodTier.avoid || it.tier==FoodTier.moderate })
        sections.forEach { section ->
            section.foods.zipWithNext().forEach { (a,b) -> assertTrue(a.tier.ordinal<b.tier.ordinal || (a.tier==b.tier && a.score>=b.score)) }
        }
    }
    @Test fun searchSupportsAccentTagsEnglishAndEmptyResults() {
        val all=FoodTier.entries.toSet()
        assertTrue(FoodCatalogModel.sections(all,"  ÉPINARDS  ").flatMap { it.foods }.any { it.id=="epinards" })
        assertTrue(FoodCatalogModel.sections(all,"high-K").flatMap { it.foods }.isNotEmpty())
        assertTrue(FoodCatalogModel.sections(all,"cucumber",true).flatMap { it.foods }.any { it.id=="concombre" })
        assertTrue(FoodCatalogModel.sections(all,"xx-nonexistent-xx").isEmpty())
    }
    @Test fun localizedFoodAndPortionCopyComesFromOriginalCatalog() {
        val cucumber=DebloatFoods.item("concombre")!!
        assertEquals("Cucumber",FoodCopy.name(cucumber,true))
        assertEquals("Concombre",FoodCopy.name(cucumber,false))
        assertEquals("6×1.5 L",FoodCopy.portion("6×1,5 L",true))
        assertTrue(FoodCopy.why(cucumber,true).isNotBlank())
    }
    @Test fun missingPreferenceIdsCannotInventFoods() {
        val state=FoodPreferenceState(likedIDs=setOf("not-in-catalog","concombre"))
        assertEquals(listOf("concombre"),state.likedFoods.map { it.id })
    }
    @Test fun shoppingDeduplicatesUncheckedEntriesButAllowsRepurchaseAfterChecking() {
        val food=DebloatFoods.item("concombre")!!
        val one=FoodShoppingPolicy.merge(emptyList(),food){"first"}
        assertEquals(one,FoodShoppingPolicy.merge(one,food){"second"})
        val checked=one.map {it.copy(checked=true)}
        val next=FoodShoppingPolicy.merge(checked,food){"second"}
        assertEquals(2,next.size)
        assertEquals("second",next.first().id)
        assertEquals("concombre",next.first().foodId)
    }
    @Test fun shoppingUsesAnAvailableSwapAndKeepsTheOriginalQuantity() {
        val avoid=DebloatFoods.all.first { it.tier==FoodTier.avoid && FoodCatalogModel.swaps(it).isNotEmpty() }
        val swap=FoodCatalogModel.swaps(avoid).first()
        val result=FoodShoppingPolicy.merge(emptyList(),avoid){"swap"}
        assertEquals(swap.id,result.single().foodId)
        assertEquals(avoid.portion ?: "1",result.single().quantity)
    }
    @Test fun shoppingKeepsOnlyNewestEightyEntries() {
        val existing=(0..79).map { FoodShoppingEntry("$it","concombre","1",true) }
        val updated=FoodShoppingPolicy.merge(existing,DebloatFoods.item("citron")!!){"new"}
        assertEquals(80,updated.size)
        assertEquals("new",updated.first().id)
        assertFalse(updated.any {it.id=="79"})
    }
}
