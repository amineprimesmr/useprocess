package com.process.android

import android.graphics.*
import android.os.Build
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import kotlin.math.*

/** Procedural texture follows the original Swift Canvas seeds, drawn once per size/density. */
@Composable internal fun ProcessReferralMetalSurface() {
    var size by remember {mutableStateOf(IntSize.Zero)}
    val density=LocalDensity.current.density
    val bitmap=remember(size,density) {if(size.width>0&&size.height>0)metalBitmap(size.width,size.height,density) else null}
    androidx.compose.foundation.layout.Box(Modifier.fillMaxSize().onSizeChanged {size=it}) {
        bitmap?.let {Image(it.asImageBitmap(),null,Modifier.fillMaxSize(),contentScale=ContentScale.FillBounds)}
    }
}
private fun metalBitmap(width:Int,height:Int,density:Float):Bitmap {
    val bitmap=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
    val canvas=Canvas(bitmap);canvas.scale(density,density)
    val w=width/density;val h=height/density;val rect=RectF(0f,0f,w,h)
    val p=Paint(Paint.ANTI_ALIAS_FLAG)
    val shape=Path().apply {addRoundRect(rect,26f,26f,Path.Direction.CW)}
    canvas.clipPath(shape)
    fun rgba(r:Float,g:Float,b:Float,a:Float=1f)=Color.argb((a*255).roundToInt(),(r*255).roundToInt(),(g*255).roundToInt(),(b*255).roundToInt())
    fun white(a:Float)=rgba(1f,1f,1f,a)
    fun black(a:Float)=rgba(0f,0f,0f,a)
    fun mode(name:String) {
        if(Build.VERSION.SDK_INT>=29)p.blendMode=when(name) {"screen"->BlendMode.SCREEN;"overlay"->BlendMode.OVERLAY;"soft"->BlendMode.SOFT_LIGHT;"multiply"->BlendMode.MULTIPLY;else->BlendMode.SRC_OVER}
        else p.xfermode=PorterDuffXfermode(when(name) {"screen"->PorterDuff.Mode.SCREEN;"overlay"->PorterDuff.Mode.OVERLAY;"multiply"->PorterDuff.Mode.MULTIPLY;else->PorterDuff.Mode.SRC_OVER})
    }
    fun layer(shader:Shader,blend:String="normal",alpha:Float=1f) {mode(blend);p.shader=shader;p.alpha=(alpha*255).roundToInt();canvas.drawRect(rect,p);p.shader=null;p.alpha=255}
    layer(LinearGradient(0f,0f,w,h,intArrayOf(rgba(.96f,.97f,.99f),rgba(.86f,.87f,.90f),rgba(.72f,.73f,.76f),rgba(.80f,.81f,.84f)),null,Shader.TileMode.CLAMP))
    layer(LinearGradient(w*.05f,0f,w*.95f,h,intArrayOf(white(1f),white(.78f),white(.22f),Color.TRANSPARENT,Color.TRANSPARENT,black(.10f)),null,Shader.TileMode.CLAMP),"screen")
    // Swift radial gradient begins at 8 points; map stops to the same radius domain.
    layer(RadialGradient(w*.28f,h*.18f,220f,intArrayOf(white(.72f),white(.72f),white(.18f),Color.TRANSPARENT),floatArrayOf(0f,8f/220f,114f/220f,1f),Shader.TileMode.CLAMP),"overlay")
    layer(SweepGradient(w*.30f,h*.24f,intArrayOf(white(.62f),white(.10f),Color.TRANSPARENT,black(.12f),white(.28f),Color.TRANSPARENT,white(.45f)),null),"overlay")
    layer(LinearGradient(0f,0f,w,h,intArrayOf(white(.82f),white(.34f),Color.TRANSPARENT,black(.16f)),null,Shader.TileMode.CLAMP),"soft")
    mode("overlay");p.strokeWidth=.65f;p.style=Paint.Style.STROKE
    val count=(h*3.2).toInt()
    repeat(count) {index -> val y=index.toFloat()/max(count-1,1)*h;val seed=(index*1903).toDouble();p.color=white(((.028+seed%.05)*.52).toFloat());canvas.drawLine(0f,y,w,y+sin(seed*.7).toFloat()*.55f,p)}
    p.style=Paint.Style.FILL
    fun noise(amount:Double,maxParticle:Float,blend:String,opacity:Double) {
        mode(blend)
        repeat((w*h*amount).toInt()) {index ->
            val seed=(index*9271).toDouble();val x=(seed%max(1f,w-1)).toFloat();val y=((seed*1.37)%max(1f,h-1)).toFloat()
            val side=if(seed%maxParticle>maxParticle*.55)maxParticle else maxParticle*.62f
            // Original seed is an integer: its `% 1 > .5` branch is always false (black).
            p.color=black(((.06+seed%.16)*opacity).toFloat());canvas.drawOval(x,y,x+side,y+side,p)
        }
    }
    noise(.11,1.45f,"overlay",.92);noise(.22,.75f,"soft",.55)
    layer(RadialGradient(w/2,h/2,260f,intArrayOf(Color.TRANSPARENT,Color.TRANSPARENT,black(.14f)),floatArrayOf(0f,80f/260f,1f),Shader.TileMode.CLAMP),"multiply",.35f)
    mode("normal");p.shader=LinearGradient(0f,0f,w,h,intArrayOf(white(.96f),white(.42f),black(.14f)),null,Shader.TileMode.CLAMP);p.strokeWidth=1.25f;p.style=Paint.Style.STROKE
    canvas.drawRoundRect(RectF(.625f,.625f,w-.625f,h-.625f),25.375f,25.375f,p)
    return bitmap
}
