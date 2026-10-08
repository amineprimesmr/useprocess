package com.process.android

import java.text.Normalizer
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

enum class ProcessWeightUnit { KG, LBS }

/** Source contracts from FirstNameInputStepView, WeightStepView and OnboardingViewModel. */
object OnboardingInputRules {
    const val KG_PER_LB = .453592
    const val NAME_FOCUS_DELAY_MS = 620L
    const val WEIGHT_FOCUS_DELAY_MS = 140L
    fun trimName(value: String) = value.trim { it.isWhitespace() || Character.isSpaceChar(it) }
    fun isRealName(value: String): Boolean {
        val trimmed = trimName(value)
        return trimmed.isNotEmpty() && trimmed.lowercase(Locale.ROOT) !in setOf("process", "process ai", "utilisateur", "user", "local-user", "anonymous")
    }
    fun initialName(input: String, profileName: String?, authName: String?): String =
        listOfNotNull(input, profileName, authName).firstOrNull(::isRealName) ?: ""
    fun usernameBase(value: String): String = Normalizer.normalize(trimName(value).lowercase(Locale.ROOT), Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "").replace(" ", "").replace("-", "")
    fun plausibleWeight(kg: Double) = kg.isFinite() && kg >= 35.0 && kg <= 250.0
    fun normalizeWeight(raw: String): String {
        val result = StringBuilder()
        var separator = false
        raw.codePoints().forEach { code ->
            if (result.length < 5) {
                val number = Character.getNumericValue(code)
                if (number in 0..9) result.append(number)
                else if ((code == '.'.code || code == ','.code) && !separator) { result.append('.'); separator = true }
            }
        }
        return result.toString()
    }
    fun kilograms(text: String, unit: ProcessWeightUnit): Double =
        (text.toDoubleOrNull() ?: 0.0) * if (unit == ProcessWeightUnit.KG) 1.0 else KG_PER_LB
    fun displayWeight(kg: Double, unit: ProcessWeightUnit): String {
        if (kg <= 0 || !kg.isFinite()) return ""
        val value = if (unit == ProcessWeightUnit.KG) kg else kg / KG_PER_LB
        val rounded = value.roundToInt()
        return if (abs(value - rounded) < .01) rounded.toString() else String.format(Locale.US, "%.1f", value)
    }
}
