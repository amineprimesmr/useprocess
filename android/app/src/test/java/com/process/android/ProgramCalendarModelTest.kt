package com.process.android

import java.time.*
import org.junit.Assert.*
import org.junit.Test

class ProgramCalendarModelTest {
    private val start=LocalDate.of(2026,10,1)
    private val plan=ProgramCalendarPlan(start,List(21){CalendarProgramDay("Day ${it+1}")})
    private val zone=ZoneId.of("Europe/Paris")
    @Test fun mondayGridHandlesLeapDayAndFourFiveSixWeekMonths() {
        for(year in 2024..2027)for(month in 1..12) {
            val ym=YearMonth.of(year,month);val grid=ProgramCalendarModel.grid(ym)
            assertEquals(DayOfWeek.MONDAY,grid.first().dayOfWeek);assertEquals(DayOfWeek.SUNDAY,grid.last().dayOfWeek)
            assertEquals(ym.lengthOfMonth(),grid.count {YearMonth.from(it)==ym});assertTrue(grid.size in listOf(28,35,42));assertEquals(grid.size,grid.distinct().size)
        }
        assertTrue(LocalDate.of(2024,2,29) in ProgramCalendarModel.grid(YearMonth.of(2024,2)))
    }
    @Test fun futurePrecedesOutOfPlanAndTodayPrecedesPartial() {
        fun day(date:LocalDate,records:List<CalendarDayRecord> = emptyList())=ProgramCalendarModel.day(date,start.plusDays(7),plan,records,emptyList(),zone)
        assertEquals(CalendarDayStatus.FUTURE,day(start.plusDays(40)).status)
        assertEquals(CalendarDayStatus.OUTSIDE_PLAN,day(start.minusDays(1)).status)
        assertEquals(CalendarDayStatus.TODAY,day(start.plusDays(7),listOf(CalendarDayRecord(start.plusDays(7),checkInSubmitted=true))).status)
        assertEquals(CalendarDayStatus.PARTIAL,day(start,listOf(CalendarDayRecord(start,checkInSubmitted=true))).status)
        assertEquals(CalendarDayStatus.VALIDATED,day(start,listOf(CalendarDayRecord(start,hasScan=true))).status)
    }
    @Test fun scanGroupingUsesLocalCalendarDateAcrossDST() {
        val scan=CalendarScan("s",Instant.parse("2026-10-24T22:30:00Z"),"content://local/photo")
        val date=LocalDate.of(2026,10,25)
        assertEquals(scan,ProgramCalendarModel.day(date,date,plan,emptyList(),listOf(scan),zone).scan)
        assertEquals(1,ProgramCalendarModel.scansInMonth(YearMonth.of(2026,10),listOf(scan),zone))
    }
    @Test fun newestMissingThumbnailDoesNotSilentlyShowAnOlderScan() {
        val a=CalendarScan("a",Instant.parse("2026-10-01T10:00:00Z"),"content://a")
        val b=CalendarScan("b",a.createdAt.plusSeconds(60),null)
        assertNull(ProgramCalendarModel.day(start,start,plan,emptyList(),listOf(a,b),zone).scan)
    }
    @Test fun monthLimitsTodayClampAndStatisticsUseWholeHistory() {
        assertFalse(ProgramCalendarModel.canShift(YearMonth.of(2026,10),-1,plan));assertFalse(ProgramCalendarModel.canShift(YearMonth.of(2026,10),1,plan))
        assertEquals(plan.lastDay,ProgramCalendarModel.preferredToday(start.plusDays(90),plan));assertEquals(start,ProgramCalendarModel.preferredToday(start.minusDays(20),plan))
        val records=listOf(CalendarDayRecord(start,true,true,20.0),CalendarDayRecord(start.plusDays(1),true,true,30.0),CalendarDayRecord(start.plusDays(2),false,false,99.0,CalendarDayVerdict.MISSED))
        assertEquals(start.plusDays(1),ProgramCalendarModel.bestDay(records));assertEquals(1,ProgramCalendarModel.missedDays(records))
    }
}
