package com.tenkdesign.android
import org.junit.Test
import org.junit.Assert.*
class AnimatedKeypadModelTest {
 @Test fun wholeNumbersStayBoundedAndNeverStartAtZero() {
  var value=AnimatedKeypadValue().append(0);assertEquals("",value.digits)
  repeat(12){value=value.append(9)}
  assertEquals(999999999,value.amount);assertEquals("999,999,999",value.formatted);assertTrue(value.atLimit)
  assertEquals(value,value.append(42))
 }
 @Test fun removalCrossesGroupingBoundaryAndReturnsToZero() {
  var value=AnimatedKeypadValue("1000").deleteLast();assertEquals("100",value.formatted)
  repeat(10){value=value.deleteLast()};assertEquals("0",value.formatted);assertEquals(0,value.amount)
 }
}
