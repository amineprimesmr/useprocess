package com.process.android
import org.junit.Test
import org.junit.Assert.*
class TimedPagingModelTest {
 @Test fun advancesWrapsAndRejectsEmptySingletonOrInvalidSelection() {assertEquals(1,timedPagingNext(0,3));assertEquals(0,timedPagingNext(2,3));assertNull(timedPagingNext(0,0));assertNull(timedPagingNext(0,1));assertNull(timedPagingNext(-1,3));assertNull(timedPagingNext(3,3))}
}
