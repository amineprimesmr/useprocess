package com.process.android
internal fun scrollIndicatorProgress(offset:Float,range:Float):Float = if(!offset.isFinite()||!range.isFinite()||range<=0f)0f else (offset/range).coerceIn(0f,1f)
internal fun scrollIndicatorDraggedProgress(initial:Float,translation:Float,travel:Float):Float = if(!initial.isFinite()||!translation.isFinite()||!travel.isFinite()||travel<=0f)0f else (initial+translation/travel).coerceIn(0f,1f)
