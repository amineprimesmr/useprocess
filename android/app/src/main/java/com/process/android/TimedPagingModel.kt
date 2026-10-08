package com.process.android
internal fun timedPagingNext(selection:Int,count:Int):Int? = if(count<=1||selection !in 0 until count)null else (selection+1)%count
