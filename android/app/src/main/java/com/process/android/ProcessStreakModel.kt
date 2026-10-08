package com.process.android

import java.time.LocalDate
import java.time.temporal.ChronoUnit

data class ProcessStreakDay(val date:LocalDate,val programDayNumber:Int,val complete:Boolean,val today:Boolean,val future:Boolean,val missed:Boolean)
data class ProcessStreakSummary(val current:Int,val longest:Int,val total:Int,val todayComplete:Boolean)

object ProcessStreakModel {
    /** Like the original, today may still be incomplete without breaking yesterday's streak. */
    fun current(submitted:Set<LocalDate>,today:LocalDate,paused:Set<LocalDate> = emptySet()):Int {
        var day=today
        if(day !in submitted) {
            day=day.minusDays(1)
            // The iOS pre-scan is unbounded; Android caps corrupt/all-paused input like the main loop.
            var safety=0
            while(day in paused&&safety++<400)day=day.minusDays(1)
            if(day !in submitted||safety>=400)return 0
        }
        return ending(day,submitted,paused)
    }
    fun ending(date:LocalDate,submitted:Set<LocalDate>,paused:Set<LocalDate> = emptySet()):Int {
        var day=date;var count=0
        repeat(400) {
            if(day !in paused) {if(day !in submitted)return count;count++}
            day=day.minusDays(1)
        }
        return count
    }
    fun launchCounts(current:Int,total:Int)=if(current==0&&total==0)1 to 1 else current to total
    fun week(today:LocalDate,plan:ProgramCalendarPlan?,records:List<CalendarDayRecord>,completed:Set<LocalDate>):List<ProcessStreakDay> {
        val monday=today.minusDays((today.dayOfWeek.value-1).toLong())
        return List(7) {offset->
            val date=monday.plusDays(offset.toLong());val done=date in completed||records.any {it.date==date&&it.hasScan};val future=date>today
            val index=plan?.let {ChronoUnit.DAYS.between(it.startedOn,date).toInt()}
            ProcessStreakDay(date,if(index!=null&&index in (plan?.days?.indices?:IntRange.EMPTY))index+1 else offset+1,done,date==today,future,!future&&date!=today&&!done&&(plan==null||date>=plan.startedOn))
        }
    }
    fun activeRange(days:List<ProcessStreakDay>):IntRange? {
        val today=days.indexOfFirst {it.today}
        if(today<0) {val last=days.indexOfLast {it.complete};return if(last<0)null else last..last}
        var start=today;var end=today
        while(start>0&&days[start-1].complete)start--
        while(end<days.lastIndex&&days[end+1].complete)end++
        return start..end
    }
    fun message(summary:ProcessStreakSummary,english:Boolean):Pair<String,String> {
        fun t(fr:String,en:String)=if(english)en else fr
        if(summary.todayComplete&&summary.current==0)return "✅" to t("Premier jour validé !","First day completed!")
        if(!summary.todayComplete)return (if(summary.current>0)"🔥" else "💪") to t("Fais ton scan pour valider aujourd'hui","Do your scan to complete today")
        return when(summary.current) {
            in 1..2->"🔥" to t("Belle régularité !","Great consistency!")
            in 3..6->"✨" to t("Tu construis l'habitude","You're building the habit")
            in 7..13->"😊" to t("Régularité incroyable !","Incredible consistency!")
            else->"🏆" to t("Mode Process activé","Process mode activated")
        }
    }
}
