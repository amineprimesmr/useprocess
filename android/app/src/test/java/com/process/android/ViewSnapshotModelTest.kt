package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ViewSnapshotModelTest {
 @Test fun clipsToVisibleWindowWithoutCapturingNeighbors(){assertEquals(SnapshotPixelRect(0,20,100,200),snapshotVisibleRect(-10,20,100,300,400,200))}
 @Test fun rejectsEmptyOutsideAndExcessiveBounds(){assertNull(snapshotVisibleRect(500,0,600,100,400,300));assertNull(snapshotVisibleRect(0,0,0,100,400,300));assertNull(snapshotVisibleRect(0,0,5000,5000,5000,5000))}
}
