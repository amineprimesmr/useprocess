package com.process.android

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.math.floor
import kotlin.math.roundToLong

/** Read model for the actual FaceOriginPlan cloud JSON. Never re-encode this projection for writes. */
data class ProcessRemotePlan(
    val id:String,val userId:String,val createdAt:Instant,val lastUpdated:Instant,val headline:String,
    val executiveSummary:String,val startedAt:Instant?,val calendarBuildVersion:Int,val days:List<RemotePlanDay>,
    val completedTaskIds:Set<String>,val taskStatuses:Map<String,String>,val completedDayIds:Set<String>
) {
    fun calendar(zone:ZoneId)=HomePlanCalendar(id,startedAt?.atZone(zone)?.toLocalDate(),days.size)
    fun dayAt(date:LocalDate,zone:ZoneId):RemotePlanDay? {
        val start=startedAt?.atZone(zone)?.toLocalDate()?:return null
        val index=ChronoUnit.DAYS.between(start,date)
        return if(index in 0 until days.size.toLong())days[index.toInt()]else null
    }
    fun taskCompleted(dayId:String,taskId:String):Boolean=when(taskStatuses["$dayId|$taskId"]) {
        "completed"->true;"failed"->false;else->taskId in completedTaskIds
    }
}
data class RemotePlanTask(val id:String,val title:String,val detail:String,val pillar:String,val durationMinutes:Int?,val optional:Boolean)
data class RemotePlanNutrition(val breakfast:String,val lunch:String,val dinner:String,val snack:String?,val hydration:String,val principles:List<String>,val foodsToday:List<String>,val mealPlanStyle:String?,val omadMeal:String?) {
    val isOmad get()=mealPlanStyle=="omad"||(!omadMeal.isNullOrEmpty()&&breakfast.isEmpty()&&dinner.isEmpty())
}
data class RemotePlanDay(val id:String,val globalIndex:Int,val weekNumber:Int,val weekdayIndex:Int,val weekdayLabel:String,val title:String,
    val morning:List<RemotePlanTask>,val posture:List<RemotePlanTask>,val face:List<RemotePlanTask>,val evening:List<RemotePlanTask>,val nutrition:RemotePlanNutrition)

object ProcessRemotePlanDecoder {
    private val swiftReferenceDate=Instant.parse("2001-01-01T00:00:00Z")
    fun swiftDate(value:Any?):Instant {
        val seconds=(value as? Number)?.toDouble()?:error("Expected Swift reference-date seconds")
        require(seconds.isFinite()&&seconds in -100_000_000_000.0..100_000_000_000.0){"Invalid plan date"}
        val whole=floor(seconds)
        return swiftReferenceDate.plusSeconds(whole.toLong()).plusNanos(((seconds-whole)*1_000_000_000).roundToLong())
    }
    fun decode(root:Map<String,Any?>,expectedUserId:String):ProcessRemotePlan {
        require(expectedUserId.isNotBlank()&&expectedUserId!="local-user"){"An authenticated identity is required"}
        val uid=root.string("userId");require(uid==expectedUserId){"Plan belongs to another identity"}
        val id=root.string("id");require(id.isNotBlank())
        val calendar=root.objOrEmpty("calendar");val days=calendar.array("weeks").flatMap {raw->
            val week=raw.obj();week.array("days").map {decodeDay(it.obj())}
        }
        require(days.size<=10000&&days.map{it.id}.distinct().size==days.size){"Invalid or duplicate calendar days"}
        require(days.withIndex().all{it.index==it.value.globalIndex}){"Calendar day order is inconsistent"}
        val progress=root.objOrEmpty("progress")
        val statuses=progress.objOrEmpty("taskStatuses").mapValues {(_,v)->
            (v as? String)?.also{require(it=="failed"||it=="completed") {"Unknown task status"}}?:error("Invalid task status")
        }
        return ProcessRemotePlan(id,uid,swiftDate(root["createdAt"]),swiftDate(root["lastUpdated"]),root.string("headline"),root.string("executiveSummary"),calendar["startedAt"]?.let(::swiftDate),calendar.int("buildVersion",if(calendar.isEmpty())6 else 1),days,progress.strings("completedTaskIds").toSet(),statuses,progress.strings("completedDayIds").toSet())
    }
    private fun decodeDay(day:Map<String,Any?>):RemotePlanDay {
        fun tasks(key:String)=day.array(key).map {raw->val t=raw.obj();RemotePlanTask(t.string("id").also{require(it.isNotBlank())},t.string("title"),t.string("detail"),t.string("pillar"),t["durationMinutes"]?.let{t.int("durationMinutes")},t["isOptional"] as? Boolean?:false)}
        val n=day["nutrition"].obj()
        val lists=listOf("morning","posture","face","evening").map(::tasks)
        return RemotePlanDay(day.string("id").also{require(it.isNotBlank())},day.int("globalDayIndex"),day.int("weekNumber"),day.int("weekdayIndex"),day.string("weekdayLabel"),day.string("title"),lists[0],lists[1],lists[2],lists[3],RemotePlanNutrition(n.string("breakfast"),n.string("lunch"),n.string("dinner"),n.optionalString("snack"),n.string("hydration"),n.strings("principles"),n.strings("foodsToday"),n.optionalString("mealPlanStyle"),n.optionalString("omadMeal")))
    }
    private fun Any?.obj():Map<String,Any?> {
        val map=this as? Map<*,*>?:error("Expected plan object")
        require(map.keys.all{it is String})
        @Suppress("UNCHECKED_CAST") return map as Map<String,Any?>
    }
    private fun Map<String,Any?>.objOrEmpty(key:String):Map<String,Any?> = this[key]?.obj()?:emptyMap()
    private fun Map<String,Any?>.string(key:String)=this[key] as? String?:error("Missing plan string: $key")
    private fun Map<String,Any?>.optionalString(key:String):String?=this[key]?.let{it as? String?:error("Invalid string: $key")}
    private fun Map<String,Any?>.array(key:String):List<*> = this[key]?.let{(it as? List<*>)?.also{list->require(list.size<=10000)}?:error("Invalid list: $key")}?:emptyList<Any>()
    private fun Map<String,Any?>.strings(key:String)=array(key).map{it as? String?:error("Invalid string array: $key")}
    private fun Map<String,Any?>.int(key:String,fallback:Int?=null):Int {
        val value=this[key]?:return fallback?:error("Missing integer: $key")
        val d=(value as? Number)?.toDouble()?:error("Invalid integer: $key")
        require(d.isFinite()&&d==floor(d)&&d in Int.MIN_VALUE.toDouble()..Int.MAX_VALUE.toDouble())
        return d.toInt()
    }
}
