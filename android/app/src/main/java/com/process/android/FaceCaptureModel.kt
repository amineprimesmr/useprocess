package com.process.android
import java.io.File
import java.time.Instant
import kotlin.math.*

enum class FaceCaptureHint { SEARCHING,MULTIPLE,TOO_FAR,TOO_CLOSE,OFF_CENTER,TURN_FORWARD,LOW_LIGHT,READY,UNAVAILABLE }
data class FaceCaptureObservation(val faceCount:Int,val fill:Float=0f,val centerX:Float=.5f,val centerY:Float=.5f,val yaw:Float=0f,val pitch:Float=0f,val luminance:Float=0f,val observedAtMillis:Long=0) {
 fun hint():FaceCaptureHint=when {
  faceCount<0->FaceCaptureHint.UNAVAILABLE
  faceCount==0->FaceCaptureHint.SEARCHING
  faceCount!=1->FaceCaptureHint.MULTIPLE
  listOf(fill,centerX,centerY,yaw,pitch,luminance).any {!it.isFinite()}->FaceCaptureHint.UNAVAILABLE
  fill<.028f->FaceCaptureHint.TOO_FAR
  fill>.82f->FaceCaptureHint.TOO_CLOSE
  centerX !in .15f.. .85f || centerY !in .15f.. .85f->FaceCaptureHint.OFF_CENTER
  abs(yaw)>18||abs(pitch)>18->FaceCaptureHint.TURN_FORWARD
  luminance<.08f->FaceCaptureHint.LOW_LIGHT
  else->FaceCaptureHint.READY
 }
 fun canCapture(nowMillis:Long)=hint()==FaceCaptureHint.READY&&nowMillis>=observedAtMillis&&nowMillis-observedAtMillis<=750
}
data class FaceCaptureRect(val left:Int,val top:Int,val right:Int,val bottom:Int) {
 val width get()=right-left;val height get()=bottom-top
 fun rotated(imageWidth:Int,imageHeight:Int,rotation:Int):FaceCaptureRect=when(rotation){
  0->this;90->FaceCaptureRect(imageHeight-bottom,left,imageHeight-top,right)
  180->FaceCaptureRect(imageWidth-right,imageHeight-bottom,imageWidth-left,imageHeight-top)
  270->FaceCaptureRect(top,imageWidth-right,bottom,imageWidth-left)
  else->error("Rotation must be 0,90,180 or270")
 }
}
/** Local photo and 2D capture metadata. This is not an ARKit mesh or a wellness assessment. */
data class FacePhotoCapture(val file:File,val contextKey:String,val createdAt:Instant,val observation:FaceCaptureObservation,val mirrored:Boolean) {
 init {require(contextKey.isNotBlank())}
}
object FaceCaptureGeometry {
 fun contour(angle:Double):Pair<Float,Float> {
  val c=cos(angle);val s=sin(angle);val exponent=2.0/2.34
  val ax=sign(c)*abs(c).pow(exponent);val ay=sign(s)*abs(s).pow(exponent)
  val bottom=max(0.0,s);val top=max(0.0,-s)
  val scale=1+.09*top.pow(1.12)+.04*(1-abs(s)).pow(2.2)-.30*bottom.pow(1.45)
  return (.5+.5*ax*scale).toFloat() to (.5+.5*ay+.5*.018*(top-bottom)).toFloat()
 }
}
