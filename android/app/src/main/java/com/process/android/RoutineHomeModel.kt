package com.process.android

/** Day/account identity belongs in contextKey; every host write must recheck it. */
data class RoutineHomeDay(val contextKey:String,val editable:Boolean,val completedStepIds:Set<String> = emptySet(),val postureItems:List<RoutinePostureItem> = emptyList())
data class RoutinePostureItem(val id:String,val title:String,val detail:String,val badge:String?=null,val imageResource:Int?=null)
data class RoutineCompletion(val contextKey:String,val stepId:String)
object RoutineStepProgress {
    fun percent(steps:Int?):Int?=steps?.let {((it.coerceAtLeast(0).toLong()*100)/10000).coerceAtMost(100).toInt()}
    fun filledTicks(percent:Int?,count:Int):Int {
        if(percent==null||percent<=0||count<=0)return 0
        return ((count.toLong()*percent.coerceAtMost(100))/100).toInt().coerceIn(1,count)
    }
}
class RoutineHoldModel {
    private var start:Long?=null
    private var completed=false
    var progress:Float=0f;private set
    val holding get()=start!=null&&!completed
    fun begin(now:Long) {start=now;completed=false;progress=0f}
    fun tick(now:Long):Boolean {
        val began=start?:return false
        if(completed)return false
        progress=((now-began).coerceAtLeast(0)/5000f).coerceAtMost(1f)
        if(progress<1f)return false
        completed=true;return true
    }
    fun release(now:Long):Boolean {
        val short=start?.let {!completed&&(now-it) in 0..349}?:false
        cancel();return short
    }
    fun cancel(){start=null;completed=false;progress=0f}
}
