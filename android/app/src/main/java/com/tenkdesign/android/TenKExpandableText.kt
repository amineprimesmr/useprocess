package com.tenkdesign.android

import android.graphics.BlurMaskFilter
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.BreakIterator
import kotlin.math.*

/** TruncationEffect, Balaji Venkatesh,16/12/25. Native renderer; physical glyph parity pending. */
object ExpandableTextModel {
    fun lineProgress(index:Int,limit:Int,total:Int,progress:Float):Float {
        if(index<limit)return 1f
        val extra=(total-limit).coerceAtLeast(1)
        return ((if(progress.isFinite())progress else 0f).coerceIn(0f,1f)*extra-(index-limit)).coerceIn(0f,1f)
    }
    fun trailingStart(text:String,start:Int,end:Int,count:Int=6):Int {
        val segment=text.substring(start.coerceIn(0,text.length),end.coerceIn(start,text.length)).trimEnd('\n','\r')
        val breaker=BreakIterator.getCharacterInstance().apply {setText(segment)}
        var offset=breaker.last()
        repeat(count.coerceAtLeast(0)) {val previous=breaker.previous();if(previous!=BreakIterator.DONE)offset=previous else offset=0}
        return start+offset
    }
}

@Composable fun TenKExpandableText(
    text:String,collapsed:Boolean,onCollapsedChange:(Boolean)->Unit,modifier:Modifier=Modifier,
    lineLimit:Int=2,fontSize:androidx.compose.ui.unit.TextUnit=16.sp,color:Color=MaterialTheme.colorScheme.onSurface,
    moreLabel:String="...More",reduceMotion:Boolean=false,expandedLabel:String="Expanded",collapsedLabel:String="Collapsed",
) {
    val density=LocalDensity.current;val limit=lineLimit.coerceAtLeast(1)
    val pixels=with(density){fontSize.toPx()};val blurPx=with(density){5.dp.toPx()}
    val progress by animateFloatAsState(if(collapsed)0f else 1f,if(reduceMotion)snap()else spring(1f,220f),label="text.line.reveal")
    BoxWithConstraints(modifier) {
        require(constraints.hasBoundedWidth) {"Expandable text requires a bounded width"}
        val width=with(density){maxWidth.roundToPx()}.coerceAtLeast(1)
        val paint=remember(pixels,color) {TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {textSize=pixels;this.color=color.toArgb();typeface=Typeface.DEFAULT}}
        val layout=remember(text,width,paint) {StaticLayout.Builder.obtain(text,0,text.length,paint,width).setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).build()}
        val limitedHeight=layout.getLineBottom(min(limit,layout.lineCount)-1)
        // The source keeps collapsed geometry until its reveal reaches its final state.
        val height=if(progress>=.9999f)layout.height else limitedHeight
        val cutLine=(limit-1).coerceAtMost(layout.lineCount-1)
        val suffixStart=remember(text,layout,limit) {ExpandableTextModel.trailingStart(text,layout.getLineStart(cutLine),layout.getLineEnd(cutLine))}
        val suffixX=layout.getPrimaryHorizontal(suffixStart)
        val suffixPaint=remember(pixels){TextPaint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {textSize=pixels;this.color=android.graphics.Color.GRAY;typeface=Typeface.DEFAULT}}
        val toggle=layout.lineCount>limit
        Canvas(Modifier.fillMaxWidth().height(with(density){height.toDp()}).then(if(toggle)Modifier.clickable {onCollapsedChange(!collapsed)}else Modifier).semantics {
            this.text=AnnotatedString(text);stateDescription=if(collapsed)collapsedLabel else expandedLabel
        }) {
            val canvas=drawContext.canvas.nativeCanvas
            for(line in 0 until layout.lineCount) {
                val top=layout.getLineTop(line).toFloat();val bottom=layout.getLineBottom(line).toFloat()
                val lineP=ExpandableTextModel.lineProgress(line,limit,layout.lineCount,progress)
                if(lineP==0f)continue
                val saved=canvas.save();canvas.clipRect(0f,top,width.toFloat(),bottom)
                paint.alpha=(255*lineP).roundToInt();paint.maskFilter=if(line>=limit&&lineP<1f)BlurMaskFilter(blurPx*(1-lineP),BlurMaskFilter.Blur.NORMAL)else null
                if(line==cutLine&&toggle) {
                    val head=canvas.save();canvas.clipRect(0f,top,suffixX,bottom);paint.alpha=255;layout.draw(canvas);canvas.restoreToCount(head)
                    val suffix=canvas.save();canvas.clipRect(suffixX,top,width.toFloat(),bottom);paint.alpha=(255*progress).roundToInt();layout.draw(canvas);canvas.restoreToCount(suffix)
                    suffixPaint.alpha=(255*(1-progress)).roundToInt();canvas.drawText(moreLabel,suffixX,layout.getLineBaseline(line).toFloat(),suffixPaint)
                } else layout.draw(canvas)
                paint.alpha=255;paint.maskFilter=null;canvas.restoreToCount(saved)
            }
        }
    }
}
