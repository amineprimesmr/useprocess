package com.process.android

import org.junit.Assert.*
import org.junit.Test
class CommitHoldModelTest {
    @Test fun fourSecondsRequiredAndDroppedFramesStillFinishOnce() {
        val m=CommitHoldModel();assertTrue(m.press(100));assertFalse(m.press(200));m.tick(4099);assertFalse(m.completed)
        m.tick(4100);assertTrue(m.completed);assertEquals(1f,m.progress,0f);assertFalse(m.activate());assertFalse(m.press(5000));assertTrue(m.tick(9000).isEmpty())
    }
    @Test fun earlyReleaseAndPauseResetEveryCommitment() {
        val m=CommitHoldModel();m.press(0);m.tick(2500);assertTrue(m.fill(0)==1f);assertTrue(m.release()>.6f);assertEquals(0f,m.fill(0),0f)
        m.press(3000);m.tick(4000);assertEquals(.25f,m.progress,0f);assertFalse(m.completed)
    }
    @Test fun eachMilestoneFiresOnlyOnceEvenWhenFramesSkip() {
        val m=CommitHoldModel();m.press(0);assertEquals(listOf(0),m.tick(1230));assertTrue(m.tick(1300).isEmpty());assertEquals(listOf(1,2),m.tick(4000))
    }
    @Test fun accessibleActivationCompletesWithoutPretendingBiometricAuthentication() {
        val m=CommitHoldModel();assertTrue(m.activate());assertTrue(m.completed);assertEquals(1f,m.fill(2),.00001f);m.release();assertEquals(1f,m.progress,0f)
    }
}
