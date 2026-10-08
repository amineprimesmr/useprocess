package com.tenkdesign.android
/** Snapshot of the selection at drag start; reversing direction retracts only the active range. */
data class DragSelectionRange(val start:Int,val baseline:Set<Int>,val subtract:Boolean= start in baseline) {
 init {require(start>=0)}
 fun selectionAt(end:Int):Set<Int> {
  require(end>=0);val range=minOf(start,end)..maxOf(start,end)
  return if(subtract)baseline-range.toSet()else baseline+range.toSet()
 }
}
