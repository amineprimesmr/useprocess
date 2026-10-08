package com.tenkdesign.android
import kotlin.math.*
object ElasticSegmentedModel {
 fun acceptedOffset(previous:Float,translation:Float,currentOffset:Float,width:Float,count:Int):Float {
  if(count<=0||width<=0||!translation.isFinite())return previous
  val end=width-width/count
  return if(translation+currentOffset>0&&translation+currentOffset<end)translation else previous
 }
 fun dropIndex(location:Float,capsuleWidth:Float,count:Int,round:Boolean):Int {
  require(count>0)
  if(!location.isFinite()||!capsuleWidth.isFinite()||capsuleWidth<=0)return 0
  val index=if(round)floor(location/capsuleWidth+.5f).toInt()else (location/capsuleWidth).toInt()
  return index.coerceIn(0,count-1)
 }
}
