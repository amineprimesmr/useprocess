package com.process.android
import org.junit.Assert.*
import org.junit.Test
class CommitSliderModelTest {
    @Test fun reachingThresholdRequiresReleaseAndCommitsOnlyOnce() {
        val m=CommitSliderModel();m.drag(92f,100f);assertFalse(m.committed);assertTrue(m.release());assertEquals(1f,m.progress,0f);assertFalse(m.release());assertFalse(m.activate())
    }
    @Test fun underThresholdAndCancelledDragsResetWithoutCommit() {
        val m=CommitSliderModel();m.drag(91.9f,100f);assertFalse(m.release());assertEquals(0f,m.progress,0f)
        m.drag(100f,100f);m.cancel();assertFalse(m.committed);assertEquals(0f,m.progress,0f)
    }
    @Test fun invalidBoundsAndReverseDragsCannotCorruptProgress() {
        val m=CommitSliderModel();m.drag(Float.NaN,100f);assertEquals(0f,m.progress,0f);m.drag(50f,0f);assertEquals(0f,m.progress,0f)
        m.drag(-20f,100f);assertEquals(0f,m.progress,0f);m.drag(200f,100f);assertEquals(1f,m.progress,0f)
    }
    @Test fun hapticBucketsAdvanceOnlyAndAccessibleActivationReachesFinalTitle() {
        val m=CommitSliderModel();assertNull(m.drag(10f,100f));assertEquals(2,m.drag(20f,100f));assertNull(m.drag(21f,100f));assertNull(m.drag(15f,100f));assertEquals(8,m.drag(80f,100f))
        assertTrue(m.activate());assertEquals(1f,m.titleReveal(),0f)
    }
}
