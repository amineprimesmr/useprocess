package com.process.android
internal data class SnapshotPixelRect(val left:Int,val top:Int,val right:Int,val bottom:Int){val width:Int get()=right-left;val height:Int get()=bottom-top}
internal fun snapshotVisibleRect(left:Int,top:Int,right:Int,bottom:Int,windowWidth:Int,windowHeight:Int):SnapshotPixelRect? {
 if(windowWidth<=0||windowHeight<=0)return null
 val rect=SnapshotPixelRect(left.coerceIn(0,windowWidth),top.coerceIn(0,windowHeight),right.coerceIn(0,windowWidth),bottom.coerceIn(0,windowHeight))
 return rect.takeIf {it.width>0&&it.height>0&&it.width.toLong()*it.height<=16_000_000}
}
