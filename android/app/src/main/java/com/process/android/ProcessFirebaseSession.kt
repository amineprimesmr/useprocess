package com.process.android

import android.app.Activity
import com.google.android.gms.tasks.Task
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.OAuthProvider
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class ProcessIdentity(val uid:String,val displayName:String?,val email:String?)
class ProcessSessionChanged:IllegalStateException("Authentication changed during the request")

/** No automatic anonymous account and no sign-in until a user invokes the native provider flow. */
class ProcessFirebaseSession(private val auth:FirebaseAuth=FirebaseAuth.getInstance()) {
    @Volatile private var generation=0L
    @Volatile private var lastUid:String?=auth.currentUser?.uid
    private val listener=FirebaseAuth.AuthStateListener {current->
        val uid=current.currentUser?.uid
        if(uid!=lastUid){generation++;lastUid=uid}
    }
    init {auth.addAuthStateListener(listener)}
    val current:ProcessIdentity? get()=auth.currentUser?.takeUnless {it.isAnonymous}?.let {ProcessIdentity(it.uid,it.displayName,it.email)}
    val identities get()=callbackFlow {
        val observer=FirebaseAuth.AuthStateListener {trySend(current)}
        auth.addAuthStateListener(observer)
        awaitClose {auth.removeAuthStateListener(observer)}
    }
    data class Lease(val uid:String,val generation:Long)
    fun lease():Lease=Lease(current?.uid?:throw IllegalStateException("Sign in required"),generation)
    fun check(lease:Lease) {if(current?.uid!=lease.uid||generation!=lease.generation)throw ProcessSessionChanged()}
    suspend fun idToken():String {val lease=lease();val token=auth.currentUser!!.getIdToken(false).awaitProcess().token;check(lease);return requireNotNull(token)}
    /** Firebase owns nonce/state/redirect handling. Server Apple Service ID and SHA setup remain prerequisites. */
    suspend fun signInWithApple(activity:Activity,english:Boolean=false):ProcessIdentity {
        val provider=OAuthProvider.newBuilder("apple.com").setScopes(listOf("email","name")).addCustomParameter("locale",if(english)"en" else "fr").build()
        (auth.pendingAuthResult?:auth.startActivityForSignInWithProvider(activity,provider)).awaitProcess()
        return requireNotNull(current)
    }
    fun signOut() {generation++;auth.signOut();lastUid=null}
    fun close() {auth.removeAuthStateListener(listener)}
}

internal suspend fun <T> Task<T>.awaitProcess():T=suspendCancellableCoroutine {continuation->
    addOnCompleteListener {task->
        if(continuation.isActive) {
            if(task.isCanceled)continuation.cancel()
            else if(task.isSuccessful)continuation.resume(task.result)
            else continuation.resumeWithException(task.exception?:IllegalStateException("Firebase request failed"))
        }
    }
}
