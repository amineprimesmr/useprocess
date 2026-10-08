package com.process.android
import org.junit.Test
import org.junit.Assert.*
import java.time.*
class ProcessProfileModelTest {
 private val zone=ZoneId.of("Europe/Paris")
 private val today=LocalDate.of(2026,10,8)
 private fun scan(id:String,time:String,score:Int=60,metric:Double=50.0)=ProfileScan(id,Instant.parse(time),score,mapOf(ProfileVisualMetric.VISUAL_INDEX to metric))
 @Test fun dailyUsesUserTimezoneAndMostRecentScan() {
  val scans=listOf(scan("old","2026-10-07T22:05:00Z",40),scan("new","2026-10-08T12:00:00Z",70),scan("past","2026-10-06T22:00:00Z",50),scan("future","2026-10-09T12:00:00Z",99))
  val points=ProcessProfileModel.scores(scans,today,ProfileScoreRange.WEEK,zone)
  assertEquals(listOf(today.minusDays(1),today),points.map {it.date})
  assertEquals(listOf(50.0,70.0),points.map {it.value})
 }
 @Test fun pairPreservesRealIdentityAndExplicitOverrides() {
  val a=scan("a","2026-10-01T00:00:00Z");val b=scan("b","2026-10-08T00:00:00Z")
  assertEquals(a to b,ProcessProfileModel.pair(ProfileSnapshot("user","A",listOf(b,a))))
  assertEquals(b to a,ProcessProfileModel.pair(ProfileSnapshot("user","A",listOf(a,b),"b","a")))
  assertEquals(a to a,ProcessProfileModel.pair(ProfileSnapshot("user","A",listOf(a))))
 }
 @Test fun disclosedSamplesNeverReplaceRealLatestDataInModel() {
  assertTrue(ProcessProfileModel.scores(emptyList(),today,ProfileScoreRange.WEEK,zone).isEmpty())
  val sample=ProcessProfileModel.sampleScores(today,ProfileScoreRange.WEEK)
  assertEquals(11,sample.size);assertEquals(58.0,sample.first().value,0.0);assertEquals(81.0,sample.last().value,0.0)
  assertEquals(today,sample.last().date)
 }
 @Test fun metricsRespectSelectedDateZeroExclusionAndHistoricalSourceDeltaGap() {
  val scans=listOf(scan("a","2026-10-08T12:00:00Z",metric=0.0),scan("b","2026-10-07T12:00:00Z",metric=42.0))
  assertEquals(listOf(42.0),ProcessProfileModel.metricHistory(scans,ProfileVisualMetric.VISUAL_INDEX,today,zone).map {it.value})
  assertTrue(ProcessProfileModel.metricHistory(scans,ProfileVisualMetric.VISUAL_INDEX,today.minusDays(2),zone).isEmpty())
  val history=listOf(ProfileDayPoint(today,60.0),ProfileDayPoint(today.minusDays(7),90.0),ProfileDayPoint(today.minusDays(14),40.0))
  assertEquals(20.0,ProcessProfileModel.sourceDelta(history,today)!!,0.0)
 }
 @Test(expected=IllegalArgumentException::class) fun nonFiniteMetricIsRejected(){scan("bad","2026-10-08T00:00:00Z",metric=Double.NaN)}
}
