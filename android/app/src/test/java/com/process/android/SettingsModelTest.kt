package com.process.android
import org.junit.Test
import org.junit.Assert.*
class SettingsModelTest {
 @Test fun languageOrderAndNativeLabelsMatchSharedSource() {
  assertEquals(listOf("fr","en","ja","de","ko","es","pt-BR"),ProcessLanguage.entries.map {it.code})
  assertEquals("🇯🇵 日本語",ProcessLanguage.JAPANESE.label)
 }
 @Test fun deviceResolutionSkipsUnsupportedLanguagesAndNormalizesRegions() {
  assertEquals(ProcessLanguage.KOREAN,ProcessLanguage.resolve(listOf("ar-SA","ko_KR","fr-FR")))
  assertEquals(ProcessLanguage.PORTUGUESE_BRAZIL,ProcessLanguage.normalize("pt_PT"))
  assertEquals(ProcessLanguage.ENGLISH,ProcessLanguage.resolve(listOf("it-IT")))
 }
}
