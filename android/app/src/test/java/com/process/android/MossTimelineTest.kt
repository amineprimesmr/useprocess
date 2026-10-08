package com.process.android

import org.junit.Assert.*
import org.junit.Test

class MossTimelineTest {
    @Test fun absolutePacingIncludesPunctuationAndFinalBreath() {
        val e=MossTimeline();e.speak(listOf(MossLine("a","A,!")),100)
        e.advance(100);assertEquals(1,e.messages.single().visibleEnd)
        e.advance(117);assertEquals(1,e.messages.single().visibleEnd)
        e.advance(118);assertEquals(2,e.messages.single().visibleEnd)
        e.advance(162);assertEquals(3,e.messages.single().visibleEnd)
        e.advance(238);assertTrue(e.messages.single().done);assertFalse(e.controlsVisible)
        e.advance(402);assertFalse(e.controlsVisible);e.advance(403);assertTrue(e.controlsVisible)
    }
    @Test fun droppedFramesCatchUpAndDoNotStretchTheScript() {
        val e=MossTimeline();e.speak(listOf(MossLine("a","AB",emotional=true),MossLine("b","C",explanatory=true)),0)
        e.advance(356);assertEquals(2,e.messages.size);assertEquals(1,e.messages.last().visibleEnd)
        e.advance(535);assertTrue(e.controlsVisible);assertFalse(e.isTyping)
    }
    @Test fun oneTapCompletesWholeBatchWithoutAddingUserAnswer() {
        val e=MossTimeline();e.speak(listOf(MossLine("a","Long question"),MossLine("b","Another question")),0)
        e.advance(18);assertTrue(e.completeBatch());assertFalse(e.completeBatch());e.advance(99999)
        assertEquals(2,e.messages.size);assertTrue(e.messages.all {it.done&&it.sender==MossSender.MOSS});assertTrue(e.controlsVisible)
    }
    @Test fun resetInvalidatesOldBatchBeforeRewindReplay() {
        val e=MossTimeline();e.speak(listOf(MossLine("old","Before reset")),0);e.advance(10);e.reset()
        e.speak(listOf(MossLine("new","Restored")),20,instant=true);e.advance(99999)
        assertEquals(listOf("new"),e.messages.map {it.id});assertTrue(e.messages.single().done)
    }
    @Test fun userReplyHas140msLeadInAndInstantResumeDoesNotReplay() {
        val e=MossTimeline();e.userReplied("Yes");e.speak(listOf(MossLine("a","Hi")),0)
        e.advance(139);assertEquals(1,e.messages.size);e.advance(140);assertEquals(1,e.messages.last().visibleEnd)
        e.stopSpeaking();e.speak(listOf(MossLine("b","Resume")),200,instant=true)
        assertEquals(3,e.messages.size);assertTrue(e.messages.all {it.done});assertTrue(e.controlsVisible)
    }
    @Test fun composedCharactersAndEmojiAreNeverHalfVisible() {
        val clusters=MossTimeline.graphemes("e\u0301🇫🇷👨‍👩‍👧‍👦👍🏽")
        assertEquals(listOf("e\u0301","🇫🇷","👨‍👩‍👧‍👦","👍🏽"),clusters)
        val e=MossTimeline();e.speak(listOf(MossLine("unicode",clusters.joinToString(""))),0);e.advance(0)
        assertEquals(2,e.messages.single().visibleEnd)
    }
}
