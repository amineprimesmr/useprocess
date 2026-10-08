package com.process.android
import org.junit.Test
import org.junit.Assert.*
class SwipeActionsModelTest {
 @Test fun clampsOffsetAndAppliesOnlyTrailingResistance() {assertEquals(SwipeActionsPosition(-165f,-3.5f,1f),swipeActionsPosition(0f,-200f,165f));swipeActionsPosition(0f,100f,165f).let {assertEquals(0f,it.offset,0f);assertEquals(0f,it.bounce,0f);assertEquals(0f,it.progress,0f)};assertEquals(-65f,swipeActionsPosition(-165f,100f,165f).offset)}
 @Test fun thresholdIncludesSourceVelocityAndRejectsInvalidInputs() {assertFalse(swipeActionsShouldOpen(-99f,0f,165f));assertTrue(swipeActionsShouldOpen(-100f,0f,165f));assertTrue(swipeActionsShouldOpen(-10f,-100f,165f));assertFalse(swipeActionsShouldOpen(-165f,200f,165f));assertFalse(swipeActionsShouldOpen(Float.NaN,0f,165f));assertFalse(swipeActionsShouldOpen(-10f,0f,0f))}
}
