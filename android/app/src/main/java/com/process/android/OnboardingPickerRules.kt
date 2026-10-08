package com.process.android

import kotlin.math.abs
import kotlin.math.roundToInt

enum class ProcessHeightUnit { CM, FT }

/** Geometry and range contracts from AgeWheelPicker.swift and HeightStepView.swift. */
object OnboardingPickerRules {
    const val MIN_AGE = 13
    const val MAX_AGE = 100
    const val DEFAULT_AGE = 25
    const val MIN_HEIGHT = 140
    const val MAX_HEIGHT = 220
    const val DEFAULT_HEIGHT = 170
    const val AGE_SAVE_DELAY_MS = 500L
    const val HEIGHT_SAVE_DELAY_MS = 300L
    fun initialAge(value: Int) = value.takeIf { it in MIN_AGE..MAX_AGE } ?: DEFAULT_AGE
    fun initialHeight(value: Double, profileHeight: Double? = null): Int {
        val candidate = value.takeIf { it.isFinite() && it > 0 }
            ?: profileHeight?.takeIf { it.isFinite() && it > 0 } ?: DEFAULT_HEIGHT.toDouble()
        return candidate.coerceIn(MIN_HEIGHT.toDouble(), MAX_HEIGHT.toDouble()).roundToInt()
    }
    fun heightForIndex(index: Int) = MIN_HEIGHT + index.coerceIn(0, MAX_HEIGHT - MIN_HEIGHT)
    fun heightLabel(cm: Int, unit: ProcessHeightUnit): String {
        if (unit == ProcessHeightUnit.CM) return cm.toString()
        val inches = (cm / 2.54).roundToInt()
        return "${inches / 12}'${inches % 12}\""
    }
    data class WheelTransform(val scale: Float, val alpha: Float)
    fun ageTransform(distance: Float): WheelTransform {
        val near = abs(distance).coerceAtMost(1f)
        val far = (abs(distance) - 1f).coerceIn(0f, 1.5f) / 1.5f
        return WheelTransform(1f - near * .44f - far * .16f, 1f - near * .5f - far * .3f)
    }
}
