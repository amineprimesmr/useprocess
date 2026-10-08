package com.process.android
internal data class SwipeActionsPosition(val offset:Float,val bounce:Float,val progress:Float)
internal fun swipeActionsPosition(initial:Float,translation:Float,width:Float):SwipeActionsPosition {
 if(!initial.isFinite()||!translation.isFinite()||!width.isFinite()||width<=0f)return SwipeActionsPosition(0f,0f,0f)
 val offset=(initial+translation).coerceIn(-width,0f)
 return SwipeActionsPosition(offset,minOf(translation-(offset-initial),0f)/10f,-offset/width)
}
internal fun swipeActionsShouldOpen(offset:Float,velocity:Float,width:Float):Boolean = width.isFinite()&&width>0f&&offset.isFinite()&&velocity.isFinite()&&-(velocity+offset)>width*.6f
