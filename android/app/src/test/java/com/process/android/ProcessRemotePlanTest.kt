package com.process.android
import java.time.*
import org.junit.Test
import org.junit.Assert.*
class ProcessRemotePlanTest {
 private fun root()=mapOf<String,Any?>("id" to "plan-a","userId" to "user-a","createdAt" to 0.0,"lastUpdated" to 1.5,"headline" to "Original plan","executiveSummary" to "Source text")
 private fun day()=mapOf("id" to "day-a","globalDayIndex" to 0,"weekNumber" to 1,"weekdayIndex" to 0,"weekdayLabel" to "Lundi","title" to "Premier jour","nutrition" to mapOf("breakfast" to "","lunch" to "Repas","dinner" to "","hydration" to "Eau","omadMeal" to "Repas unique"))
 @Test fun legacyAbsentCalendarIsEmptyAndSwiftDatesUse2001Epoch() {
  val p=ProcessRemotePlanDecoder.decode(root(),"user-a")
  assertEquals(Instant.parse("2001-01-01T00:00:00Z"),p.createdAt)
  assertEquals(Instant.parse("2001-01-01T00:00:01.500Z"),p.lastUpdated)
  assertTrue(p.days.isEmpty());assertNull(p.startedAt)
  assertEquals(Instant.parse("2000-12-31T23:59:59.500Z"),ProcessRemotePlanDecoder.swiftDate(-.5))
 }
 @Test fun usesActualCalendarLengthAndLocalDateAcrossDst() {
  val start=Instant.parse("2026-03-28T23:00:00Z").epochSecond-978307200L
  val calendar=mapOf("startedAt" to start,"weeks" to listOf(mapOf("days" to listOf(day(),day()+mapOf("id" to "day-b","globalDayIndex" to 1)))))
  val p=ProcessRemotePlanDecoder.decode(root()+mapOf("calendar" to calendar),"user-a");val zone=ZoneId.of("Europe/Paris")
  assertEquals(2,p.calendar(zone).totalDays);assertEquals("day-b",p.dayAt(LocalDate.parse("2026-03-30"),zone)?.id)
  assertNull(p.dayAt(LocalDate.parse("2026-03-31"),zone));assertTrue(p.days[0].nutrition.isOmad)
 }
 @Test fun failedDayStatusOverridesLegacyCompletion() {
  val p=ProcessRemotePlanDecoder.decode(root()+mapOf("progress" to mapOf("completedTaskIds" to listOf("task"),"taskStatuses" to mapOf("day|task" to "failed","other|task" to "completed"))),"user-a")
  assertFalse(p.taskCompleted("day","task"));assertTrue(p.taskCompleted("other","task"));assertTrue(p.taskCompleted("legacy","task"))
 }
 @Test fun rejectsMismatchedAndPreviewIdentity() {
  assertThrows(IllegalArgumentException::class.java){ProcessRemotePlanDecoder.decode(root(),"user-b")}
  assertThrows(IllegalArgumentException::class.java){ProcessRemotePlanDecoder.decode(root(),"local-user")}
 }
 @Test fun rejectsDuplicateDaysAndInvalidIndices() {
  for(days in listOf(listOf(day(),day()),listOf(day()+mapOf("globalDayIndex" to 2)))) {
   assertThrows(IllegalArgumentException::class.java){ProcessRemotePlanDecoder.decode(root()+mapOf("calendar" to mapOf("weeks" to listOf(mapOf("days" to days)))),"user-a")}
  }
 }
 @Test fun rejectsNonFiniteDatesAndUnknownStatuses() {
  assertThrows(IllegalArgumentException::class.java){ProcessRemotePlanDecoder.swiftDate(Double.NaN)}
  assertThrows(IllegalArgumentException::class.java){ProcessRemotePlanDecoder.decode(root()+mapOf("progress" to mapOf("taskStatuses" to mapOf("a" to "paid"))),"user-a")}
 }
}
