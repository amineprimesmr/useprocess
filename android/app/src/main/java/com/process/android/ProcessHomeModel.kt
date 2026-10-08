package com.process.android
import java.time.*
import java.time.temporal.ChronoUnit

enum class HomeDayAvailability { EDITABLE,FUTURE,OUTSIDE_PLAN }
enum class HomeSection { FACE_SCAN,NUTRITION,FACE_ROUTINE,POSTURE,TRAINING,RESOURCES }
data class HomePlanCalendar(val id:String,val start:LocalDate?,val totalDays:Int) {
 init {require(id.isNotBlank());require(totalDays in 0..10000)}
 fun contains(date:LocalDate)=start!=null&&totalDays>0&&!date.isBefore(start)&&date.isBefore(start.plusDays(totalDays.toLong()))
 fun preferredDate(today:LocalDate):LocalDate=if(start==null||totalDays==0)today else today.coerceIn(start,start.plusDays(totalDays.toLong()-1))
 fun availability(date:LocalDate,today:LocalDate)=if(date>today)HomeDayAvailability.FUTURE else if(contains(date))HomeDayAvailability.EDITABLE else HomeDayAvailability.OUTSIDE_PLAN
 fun elapsedDays(today:LocalDate)=if(start==null)0 else (ChronoUnit.DAYS.between(start,today)+1).coerceIn(0,totalDays.toLong()).toInt()
 fun remainingDays(today:LocalDate)=(totalDays-elapsedDays(today)).coerceAtLeast(0)
 fun progress(today:LocalDate)=if(totalDays==0)0f else elapsedDays(today).toFloat()/totalDays
}
data class HomeScanSummary(val id:String,val createdAt:Instant,val score:Int?,val showsMedia:Boolean=true) {
 init {require(id.isNotBlank());require(score==null||score in 0..100)}
}
data class HomeMealTile(val id:String,val imageResource:String?,val score:Int?=null) {init {require(score==null||score in 0..100)}}
data class ProcessHomeSnapshot(
 val contextKey:String,val firstName:String,val plan:HomePlanCalendar?,val selectedDate:LocalDate,
 val streak:Int=0,val todayComplete:Boolean=false,val latestScan:HomeScanSummary?=null,
 val localWaterMl:Int=0,val healthWaterMl:Int?=null,val hasLocalWaterAdjustment:Boolean=false,val targetWaterMl:Int=2000,
 val meals:List<HomeMealTile> = emptyList(),val completedRoutineIds:Set<String> = emptySet(),
 val sectionOrder:List<HomeSection> = listOf(HomeSection.FACE_SCAN,HomeSection.NUTRITION,HomeSection.FACE_ROUTINE),
 val hiddenSections:Set<HomeSection> = emptySet(),val canRestore:Boolean=false
) {
 init {require(contextKey.isNotBlank());require(targetWaterMl>0);require(meals.map{it.id}.distinct().size==meals.size)}
 val effectiveWaterMl get()=if(hasLocalWaterAdjustment)localWaterMl.coerceAtLeast(0)else maxOf(0,localWaterMl,healthWaterMl?:0)
 val visibleSections get()=(sectionOrder+listOf(HomeSection.FACE_SCAN,HomeSection.NUTRITION,HomeSection.FACE_ROUTINE)).distinct().filter {it !in setOf(HomeSection.TRAINING,HomeSection.RESOURCES)&& (it !in hiddenSections||it==HomeSection.NUTRITION)}
}
object HomeScanCadence {
 fun next(last:Instant,zone:ZoneId)=last.atZone(zone).toLocalDate().plusDays(1).atTime(6,0).atZone(zone).toInstant()
 fun due(last:Instant?,now:Instant,zone:ZoneId):Boolean {
  if(last==null)return true
  if(last>now||last.atZone(zone).toLocalDate()==now.atZone(zone).toLocalDate())return false
  return now>=now.atZone(zone).toLocalDate().atTime(6,0).atZone(zone).toInstant()
 }
 fun progress(last:Instant,now:Instant,zone:ZoneId):Float {
  val total=Duration.between(last,next(last,zone)).toMillis();if(total<=0)return 1f
  return (Duration.between(last,now).toMillis().toDouble()/total).coerceIn(0.0,1.0).toFloat()
 }
 fun countdown(last:Instant,now:Instant,zone:ZoneId):String {
  val seconds=Duration.between(now,next(last,zone)).seconds.coerceAtLeast(0);val hours=seconds/3600;val minutes=(seconds%3600)/60
  return when {hours>0->"${hours}h ${minutes.toString().padStart(2,'0')}m";minutes>0->"$minutes min";else->"< 1 min"}
 }
}
