package com.process.android

import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class ProcessStreakModelTest {
    private val today=LocalDate.of(2026,10,8)
    @Test fun incompleteTodayKeepsYesterdayButMissingYesterdayBreaksTheStreak() {
        val days=setOf(today.minusDays(1),today.minusDays(2),today.minusDays(3))
        assertEquals(3,ProcessStreakModel.current(days,today))
        assertEquals(4,ProcessStreakModel.current(days+today,today))
        assertEquals(0,ProcessStreakModel.current(days-today.minusDays(1),today))
    }
    @Test fun pauseDaysBridgeWithoutAddingToCountAndCannotLoopForever() {
        val days=setOf(today.minusDays(2),today.minusDays(3))
        assertEquals(2,ProcessStreakModel.current(days,today,setOf(today.minusDays(1))))
        assertEquals(0,ProcessStreakModel.current(emptySet(),today,(1..500).map {today.minusDays(it.toLong())}.toSet()))
        assertEquals(400,ProcessStreakModel.current((0..500).map {today.minusDays(it.toLong())}.toSet(),today))
    }
    @Test fun initialDisplayPolicyDoesNotChangeRawCompletedDays() {
        assertEquals(1 to 1,ProcessStreakModel.launchCounts(0,0));assertEquals(0 to 5,ProcessStreakModel.launchCounts(0,5));assertEquals(3 to 8,ProcessStreakModel.launchCounts(3,8))
    }
    @Test fun programWeekUsesScansAndDoesNotMarkPreProgramDatesMissed() {
        val plan=ProgramCalendarPlan(today.minusDays(1),List(7){CalendarProgramDay()})
        val days=ProcessStreakModel.week(today,plan,listOf(CalendarDayRecord(today.minusDays(1),hasScan=true)),emptySet())
        assertEquals(7,days.size);assertEquals(1,days.first().date.dayOfWeek.value)
        assertFalse(days.first().missed);assertTrue(days[2].complete);assertTrue(days[3].today);assertEquals(2,days[3].programDayNumber)
        assertEquals(2..3,ProcessStreakModel.activeRange(days));assertTrue(days.last().future)
    }
    @Test fun consistencyCopyUsesCompletionBeforeThreshold() {
        assertTrue(ProcessStreakModel.message(ProcessStreakSummary(30,30,30,false),true).second.contains("scan"))
        assertEquals("✨",ProcessStreakModel.message(ProcessStreakSummary(3,3,3,true),false).first)
    }
}
