package com.tenkdesign.android

/** Native adaptation of Balaji Venkatesh's AnimatedStateButton, 18 March 2025. */
object AsyncButtonModel {
    const val pressDurationMillis = 200
    const val transitionDurationMillis = 250
    const val firstPhaseMillis = 3_000L
    const val secondPhaseMillis = 3_000L
    const val resultPhaseMillis = 1_000L

    enum class DemoPhase { IDLE, ANALYZING, PROCESSING, FAILED }
    fun demoPhase(elapsedMillis: Long): DemoPhase = when {
        elapsedMillis < 0 -> DemoPhase.IDLE
        elapsedMillis < firstPhaseMillis -> DemoPhase.ANALYZING
        elapsedMillis < firstPhaseMillis + secondPhaseMillis -> DemoPhase.PROCESSING
        elapsedMillis < firstPhaseMillis + secondPhaseMillis + resultPhaseMillis -> DemoPhase.FAILED
        else -> DemoPhase.IDLE
    }

    /** Swift speed(1.2) applies to each animation's duration; extra rotation starts after its delay. */
    fun spinnerDegrees(elapsedMillis: Long): Float {
        val seconds = elapsedMillis.coerceAtLeast(0) / 1_000.0
        val primary = seconds / (0.7 / 1.2) * 360.0
        val extra = (seconds - 1.0).coerceAtLeast(0.0) / (1.0 / 1.2) * 360.0
        return ((primary + extra) % 360.0).toFloat()
    }
}
