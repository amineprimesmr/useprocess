package com.tenkdesign.android
object ExpandableSliderModel {
 fun safe(value:Float,range:ClosedFloatingPointRange<Float>):Float {
  require(range.start.isFinite()&&range.endInclusive.isFinite()&&range.start>=0&&range.endInclusive>range.start)
  return (if(value.isFinite())value else range.start).coerceIn(range)
 }
 fun fraction(value:Float,range:ClosedFloatingPointRange<Float>)=safe(value,range)/range.endInclusive
 fun drag(start:Float,delta:Float,width:Float,range:ClosedFloatingPointRange<Float>):Float =
  if(!delta.isFinite()||!width.isFinite()||width<=0)safe(start,range)else safe(start+delta/width*range.endInclusive,range)
}
