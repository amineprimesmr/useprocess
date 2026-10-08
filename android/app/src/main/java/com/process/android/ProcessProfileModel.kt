package com.process.android
import java.time.*
import kotlin.math.*

enum class ProfileVisualMetric(val french:String,val english:String) {
 VISUAL_INDEX("Indice visuel","Visual index"),RECOVERY("Cernes et fatigue","Dark Circles & Fatigue"),PUFFINESS("Aspect gonflé","Apparent puffiness"),DEFINITION("Mâchoire & pommettes","Jawline & Cheekbones"),CAPTURE("Capture","Capture");
 fun title(english:Boolean)=if(english)this.english else french
 val lowerIsBetter get()=this in setOf(VISUAL_INDEX,RECOVERY,PUFFINESS)
}
data class ProfileScan(val id:String,val createdAt:Instant,val wellnessScore:Int,val metrics:Map<ProfileVisualMetric,Double> = emptyMap()) {
 init {require(id.isNotBlank()&&wellnessScore in 0..100&&metrics.values.all {it.isFinite()&&it in 0.0..100.0})}
}
data class ProfileSnapshot(val contextKey:String,val firstName:String,val scans:List<ProfileScan>,val startScanOverride:String?=null,val nowScanOverride:String?=null) {
 init {require(contextKey.isNotBlank()&&scans.map {it.id}.distinct().size==scans.size)}
}
data class ProfileDayPoint(val date:LocalDate,val value:Double)
enum class ProfileScoreRange(val days:Long,val french:String,val english:String) { WEEK(7,"Semaine","Week"),MONTH(30,"Mois","Month"),ALL(90,"Tout","All") }
object ProcessProfileModel {
 private val demoShape=listOf(58,60,59,63,62,66,65,69,68,72,71,75,74,78,77,81)
 fun pair(snapshot:ProfileSnapshot?):Pair<ProfileScan?,ProfileScan?> {
  val scans=snapshot?.scans?:emptyList()
  return (scans.firstOrNull {it.id==snapshot?.startScanOverride}?:scans.minByOrNull {it.createdAt}) to (scans.firstOrNull {it.id==snapshot?.nowScanOverride}?:scans.maxByOrNull {it.createdAt})
 }
 fun daily(scans:List<ProfileScan>,zone:ZoneId)=scans.groupBy {it.createdAt.atZone(zone).toLocalDate()}.mapValues {(_,items)->items.reduce {a,b->if(b.createdAt>=a.createdAt)b else a}}.toSortedMap()
 fun scores(scans:List<ProfileScan>,today:LocalDate,range:ProfileScoreRange,zone:ZoneId)=daily(scans,zone).filterKeys {it>=today.minusDays(range.days-1)&&it<=today}.map {(day,scan)->ProfileDayPoint(day,scan.wellnessScore.toDouble())}
 /** Original explicitly disclosed sample curve, never used as a real score or metric history. */
 fun sampleScores(today:LocalDate,range:ProfileScoreRange):List<ProfileDayPoint> {
  val count=when(range){ProfileScoreRange.WEEK->11;ProfileScoreRange.MONTH->30;ProfileScoreRange.ALL->90}
  return (0 until count).map {i->ProfileDayPoint(today.minusDays((count-1-i).toLong()),demoShape[(i.toDouble()/(count-1)*(demoShape.size-1)).roundToInt()].toDouble())}
 }
 fun metricHistory(scans:List<ProfileScan>,metric:ProfileVisualMetric,selectedDate:LocalDate,zone:ZoneId)=daily(scans,zone).filterKeys {it<=selectedDate}.mapNotNull {(date,scan)->scan.metrics[metric]?.takeIf {it>0}?.let {ProfileDayPoint(date,it)}}
 fun metricPoints(history:List<ProfileDayPoint>,today:LocalDate)=history.filter {it.date>=today.minusDays(29)&&it.date<=today}.ifEmpty {history.lastOrNull()?.let(::listOf)?:emptyList()}
 /** Preserve live source's historical comparison interval: current -6..0 versus -19..-13 (including its intervening gap). */
 fun sourceDelta(history:List<ProfileDayPoint>,today:LocalDate):Double? {
  fun average(start:Long,end:Long)=history.filter {it.date>=today.minusDays(start)&&it.date<=today.minusDays(end)&&it.value>0}.map {it.value}.takeIf {it.isNotEmpty()}?.average()
  val current=average(6,0)?:return null;val previous=average(19,13)?:return null;return current-previous
 }
 fun axis(values:List<Double>):Pair<Double,Double> {
  if(values.isEmpty())return 40.0 to 80.0
  val low=values.min();val high=values.max()
  if(low==high)return max(0.0,low-8) to min(100.0,high+8)
  val padding=max(4.0,(high-low)*.15);return low-padding to high+padding
 }
}
