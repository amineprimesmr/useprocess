package com.process.android

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.view.Surface
import android.view.TextureView
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/** Local original media; remote high-quality replacement is a separate authenticated host service. */
@Composable internal fun ProcessRoutineMedia(step:RoutineStep,english:Boolean,modifier:Modifier=Modifier,reduceMotion:Boolean=rememberProcessReducedMotion()) {
    val owner=LocalLifecycleOwner.current
    var active by remember(owner) {mutableStateOf(owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))}
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver {_,_->active=owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)}
        owner.lifecycle.addObserver(observer);onDispose {owner.lifecycle.removeObserver(observer)}
    }
    val image=when(step.imageResource) {"routinesauts"->R.drawable.routinesauts;"routinepointes"->R.drawable.routinepointes;"routinebrasciel"->R.drawable.routinebrasciel;"routinebrascroix"->R.drawable.routinebrascroix;"routinethorax"->R.drawable.routinethorax;"routinegenoux"->R.drawable.routinegenoux;else->0}
    val video=when(step.videoResource) {"lymph_01"->R.raw.lymph_01;"lymph_02"->R.raw.lymph_02;"lymph_03"->R.raw.lymph_03;"lymph_05"->R.raw.lymph_05;"lymph_06"->R.raw.lymph_06;"lymph_07"->R.raw.lymph_07;else->0}
    Box(modifier.clipToBounds()) {
        if(image!=0)Image(painterResource(image),step.title(english),Modifier.fillMaxSize(),contentScale=ContentScale.Crop)
        if(video!=0&&!reduceMotion)AndroidView(factory={context->RoutineVideoView(context)},modifier=Modifier.fillMaxSize(),update={it.setMedia(video,active)},onRelease={it.releaseMedia()})
    }
}
private class RoutineVideoView(context:Context):TextureView(context),TextureView.SurfaceTextureListener {
    private var rawId=0
    private var active=false
    private var prepared=false
    private var player:MediaPlayer?=null
    private var videoSurface:Surface?=null
    init {isOpaque=false;alpha=0f;surfaceTextureListener=this;importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO}
    fun setMedia(resource:Int,play:Boolean) {
        active=play
        if(resource!=rawId) {releaseMedia();rawId=resource;if(isAvailable)prepare()}
        updatePlayback()
    }
    private fun prepare() {
        val texture=surfaceTexture?:return
        if(rawId==0||player!=null)return
        val media=MediaPlayer();player=media;videoSurface=Surface(texture)
        try {
            media.setSurface(videoSurface);media.isLooping=true;media.setVolume(0f,0f)
            context.resources.openRawResourceFd(rawId).use {media.setDataSource(it.fileDescriptor,it.startOffset,it.length)}
            media.setOnPreparedListener {if(player===it){prepared=true;updateCrop();updatePlayback()}}
            media.setOnVideoSizeChangedListener {_,_,_->updateCrop()}
            media.setOnInfoListener {mp,what,_->if(player===mp&&what==MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START)alpha=1f;false}
            media.setOnErrorListener {mp,_,_->if(player===mp)releaseMedia();true}
            media.prepareAsync()
        } catch(_:Exception) {releaseMedia()}
    }
    private fun updatePlayback() {
        val media=player?:return
        if(!prepared)return
        try {if(active&&!media.isPlaying)media.start()else if(!active&&media.isPlaying)media.pause()}
        catch(_:IllegalStateException) {releaseMedia()}
    }
    private fun updateCrop() {
        val media=player?:return
        if(!prepared||width<=0||height<=0||media.videoWidth<=0||media.videoHeight<=0)return
        val videoRatio=media.videoWidth.toFloat()/media.videoHeight
        val boundsRatio=width.toFloat()/height
        setTransform(Matrix().apply {setScale(if(videoRatio>boundsRatio)videoRatio/boundsRatio else 1f,if(videoRatio<boundsRatio)boundsRatio/videoRatio else 1f,width/2f,height/2f)})
    }
    fun releaseMedia() {prepared=false;player?.release();player=null;videoSurface?.release();videoSurface=null;alpha=0f}
    override fun onSurfaceTextureAvailable(surface:SurfaceTexture,width:Int,height:Int) {prepare()}
    override fun onSurfaceTextureSizeChanged(surface:SurfaceTexture,width:Int,height:Int) {updateCrop()}
    override fun onSurfaceTextureDestroyed(surface:SurfaceTexture):Boolean {releaseMedia();return true}
    override fun onSurfaceTextureUpdated(surface:SurfaceTexture) {}
}
