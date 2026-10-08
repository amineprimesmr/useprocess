package com.process.android
import java.time.*
import org.junit.Test
import org.junit.Assert.*
class ProcessHomeModelTest {
 private val day=LocalDate.of(2026,10,8)
 @Test fun homeClampsDateAndFutureWinsOverOutsidePlan(){val plan=HomePlanCalendar("p",day,7);assertEquals(day,plan.preferredDate(day.minusDays(1)));assertEquals(day.plusDays(6),plan.preferredDate(day.plusDays(30)));assertEquals(HomeDayAvailability.FUTURE,plan.availability(day.plusDays(30),day));assertEquals(HomeDayAvailability.OUTSIDE_PLAN,plan.availability(day.minusDays(1),day))}
 @Test fun progressCountsSourceFirstDayAsElapsed(){val plan=HomePlanCalendar("p",day,7);assertEquals(6,plan.remainingDays(day));assertEquals(1f/7,plan.progress(day),.00001f);assertEquals(0,plan.remainingDays(day.plusDays(7)))}
 @Test fun scanUnlockUsesLocalSixAmAndCalendarDst(){val zone=ZoneId.of("Europe/Paris");val last=ZonedDateTime.of(2026,10,24,8,0,0,0,zone).toInstant();val unlock=ZonedDateTime.of(2026,10,25,6,0,0,0,zone).toInstant();assertEquals(unlock,HomeScanCadence.next(last,zone));assertFalse(HomeScanCadence.due(last,unlock.minusSeconds(1),zone));assertTrue(HomeScanCadence.due(last,unlock,zone));assertEquals(1f,HomeScanCadence.progress(last,unlock,zone),0f)}
 @Test fun sameDayAndFutureScanNeverUnlock(){val zone=ZoneId.of("UTC");val now=Instant.parse("2026-10-08T15:00:00Z");assertFalse(HomeScanCadence.due(now.minusSeconds(60),now,zone));assertFalse(HomeScanCadence.due(now.plusSeconds(86400),now,zone));assertTrue(HomeScanCadence.due(null,now,zone))}
 @Test fun explicitLocalHydrationCanDecreaseAndHiddenTrainingStaysExcluded(){val s=ProcessHomeSnapshot("u","",null,day,localWaterMl=250,healthWaterMl=1000,hasLocalWaterAdjustment=true,sectionOrder=HomeSection.entries,hiddenSections=setOf(HomeSection.NUTRITION));assertEquals(250,s.effectiveWaterMl);assertEquals(1000,s.copy(hasLocalWaterAdjustment=false).effectiveWaterMl);assertFalse(HomeSection.TRAINING in s.visibleSections);assertFalse(HomeSection.RESOURCES in s.visibleSections);assertTrue(HomeSection.NUTRITION in s.visibleSections)}
}
