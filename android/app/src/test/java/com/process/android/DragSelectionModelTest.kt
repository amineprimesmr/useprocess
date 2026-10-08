package com.process.android
import com.tenkdesign.android.*
import org.junit.Test
import org.junit.Assert.*
class DragSelectionModelTest {
 @Test fun additiveDragKeepsPriorSelection(){assertEquals(setOf(0,3,4,5),DragSelectionRange(3,setOf(0)).selectionAt(5))}
 @Test fun reversingRetractsOnlyCurrentRange(){val drag=DragSelectionRange(3,setOf(0,8));assertEquals(setOf(0,3,4,8),drag.selectionAt(4));assertEquals(setOf(0,1,2,3,8),drag.selectionAt(1))}
 @Test fun dragStartingOnSelectedItemSubtractsFromBaseline(){val drag=DragSelectionRange(3,setOf(1,2,3,5,8));assertEquals(setOf(1,2,8),drag.selectionAt(5));assertEquals(setOf(1,2,5,8),drag.selectionAt(3))}
}
