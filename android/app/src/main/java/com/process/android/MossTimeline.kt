package com.process.android

import java.text.BreakIterator
import java.util.Locale

enum class MossSender { MOSS, USER }
data class MossLine(val id:String,val text:String,val explanatory:Boolean=false,val emotional:Boolean=false)
data class MossMessage(val id:String,val text:String,val sender:MossSender,val visibleEnd:Int,val done:Boolean)
data class MossPulse(val glyph:String?=null,val emotional:Boolean=false)

/** Clock-driven port: one deterministic pump, no delayed callback can outlive reset/rewind. */
class MossTimeline {
    private enum class Phase { LEAD, TYPE, BREATH }
    private val history=mutableListOf<MossMessage>()
    private val queue=ArrayDeque<MossLine>()
    private var phase=Phase.LEAD
    private var deadline=0L
    private var active:MossLine?=null
    private var glyphs=listOf<String>()
    private var position=0
    var isTyping=false;private set
    var controlsVisible=false;private set
    val messages:List<MossMessage> get()=history.toList()

    fun speak(lines:List<MossLine>,nowMs:Long,instant:Boolean=false) {
        if(lines.isEmpty()) {if(!isTyping)controlsVisible=true;return}
        if(instant) {
            completeBatch()
            history.addAll(lines.map {MossMessage(it.id,it.text,MossSender.MOSS,it.text.length,true)})
            controlsVisible=true;return
        }
        queue.addAll(lines);controlsVisible=false
        if(!isTyping) {
            deadline=nowMs+if(history.lastOrNull()?.sender==MossSender.USER)140L else 0L
            phase=Phase.LEAD;isTyping=true
        }
    }
    fun userReplied(text:String) {
        if(text.isEmpty())return
        history.add(MossMessage("user.${history.size}",text,MossSender.USER,text.length,true))
    }
    /** Absolute deadlines catch up after dropped frames without extending authored punctuation pauses. */
    fun advance(nowMs:Long):List<MossPulse> {
        val pulses=mutableListOf<MossPulse>()
        while(isTyping && nowMs>=deadline) {
            when(phase) {
                Phase.LEAD,Phase.BREATH -> {
                    if(queue.isEmpty()) {finish();break}
                    val line=queue.removeFirst();active=line;glyphs=graphemes(line.text);position=0
                    history.add(MossMessage(line.id,line.text,MossSender.MOSS,0,false));phase=Phase.TYPE
                }
                Phase.TYPE -> {
                    if(position<glyphs.size) {
                        val glyph=glyphs[position++]
                        val last=history.last();history[history.lastIndex]=last.copy(visibleEnd=last.visibleEnd+glyph.length)
                        if(glyph.any { !it.isWhitespace() })pulses.add(MossPulse(glyph))
                        deadline+=glyphDelay(glyph,active!!.explanatory)
                    } else {
                        val last=history.last();history[history.lastIndex]=last.copy(done=true)
                        pulses.add(MossPulse(emotional=active!!.emotional))
                        deadline+=if(active!!.emotional)320L else 165L;phase=Phase.BREATH
                    }
                }
            }
        }
        return pulses
    }
    /** The same tap only reveals the batch; callers must never forward it to newly shown controls. */
    fun completeBatch():Boolean {
        if(!isTyping)return false
        finishActive()
        while(queue.isNotEmpty()) {val line=queue.removeFirst();history.add(MossMessage(line.id,line.text,MossSender.MOSS,line.text.length,true))}
        finish();return true
    }
    fun stopSpeaking() {finishActive();queue.clear();finish()}
    fun reset() {queue.clear();history.clear();active=null;glyphs=emptyList();position=0;isTyping=false;controlsVisible=false;deadline=0;phase=Phase.LEAD}
    private fun finishActive() {
        if(history.lastOrNull()?.done==false) {val last=history.last();history[history.lastIndex]=last.copy(visibleEnd=last.text.length,done=true)}
    }
    private fun finish() {isTyping=false;controlsVisible=true;active=null}
    companion object {
        fun graphemes(text:String):List<String> {
            val iterator=BreakIterator.getCharacterInstance(Locale.ROOT);iterator.setText(text)
            val result=mutableListOf<String>();var start=iterator.first();var end=iterator.next()
            while(end!=BreakIterator.DONE) {result.add(text.substring(start,end));start=end;end=iterator.next()}
            return result
        }
        fun glyphDelay(glyph:String,explanatory:Boolean=false):Long = (if(explanatory)14L else 18L)+when(glyph) {
            ","->26L;".","?","!"->58L;"\n"->115L;else->0L
        }
    }
}
