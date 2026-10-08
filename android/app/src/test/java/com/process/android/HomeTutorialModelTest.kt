package com.process.android
import org.junit.Test
import org.junit.Assert.*
class HomeTutorialModelTest {
 @Test fun noMissingPlanOrSuppressedPreviewCanStart(){val p=HomeTutorialProgress();assertFalse(p.begin(false,false).active);assertFalse(p.begin(true,true).active);assertTrue(p.begin(true,false).active);assertFalse(HomeTutorialProgress(completed=true).begin(true,false).active)}
 @Test fun fiveStepOrderAndExitAreDeterministic(){var p=HomeTutorialProgress().begin(true,false);val seen=mutableListOf<HomeTutorialStep>();repeat(5){seen+=p.step;p=p.advance()};assertEquals(HomeTutorialStep.entries,seen);assertTrue(p.completed);assertFalse(p.active);assertEquals(p,p.advance());assertEquals(p,p.begin(true,false))}
 @Test fun hydrationHidesMealsWhileRetainingNutritionSection(){val p=HomeTutorialProgress().begin(true,false).advance();assertEquals(HomeTutorialStep.HYDRATION,p.step);assertFalse(p.showsMealCards());assertTrue(p.showsMealCards(false));assertTrue(p.showsSection(HomeTutorialStep.NUTRITION));assertFalse(p.showsSection(HomeTutorialStep.ROUTINE));assertTrue(p.shouldScrollVertically);assertFalse(p.advance().shouldScrollVertically)}
 @Test fun profileStepDoesNotConstrainHomeAndSkipDoesNotRequestHomeNavigation(){val p=HomeTutorialProgress(true,4);assertEquals("profile",p.step.requestedTab);assertFalse(p.constrainsHome(true,false));assertTrue(p.showsSection(HomeTutorialStep.ROUTINE));assertFalse(p.finish().active)}
}
