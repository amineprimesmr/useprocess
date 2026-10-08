package com.process.android

/** Monotonic-time hold contract; release/pause resets an unfinished gesture. */
class CommitHoldModel {
    var pressed=false;private set
    var completed=false;private set
    var progress=0f;private set
    private var start=0L
    private val milestones=mutableSetOf<Int>()
    fun press(nowMs:Long):Boolean {
        if(pressed||completed)return false
        pressed=true;start=nowMs;progress=0f;milestones.clear();return true
    }
    fun tick(nowMs:Long):List<Int> {
        if(!pressed||completed)return emptyList()
        progress=((nowMs-start).coerceAtLeast(0)/4000f).coerceIn(0f,1f)
        val fired=(0..2).filter {fill(it)>=.92f&&milestones.add(it)}
        if(progress==1f){completed=true;pressed=false}
        return fired
    }
    fun fill(index:Int)=((progress-index/3f)*3).coerceIn(0f,1f)
    fun release():Float {
        val abandoned=if(pressed&&!completed)progress else 0f
        pressed=false;milestones.clear()
        if(!completed)progress=0f
        return abandoned
    }
    /** Equivalent to the original VoiceOver activate action; independent from biometric authentication. */
    fun activate():Boolean {
        if(completed)return false
        completed=true;pressed=false;progress=1f;return true
    }
}
