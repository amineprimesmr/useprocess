package com.process.android

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.*

data class ProcessEstimationContext(val age:Int,val heightCm:Double?,val weightKg:Double?,val idealWeightKg:Double?=null,val hasWeightGoal:Boolean=false,val sports:Set<String> = emptySet(),val experience:String?=null,val trainingFrequency:String?=null)
data class ProcessEstimationFrame(val date:LocalDate,val unlockProgress:Float,val finished:Boolean)
object ProcessEstimationModel {
    /** The live screen labels this a routine check-in, never a guaranteed appearance prediction. */
    fun checkInDays(context:ProcessEstimationContext):Int {
        val bmi=if(context.heightCm!=null&&context.heightCm>0&&context.weightKg!=null&&context.weightKg>0&&context.heightCm.isFinite()&&context.weightKg.isFinite())context.weightKg/(context.heightCm/100).pow(2) else null
        val lean=(bmi?:25.0)<24.5
        val sporty=context.sports.isNotEmpty()||context.experience in setOf("intermediaire","amateur","professionnel")||context.trainingFrequency in setOf("3-5","6+")
        val gap=if(context.hasWeightGoal&&context.weightKg!=null&&context.idealWeightKg!=null)abs(context.weightKg-context.idealWeightKg).takeIf {it.isFinite()&&it>=.5} else null
        var days=when {lean&&sporty->10;sporty&&(gap?:99.0)<=10->14;lean->14;(bmi?:25.0)>=29->24;else->18}
        if(context.age<=22)days=max(10,days-3) else if(context.age<=28)days=max(10,days-2)
        if(sporty)days=max(10,days-2)
        return days.coerceIn(10,28) // Original onboarding uses default habitSeverity30; cap >=49 never binds here.
    }
    fun frame(now:LocalDate,finalDate:LocalDate,elapsedMs:Long):ProcessEstimationFrame {
        val difference=max(1,ChronoUnit.DAYS.between(now,finalDate).toInt())
        val overshoot=max(difference+7,ceil(difference*1.15).toInt())
        val start=now.plusDays(overshoot.toLong())
        if(elapsedMs<300)return ProcessEstimationFrame(finalDate,0f,false) // Original first displays the hydrated final date.
        val progress=((elapsedMs-300)/2200.0).coerceIn(0.0,1.0)
        if(progress>=1)return ProcessEstimationFrame(finalDate,1f,true)
        val delta=ChronoUnit.DAYS.between(start,finalDate)
        val moved=floor(abs(delta)*progress+.5).toLong() // Swift round is half-away-from-zero.
        return ProcessEstimationFrame(start.plusDays(moved*if(delta>=0)1 else -1),(1-(1-progress).pow(3)).toFloat(),false)
    }
}
