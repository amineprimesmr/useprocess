package com.process.android

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.Source
import java.time.LocalDate

/** Matches live iOS paths. Responses are discarded after account changes; writes never target a supplied UID. */
class ProcessCloudRepository(private val session:ProcessFirebaseSession,private val database:FirebaseFirestore=FirebaseFirestore.getInstance()) {
    suspend fun loadProfile():ProcessCloudProfile? {
        val lease=session.lease()
        val result=database.collection("users").document(lease.uid).get().awaitProcess()
        session.check(lease)
        return result.data?.let {ProcessCloudProfile.decode(lease.uid,it)}
    }
    /** Updating an existing profile avoids creating a partial record that the iOS Codable model cannot decode. */
    suspend fun updateProfile(edit:ProcessProfileEdit) {
        val fields=edit.fields();if(fields.isEmpty())return
        val lease=session.lease()
        val document=database.collection("users").document(lease.uid)
        database.runTransaction {transaction->
            session.check(lease)
            check(transaction.get(document).exists()) {"Complete account creation before saving a profile"}
            transaction.update(document,fields+("lastUpdated" to FieldValue.serverTimestamp()))
        }.awaitProcess()
        session.check(lease)
    }
    suspend fun isUsernameAvailable(raw:String):Boolean {
        val tag=ProcessUsernameRules.normalize(raw);require(ProcessUsernameRules.valid(tag))
        val lease=session.lease()
        val result=database.collection("usernames").document(tag).get(Source.SERVER).awaitProcess()
        session.check(lease)
        return !result.exists()||result.getString("userId")==lease.uid
    }
    /** Claim, release the previous owned tag and update the profile atomically. */
    suspend fun claimUsername(raw:String,displayName:String) {
        val tag=ProcessUsernameRules.normalize(raw);require(ProcessUsernameRules.valid(tag))
        require(displayName.codePointCount(0,displayName.length)<=80)
        val lease=session.lease()
        val user=database.collection("users").document(lease.uid)
        val target=database.collection("usernames").document(tag)
        database.runTransaction {transaction->
            session.check(lease)
            val profile=transaction.get(user);check(profile.exists()) {"Account profile missing"}
            val existing=transaction.get(target)
            check(!existing.exists()||existing.getString("userId")==lease.uid) {"Username already taken"}
            val old=profile.getString("username")?.let(ProcessUsernameRules::normalize)?.takeIf {it.isNotEmpty()&&it!=tag}
            val oldRef=old?.let {database.collection("usernames").document(it)}
            val oldOwner=oldRef?.let {transaction.get(it).getString("userId")}
            if(oldRef!=null&&oldOwner==lease.uid)transaction.delete(oldRef)
            transaction.set(target,mapOf("userId" to lease.uid,"displayName" to displayName,"updatedAt" to FieldValue.serverTimestamp()))
            transaction.update(user,mapOf("username" to tag,"lastUpdated" to FieldValue.serverTimestamp()))
        }.awaitProcess()
        session.check(lease)
    }
    suspend fun loadTrajectory(limit:Long=90):List<CalendarDayRecord> {
        require(limit in 1..730)
        val lease=session.lease()
        val result=database.collection("users").document(lease.uid).collection("debloatTrajectory").orderBy("dayKey",Query.Direction.DESCENDING).limit(limit).get().awaitProcess()
        session.check(lease)
        return result.documents.mapNotNull {doc->
            val date=runCatching {LocalDate.parse(doc.getString("dayKey"))}.getOrNull()?:return@mapNotNull null
            val verdict=when(doc.getString("verdict")) {
                "excellent"->CalendarDayVerdict.EXCELLENT;"onTrack"->CalendarDayVerdict.ON_TRACK;"partial"->CalendarDayVerdict.PARTIAL
                "regression"->CalendarDayVerdict.REGRESSION;"missed"->CalendarDayVerdict.MISSED;"paused"->CalendarDayVerdict.PAUSED;else->CalendarDayVerdict.PENDING
            }
            CalendarDayRecord(date,doc.getString("scanId")!=null,doc.getBoolean("checkInSubmitted")==true,doc.getDouble("compositeScore")?:0.0,verdict)
        }
    }
    /** Real account-bound read; unknown fields remain in rawJson and this projection cannot overwrite them. */
    suspend fun loadPlan():ProcessPlanDocument? {
        val lease=session.lease()
        val raw=loadPlanJSON()
        session.check(lease)
        if(raw==null)return null
        val document=kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {ProcessPlanJson.decode(raw,lease.uid)}
        session.check(lease)
        return document
    }
    /** Preserve the entire original JSON alongside the read-only calendar decoder; never overwrite unknown plan fields. */
    suspend fun loadPlanJSON():String? {
        val lease=session.lease()
        val result=database.collection("users").document(lease.uid).collection("welcomePlan").document("current").get().awaitProcess()
        session.check(lease)
        return result.getString("planJSON")
    }
}
