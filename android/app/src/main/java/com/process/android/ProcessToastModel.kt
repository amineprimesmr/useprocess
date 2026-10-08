package com.process.android

import java.util.UUID

/** Source: DynamicIslandToastMessage and ScanCompletionToastPresenter. */
data class ProcessToastMessage(
    val title:String,
    val text:String,
    val streakBefore:Int?=null,
    val streakAfter:Int?=null,
    val streakProgress:Float?=null,
    val id:String=UUID.randomUUID().toString(),
) {
    companion object {
        fun scanCompleted(before:Int,after:Int,nextMilestoneDays:Int?,english:Boolean=false):ProcessToastMessage {
            val progress=if(nextMilestoneDays!=null && nextMilestoneDays>0) (after.toFloat()/nextMilestoneDays).coerceIn(0f,1f) else 1f
            val first=before==0 && after>0
            return ProcessToastMessage(if(english)"Scan saved" else "Scan enregistré",
                if(first){if(english)"First day of your streak!"else"Premier jour de ta série !"}else{if(english)"$after-day streak"else"$after jours de série d'affilée"},before,after,progress)
        }
    }
}

object ProcessToastTimeline {
    const val DISMISS_MILLIS=4500L
    const val COUNTER_DELAY=320L
    const val PROGRESS_DELAY=360L
    fun canDismiss(currentId:String?,scheduledId:String)=currentId==scheduledId
    fun displayedCounter(message:ProcessToastMessage,elapsedMillis:Long)=if(elapsedMillis>=COUNTER_DELAY)message.streakAfter ?: 0 else message.streakBefore ?: message.streakAfter ?: 0
    fun progress(message:ProcessToastMessage,elapsedMillis:Long)=if(elapsedMillis>=PROGRESS_DELAY)message.streakProgress?.coerceIn(0f,1f) ?: 0f else 0f
}
