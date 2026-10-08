package com.process.android

import kotlin.random.Random
import org.junit.Assert.*
import org.junit.Test

class ProgramCreationModelTest {
    @Test fun irregularCurvesNeverReverseAndReachOne() {
        repeat(3) {phase ->
            val points=ProgramCreationModel.milestones(phase,Random(19))
            assertEquals(14+phase,points.size)
            assertEquals(1.0,points.last().value,0.0)
            assertTrue(points.zipWithNext().all { (a,b)->a.value<=b.value })
            points.dropLast(1).forEachIndexed { i,p ->
                assertTrue(p.delayMillis in (if((i+1)%7==0)176L..300L else 88L..150L))
                assertTrue(p.animationMillis in 340..540)
            }
        }
    }
    @Test fun phasesPreserveEarlierBarsAndDoNotPrematurelyShow100() {
        assertEquals(listOf(1f,.5f,0f),ProgramCreationModel.progress(1,.5).bars)
        assertEquals(50,ProgramCreationModel.progress(1,.5).percentage)
        assertEquals(99,ProgramCreationModel.progress(2,.999).percentage)
        assertEquals(100,ProgramCreationModel.progress(2,1.0).percentage)
        assertEquals(0,ProgramCreationModel.progress(0,Double.NaN).percentage)
    }
    @Test fun badgeThresholdsMatchSource() {
        assertEquals(ProgramCreationModel.Badge.SCIENCE,ProgramCreationModel.badge(57))
        assertEquals(ProgramCreationModel.Badge.PROGRAM,ProgramCreationModel.badge(58))
        assertEquals(ProgramCreationModel.Badge.DOWNLOAD,ProgramCreationModel.badge(72))
    }
    @Test fun confettiKeepsOriginalCountAndBounds() {
        val pieces=ProgramCreationModel.confetti(Random(7));assertEquals(52,pieces.size)
        pieces.forEach {p->assertTrue(p.xRatio in .04f.. .96f);assertTrue(p.duration in 2.8f..4.6f);assertTrue(p.spin in -220f..220f)}
    }
}
