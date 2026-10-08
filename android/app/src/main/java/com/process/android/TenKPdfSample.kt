package com.process.android
import android.graphics.*
import java.io.File
/** Explicit source demonstration data,not financial account records. */
object TenKPdfSample {
 const val rowCount=50
 const val rowsPerPage=8
 val pageCount:Int get()=(rowCount+rowsPerPage-1)/rowsPerPage
 fun create(cacheDirectory:File)=TenKPdfMaker.create(cacheDirectory,pageCount){canvas,index->draw(canvas,index)}
 fun draw(canvas:Canvas,page:Int) {
  require(page in 0 until pageCount)
  val paint=Paint(Paint.ANTI_ALIAS_FLAG);canvas.drawColor(Color.WHITE)
  fun text(value:String,x:Float,y:Float,size:Float,color:Int=Color.BLACK,bold:Boolean=false) {paint.textSize=size;paint.color=color;paint.typeface=if(bold)Typeface.create("sans-serif",Typeface.BOLD)else Typeface.create("sans-serif",Typeface.NORMAL);canvas.drawText(value,x,y,paint)}
  paint.color=Color.BLACK;canvas.drawRoundRect(15f,15f,65f,65f,15f,15f,paint)
  // Android document mark replaces the source Apple-only system glyph; layout stays50x50.
  paint.color=Color.WHITE;paint.style=Paint.Style.STROKE;paint.strokeWidth=2f;canvas.drawRoundRect(30f,27f,50f,54f,2f,2f,paint);canvas.drawLine(35f,35f,45f,35f,paint);canvas.drawLine(35f,41f,45f,41f,paint);paint.style=Paint.Style.FILL
  text("App - App Description",75f,36f,16f);text("Justine Ezarik",75f,55f,12f)
  val count=minOf(rowsPerPage,rowCount-page*rowsPerPage)
  repeat(count){index->
   val top=95f+index*80f
   text("iPhone Air",15f,top+19f,16f)
   text("Account: $999",15f,top+38f,12f,bold=true)
   paint.color=Color.BLACK;paint.strokeWidth=.6f;canvas.drawLine(15f,top+40f,100f,top+40f,paint)
   text("Category: Apple",15f,top+56f,11f,Color.GRAY)
   text("$999",531f,top+25f,16f,Color.rgb(52,199,89),true)
   text("24 Sep 2025",514f,top+46f,11f,Color.GRAY)
   paint.color=Color.rgb(220,220,220);paint.strokeWidth=.5f;canvas.drawLine(15f,top+70f,580f,top+70f,paint)
  }
  text("${page+1}",294f,832f,12f,bold=true)
 }
}
