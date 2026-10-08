package com.process.android

import kotlin.math.*
import kotlin.random.Random

/** Original OnboardingProgramCreationViewModel curves, with reproducible RNG for verification. */
object ProgramCreationModel {
    const val START_DELAY = 180L
    data class Milestone(val value: Double, val delayMillis: Long, val animationMillis: Int)
    enum class Badge { SCIENCE, PROGRAM, DOWNLOAD }
    fun badge(percentage: Int) = if(percentage>=72) Badge.DOWNLOAD else if(percentage>=58) Badge.PROGRAM else Badge.SCIENCE
    fun milestones(phase: Int, random: Random = Random.Default): List<Milestone> {
        require(phase in 0..2)
        val count=13+phase
        var previous=0.0
        return (1..count).map { step ->
            val t=step.toDouble()/count
            val base=if(t<.5)2*t*t else 1-(-2*t+2).pow(2)/2
            val wave=sin(t*PI*(1.8+(phase+1)*.2))*.018
            val value=max(previous,(base+wave).coerceIn(0.0,1.0));previous=value
            Milestone(value,random.nextLong(88,151)*(if(step%7==0)2 else 1),random.nextInt(340,541))
        }+Milestone(1.0,200,400)
    }
    data class Progress(val bars: List<Float>,val percentage:Int,val visibleCount:Int)
    fun progress(phase:Int,value:Double):Progress {
        require(phase in 0..2)
        val v=if(value.isFinite())value.coerceIn(0.0,1.0) else 0.0
        val complete=phase==2 && v>=1
        return Progress(List(3) { if(it<phase || complete)1f else if(it==phase)v.toFloat() else 0f },
            if(complete)100 else floor((phase+v)*100/3+.5).toInt().coerceAtMost(99),phase+1)
    }
    data class Confetti(val xRatio:Float,val delay:Float,val duration:Float,val colorIndex:Int,val opacity:Float,val width:Float,val height:Float,val spin:Float)
    fun confetti(random:Random=Random.Default):List<Confetti> = List(52) { i ->
        fun range(a:Float,b:Float)=a+random.nextFloat()*(b-a)
        Confetti(range(.04f,.96f),i*.045f+range(0f,.35f),range(2.8f,4.6f),i%5,range(.55f,.9f),range(7f,12f),range(14f,22f),range(-220f,220f))
    }
}
