package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ProcessRoutineCatalogTest {
 @Test fun importedOrderDurationAndMediaStayAligned() {val steps=ProcessRoutineCatalog.steps;assertEquals(6,steps.size);assertEquals(280,ProcessRoutineCatalog.fullSessionSeconds);assertEquals(listOf("lymph_01","lymph_02","lymph_03","lymph_05","lymph_06","lymph_07"),steps.map {it.videoResource});assertEquals((1..6).toList(),steps.map {it.number});assertEquals(6,steps.map {it.id}.distinct().size);assertTrue(steps.all {it.instructions.size==3&&it.benefits.size==4})}
 @Test fun bothLanguagesAndSourceDurationBadgesArePresent() {val steps=ProcessRoutineCatalog.steps;assertEquals(listOf("1 min","1 min","55 s","30 s","30 s","45 s"),steps.map {it.durationLabel});assertEquals("Sauts sur place",steps.first().title(false));assertEquals("Jumping in place",steps.first().title(true));assertTrue(steps.all {s->s.instructions.all {it.first.isNotBlank()&&it.second.isNotBlank()}&&s.benefits.all {it.first.isNotBlank()&&it.second.isNotBlank()}})}
}
