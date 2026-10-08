package com.process.android

import android.content.Context
import android.graphics.*
import android.view.View
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlin.math.*

/** Source flame: same Bezier controls, layer phases, periods, gradients and blur radii.
 * Software-backed native Canvas supports blurred paths on API 28, not only RenderEffect on API 31+.
 * Pixel compositing and frame performance still require physical-device comparison.
 */
@Composable fun ProcessStreakFlame(
    modifier:Modifier=Modifier,height:Dp=252.dp,active:Boolean=true,dark:Boolean=isSystemInDarkTheme(),
    timeSeconds:Double?=null
) {
    val reduced=rememberProcessReducedMotion()
    val owner=LocalLifecycleOwner.current
    var clock by remember {mutableDoubleStateOf(System.currentTimeMillis()/1000.0-978307200.0)}
    var resumed by remember {mutableStateOf(false)}
    LaunchedEffect(owner,active,reduced,timeSeconds) {
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            resumed=true
            try {
                if(active&&!reduced&&timeSeconds==null)while(true) {
                    clock=System.currentTimeMillis()/1000.0-978307200.0
                    delay(34) // Source TimelineView minimum interval = 1/30 second.
                } else kotlinx.coroutines.awaitCancellation()
            } finally {resumed=false}
        }
    }
    val scale=height.value/252f
    Box(modifier.size((210*scale).dp,height).clearAndSetSemantics {},contentAlignment=Alignment.Center) {
        AndroidView(factory={FlameCanvasView(it)},modifier=Modifier.requiredSize((370*scale).dp,(412*scale).dp),update={view->
            view.frameTime=timeSeconds?:clock;view.dark=dark;view.playbackActive=active&&resumed;view.invalidate()
        })
    }
}

private class FlameCanvasView(context:Context):View(context) {
    var frameTime=0.0
    var dark=false
        set(value) {if(field!=value){field=value;configurePaints()}}
    var playbackActive=true
    private val path=Path()
    private val additive=PorterDuffXfermode(PorterDuff.Mode.ADD)
    private data class Layer(val phase:Double,val rect:RectF,val paint:Paint,val lightOpacity:Float,val darkOpacity:Float)
    private data class Tongue(val phase:Double,val offset:Float,val scale:Float,val paint:Paint=Paint(Paint.ANTI_ALIAS_FLAG),val rect:RectF=RectF(),val matrix:Matrix=Matrix())
    private val ambientRect=rect(1.22f,1.14f)
    private val ambient=Paint(Paint.ANTI_ALIAS_FLAG).apply {maskFilter=BlurMaskFilter(52f,BlurMaskFilter.Blur.NORMAL)}
    private val layers=arrayOf(
        Layer(0.0,rect(1.18f,1.12f),blurPaint(36f),.42f,.32f),
        Layer(1.35,rect(1.08f,1.06f),blurPaint(24f),.58f,.46f),
        Layer(2.7,rect(.96f,1f),blurPaint(14f),.88f,.72f),
        Layer(4.1,rect(.68f,.82f),blurPaint(8f),.92f,.88f)
    )
    private val tongues=arrayOf(Tongue(.8,-.18f,.38f),Tongue(2.2,.14f,.34f),Tongue(3.6,.02f,.28f))
    init {setLayerType(LAYER_TYPE_SOFTWARE,null);importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO;configurePaints()}
    private fun configurePaints() {
        val accent=if(dark)rgb(.34f,.72f,1f) else rgb(.06f,.36f,.78f)
        val deep=if(dark)rgb(.20f,.56f,.98f) else rgb(.03f,.24f,.66f)
        val glow=if(dark)rgb(.52f,.88f,1f) else rgb(.14f,.48f,.86f)
        fun a(light:Float,night:Float)=if(dark)night else light
        val radius=max(ambientRect.width(),ambientRect.height())*.95f
        ambient.shader=RadialGradient(ambientRect.centerX(),ambientRect.centerY()+ambientRect.height()*.08f,radius,intArrayOf(alpha(glow,a(.48f,.38f)),alpha(deep,a(.10f,.04f)),Color.TRANSPARENT),floatArrayOf(8f/radius,.5f,1f),Shader.TileMode.CLAMP)
        ambient.xfermode=if(dark)additive else null
        val colors=arrayOf(
            intArrayOf(alpha(glow,a(.62f,.45f)),alpha(deep,a(.12f,.03f))),
            intArrayOf(alpha(glow,a(.78f,.58f)),alpha(deep,a(.22f,.10f))),
            intArrayOf(alpha(accent,a(.96f,.88f)),alpha(deep,a(.58f,.38f))),
            intArrayOf(alpha(Color.WHITE,a(.42f,.90f)),alpha(accent,a(.92f,.82f)))
        )
        layers.forEachIndexed {index,layer->
            val r=layer.rect
            layer.paint.shader=LinearGradient(r.centerX(),r.bottom,r.centerX(),r.top,colors[index],null,Shader.TileMode.CLAMP)
            layer.paint.xfermode=if(dark&&index<2)additive else null
        }
        tongues.forEach {tongue->
            val w=210*tongue.scale;val h=252*tongue.scale*.78f
            tongue.paint.shader=LinearGradient(w/2,h,w/2,0f,intArrayOf(alpha(Color.WHITE,a(.48f,.82f)),alpha(accent,a(.42f,.28f))),null,Shader.TileMode.CLAMP)
            tongue.paint.maskFilter=BlurMaskFilter(6f,BlurMaskFilter.Blur.NORMAL)
            tongue.paint.xfermode=if(dark)additive else null
        }
    }
    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        val scale=min(width/370f,height/412f);val activityAlpha=if(playbackActive)1f else .92f
        canvas.save();canvas.translate((width-370*scale)/2,(height-412*scale)/2);canvas.scale(scale,scale);canvas.translate(80f,80f)
        makePath(ambientRect,.2)
        ambient.alpha=(255*(if(dark).42f else .52f)*activityAlpha).toInt()
        canvas.save();canvas.scale(.92f,1.08f,105f,126f);canvas.drawPath(path,ambient);canvas.restore()
        for(layer in layers) {
            makePath(layer.rect,layer.phase)
            layer.paint.alpha=(255*(if(dark)layer.darkOpacity else layer.lightOpacity)*activityAlpha).toInt()
            canvas.drawPath(path,layer.paint)
        }
        for(tongue in tongues) {
            val phase=tongue.phase;val w=210*tongue.scale;val h=252*tongue.scale*.78f
            val cx=210*(.5f+tongue.offset)+sin(frameTime*5.4+phase).toFloat()*210*.035f
            val y=252*.04f+sin(frameTime*4.1+phase).toFloat()*5f
            tongue.rect.set(cx-w/2,y,cx+w/2,y+h)
            makePath(tongue.rect,phase+1.7,.62f)
            tongue.matrix.setTranslate(tongue.rect.left,tongue.rect.top);tongue.paint.shader?.setLocalMatrix(tongue.matrix)
            tongue.paint.alpha=(255*(.5+sin(frameTime*6.2+phase)*.2)*activityAlpha).toInt()
            canvas.drawPath(path,tongue.paint)
        }
        canvas.restore()
    }
    private fun rect(widthScale:Float,heightScale:Float):RectF {
        val x=210*(1-widthScale)/2;val y=252*(1-heightScale)*.22f
        return RectF(x,y,x+210*widthScale,y+252*heightScale)
    }
    private fun blurPaint(radius:Float)=Paint(Paint.ANTI_ALIAS_FLAG).apply {maskFilter=BlurMaskFilter(radius,BlurMaskFilter.Blur.NORMAL)}
    private fun makePath(r:RectF,phase:Double,split:Float=1f) {
        val w=r.width();val h=r.height();val cx=r.centerX();val bottom=r.bottom;val t=frameTime
        val primary=sin(t*4.4+phase).toFloat()*w*.06f*split
        val secondary=sin(t*6.1+phase*1.4).toFloat()*w*.042f*split
        val tertiary=cos(t*3.3+phase*.8).toFloat()*w*.038f*split
        val stretch=sin(t*2.8+phase*.6).toFloat()*h*.06f
        val base=w*.20f;val belly=w*.44f;val bellyY=bottom-h*.52f+sin(t*3.2+phase).toFloat()*h*.02f
        val leftTipX=cx-w*.14f+primary;val rightTipX=cx+w*.12f+secondary;val centerTipX=cx+tertiary*.4f
        val leftTipY=r.top+stretch+h*.04f;val rightTipY=r.top+stretch*.7f+h*.07f;val centerTipY=r.top+stretch+h*.02f
        val leftMidX=cx-belly*.72f+secondary;val rightMidX=cx+belly*.78f+tertiary;val midY=bellyY-h*.08f
        path.reset();path.moveTo(cx-base,bottom)
        path.cubicTo(cx-belly,bottom-h*.18f,leftMidX,midY,leftTipX,leftTipY)
        path.quadTo(cx-w*.04f+primary*.3f,r.top+h*.12f,centerTipX,centerTipY)
        path.quadTo(cx+w*.06f+secondary*.25f,r.top+h*.14f,rightTipX,rightTipY)
        path.cubicTo(rightMidX,midY+h*.04f,cx+belly*.92f,bottom-h*.16f,cx+base,bottom)
        path.quadTo(cx,bottom-h*.035f,cx-base,bottom);path.close()
    }
    private fun rgb(r:Float,g:Float,b:Float)=Color.rgb((255*r).roundToInt(),(255*g).roundToInt(),(255*b).roundToInt())
    private fun alpha(color:Int,value:Float)=(color and 0xFFFFFF) or ((value*255).roundToInt().coerceIn(0,255) shl 24)
}
