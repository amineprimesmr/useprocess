package com.process.android
object GooeyRefreshGeometry {
 const val threshold=60f
 fun progress(offset:Float)=if(offset.isFinite())(offset/threshold).coerceIn(0f,1f)else 0f
 fun indicatorSize(progress:Float)=30f+10f*((progress.coerceIn(0f,1f)-.2f)/.8f).coerceIn(0f,1f)
 fun spinnerOpacity(progress:Float)=((progress-.8f)/.2f).coerceIn(0f,1f)
 fun blur(progress:Float)=25f*(1f-progress.coerceIn(0f,1f))
}
