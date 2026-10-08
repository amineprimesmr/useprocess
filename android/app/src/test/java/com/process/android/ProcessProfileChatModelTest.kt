package com.process.android

import org.junit.Assert.*
import org.junit.Test

class ProcessProfileChatModelTest {
    private fun throughChoices():ProfileChatProgress {
        var p=ProfileChatProgress()
        for(q in ProcessProfileChatModel.questions("Amine")) {
            if(q.kind==ProfileChatKind.SUMMARY)break
            p=ProcessProfileChatModel.submit(p,q.id,q.choices.firstOrNull()?.id,trackingExplainerConfirmed=true)
        }
        return p
    }
    @Test fun cannotSkipQuestionsOrSubmitUnknownAnswersOrBypassExplainer() {
        var p=ProfileChatProgress();assertEquals(p,ProcessProfileChatModel.submit(p,"sleep_hours","4.5"))
        p=ProcessProfileChatModel.submit(p,"intro_swollen_face");p=ProcessProfileChatModel.submit(p,"intro_causes")
        assertEquals(p,ProcessProfileChatModel.submit(p,"intro_next"))
        p=ProcessProfileChatModel.submit(p,"intro_next",trackingExplainerConfirmed=true)
        assertEquals(p,ProcessProfileChatModel.submit(p,"debloat_driver","bogus"))
    }
    @Test fun localeSwitchPreservesIdsRawAnswersAndTranslatesReplay() {
        val fr=ProcessProfileChatModel.questions("Amine");val en=ProcessProfileChatModel.questions("Amine",true)
        assertEquals(fr.map{it.id},en.map{it.id});assertEquals(fr.flatMap{it.choices}.map{it.id},en.flatMap{it.choices}.map{it.id})
        val p=throughChoices();val q=en.first{it.id=="hydration_level"};assertEquals("Less than 1 L",ProcessProfileChatModel.answerDisplay(q,p))
        assertEquals("Mauvaise",p.answers["hydration_level"])
    }
    @Test fun profileSideEffectsMatchOriginalAndRewindRemovesStaleAnswer() {
        val p=throughChoices();val profile=ProcessProfileChatModel.profile(p)
        assertEquals(4.5,profile.sleepHours!!,0.0);assertEquals("Très mauvais",profile.sleepQuality)
        assertEquals(false,profile.sufficientHydration);assertEquals(false,profile.hasSportActivity)
        val back=ProcessProfileChatModel.rewind(p)!!;assertEquals("cardio_frequency",ProcessProfileChatModel.current(back))
        assertNull(ProcessProfileChatModel.profile(back).trainingFrequency);assertEquals(4.5,ProcessProfileChatModel.profile(back).sleepHours!!,0.0)
    }
    @Test fun oldSummaryIdMigratesButInvalidStoredAnswersCannotSkipAhead() {
        val p=throughChoices();val legacy=p.copy(completed=p.completed+"face_scan_offer")
        assertNull(ProcessProfileChatModel.current(ProcessProfileChatModel.normalize(legacy)))
        val corrupt=legacy.copy(answers=p.answers+("sleep_hours" to "invalid"))
        val safe=ProcessProfileChatModel.normalize(corrupt);assertEquals("sleep_hours",ProcessProfileChatModel.current(safe));assertFalse("cardio_frequency" in safe.completed)
    }
    @Test fun numberedQuestionsAndNamedIntroUseStableMessageIds() {
        val questions=ProcessProfileChatModel.questions("  Amine  ")
        assertTrue(questions.first().blocks.first().startsWith("Amine,"))
        assertFalse(ProcessProfileChatModel.questions("local-user").first().blocks.first().contains("local-user"))
        val q=questions.first{it.id=="hydration_level"};assertEquals("process.chat.hydration_level.0",q.lines(2).single().id);assertTrue(q.lines(2).single().text.endsWith("(2/5)"))
    }
}
