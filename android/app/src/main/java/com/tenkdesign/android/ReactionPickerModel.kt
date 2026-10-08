package com.tenkdesign.android

import kotlin.math.min

/** AMReactionView source: Balaji Venkatesh, 22 August 2026. */
object ReactionPickerModel {
    fun limited(reactions: List<String>, insertButton: Boolean): List<String> = reactions.take(if (insertButton) 5 else 6)
    // Original sleeps inside a loop: delays accumulate, rather than equal linear staggering.
    fun revealMillis(index: Int, forcePopover: Boolean): Long {
        val i = index.coerceAtLeast(0).toLong()
        return (if (forcePopover) 80L else 150L) + i * (i + 1) / 2 * (if (forcePopover) 20L else 30L)
    }
    data class Particle(val opacity: Float, val scale: Float, val x: Float, val y: Float)
    fun particle(index: Int, elapsedMillis: Long, fontSize: Float): Particle {
        val progress = (elapsedMillis.coerceAtLeast(0) / 2300f * 8f).coerceAtMost(8f)
        val current = (progress - index).coerceIn(0f, 4f)
        return Particle(1f - (current - 3).coerceAtLeast(0f), min(current / .5f,1f),
            (if (index % 2 == 0) -1 else 1) * fontSize / 2, -fontSize - current * 35f)
    }
}
