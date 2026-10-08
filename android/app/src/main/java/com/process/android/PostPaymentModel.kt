package com.process.android

/** The host must verify entitlement and finish account/profile migration before navigation. */
sealed interface ProcessAccountCompletion {
    data object Completed : ProcessAccountCompletion
    data object Cancelled : ProcessAccountCompletion
    data class Failed(val message: String) : ProcessAccountCompletion
}
class PostPaymentGate {
    var busy = false; private set
    var completed = false; private set
    fun begin(accessVerified: Boolean): Boolean {
        if (!accessVerified || busy || completed) return false
        busy = true
        return true
    }
    fun finish(result: ProcessAccountCompletion, accessStillVerified: Boolean): Boolean {
        if (!busy) return false
        busy = false
        completed = result == ProcessAccountCompletion.Completed && accessStillVerified
        return completed
    }
    fun cancel() { busy = false }
}
