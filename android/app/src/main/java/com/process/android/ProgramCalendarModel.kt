package com.process.android

import java.time.*
import java.time.temporal.ChronoUnit

enum class CalendarDayVerdict { EXCELLENT, ON_TRACK, PARTIAL, REGRESSION, PENDING, MISSED, PAUSED }
enum class CalendarDayStatus { OUTSIDE_PLAN, FUTURE, TODAY, VALIDATED, PARTIAL, MISSED }
data class CalendarProgramDay(val title:String="",val phaseTitle:String="")
data class ProgramCalendarPlan(val startedOn:LocalDate,val days:List<CalendarProgramDay>) {
    val lastDay:LocalDate get()=startedOn.plusDays((days.size-1).coerceAtLeast(0).toLong())
}
data class CalendarDayRecord(val date:LocalDate,val hasScan:Boolean=false,val checkInSubmitted:Boolean=false,val compositeScore:Double=0.0,val verdict:CalendarDayVerdict=CalendarDayVerdict.PENDING)
data class CalendarScan(val id:String,val createdAt:Instant,val thumbnailUri:String?,val scale:Float=1f,val offsetX:Float=0f,val offsetY:Float=0f)
data class ProgramCalendarDayModel(val date:LocalDate,val number:Int?,val programDay:CalendarProgramDay?,val isTarget:Boolean,val status:CalendarDayStatus,val record:CalendarDayRecord?,val scan:CalendarScan?)

object ProgramCalendarModel {
    /** Monday-first compact full-week grid, including neighboring-month cells. */
    fun grid(month:YearMonth):List<LocalDate> {
        val start=month.atDay(1);val leading=start.dayOfWeek.value-1
        val count=((leading+month.lengthOfMonth()+6)/7)*7
        return List(count) {start.minusDays(leading.toLong()).plusDays(it.toLong())}
    }
    fun day(date:LocalDate,today:LocalDate,plan:ProgramCalendarPlan,records:List<CalendarDayRecord>,scans:List<CalendarScan>,zone:ZoneId):ProgramCalendarDayModel {
        val index=ChronoUnit.DAYS.between(plan.startedOn,date).toInt()
        val programDay=plan.days.getOrNull(index);val record=records.firstOrNull {it.date==date}
        val status=when {
            date>today->CalendarDayStatus.FUTURE // The live presenter checks future before plan membership.
            programDay==null->CalendarDayStatus.OUTSIDE_PLAN
            record?.hasScan==true->CalendarDayStatus.VALIDATED
            date==today->CalendarDayStatus.TODAY
            record?.checkInSubmitted==true->CalendarDayStatus.PARTIAL
            else->CalendarDayStatus.MISSED
        }
        val latest=scans.filter {it.createdAt.atZone(zone).toLocalDate()==date}.maxByOrNull {it.createdAt}
        return ProgramCalendarDayModel(date,if(programDay!=null)index+1 else null,programDay,programDay!=null&&index==plan.days.lastIndex,status,record,latest?.takeIf {!it.thumbnailUri.isNullOrBlank()})
    }
    fun preferredToday(today:LocalDate,plan:ProgramCalendarPlan)=if(plan.days.isEmpty())today else today.coerceIn(plan.startedOn,plan.lastDay)
    fun canShift(month:YearMonth,delta:Int,plan:ProgramCalendarPlan):Boolean {
        if(plan.days.isEmpty())return true
        val next=month.plusMonths(delta.toLong())
        return if(delta<0)next.atEndOfMonth()>=plan.startedOn else next.atDay(1)<=plan.lastDay
    }
    fun scansInMonth(month:YearMonth,scans:List<CalendarScan>,zone:ZoneId)=scans.count {YearMonth.from(it.createdAt.atZone(zone))==month}
    fun bestDay(records:List<CalendarDayRecord>)=records.filter {it.checkInSubmitted&&it.compositeScore.isFinite()}.maxByOrNull {it.compositeScore}?.date
    fun missedDays(records:List<CalendarDayRecord>)=records.count {it.verdict==CalendarDayVerdict.MISSED}
}
