package com.process.android
import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test
class ProcessEstimationModelTest {
    @Test fun sourceProfileBranchesAndAgeBoundaries() {
        fun days(age:Int,weight:Double,sport:Boolean=false)=ProcessEstimationModel.checkInDays(ProcessEstimationContext(age,170.0,weight,sports=if(sport)setOf("run") else emptySet()))
        assertEquals(10,days(25,65.0,true));assertEquals(12,days(25,65.0));assertEquals(14,days(29,65.0));assertEquals(24,days(40,90.0));assertEquals(21,days(22,90.0))
    }
    @Test fun missingAndInvalidMeasurementsDoNotCreateNaNOrShortCircuitTheSourceFallback() {
        assertEquals(16,ProcessEstimationModel.checkInDays(ProcessEstimationContext(25,null,null)))
        assertEquals(18,ProcessEstimationModel.checkInDays(ProcessEstimationContext(40,Double.NaN,Double.POSITIVE_INFINITY)))
    }
    @Test fun dateRolloversAndExactUnlockTiming() {
        val now=LocalDate.of(2026,12,28);val end=now.plusDays(14)
        assertEquals(end,ProcessEstimationModel.frame(now,end,0).date)
        assertEquals(now.plusDays(21),ProcessEstimationModel.frame(now,end,300).date)
        assertFalse(ProcessEstimationModel.frame(now,end,2499).finished)
        assertEquals(ProcessEstimationFrame(end,1f,true),ProcessEstimationModel.frame(now,end,2500))
        assertEquals(ProcessEstimationFrame(end,1f,true),ProcessEstimationModel.frame(now,end,7000))
    }
    @Test fun unlockCurveIsEasedButDateCountdownRemainsLinear() {
        val now=LocalDate.of(2026,10,8);val end=now.plusDays(14);val frame=ProcessEstimationModel.frame(now,end,1400)
        assertEquals(.875f,frame.unlockProgress,0f);assertEquals(now.plusDays(17),frame.date)
    }
}
