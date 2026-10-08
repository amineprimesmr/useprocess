package com.process.android
internal data class ScrollNavigationModel(val previousOffset:Float=0f,val directionDown:Boolean=false,val baseline:Float=0f,val hidden:Boolean=false) {
 fun update(offset:Float,interacting:Boolean):ScrollNavigationModel {
  if(!offset.isFinite()||offset==previousOffset)return this
  val down=previousOffset<offset
  val nextBaseline=if(down!=directionDown)offset-(if(hidden)60f else 0f)else baseline
  return copy(previousOffset=offset,directionDown=down,baseline=nextBaseline,hidden=if(interacting)offset-nextBaseline>50f else hidden)
 }
}
