package com.process.android
import android.graphics.Canvas
import android.graphics.pdf.PdfDocument
import android.os.Looper
import android.view.View
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** PdfDocument requires integer PostScript points; source A4 595.2x841.8 rounds to595x842. */
data class TenKPdfPageSize(val width:Int,val height:Int) {
 init {require(width in 1..14400&&height in 1..14400)}
 companion object {val A4=TenKPdfPageSize(595,842);val USLetter=TenKPdfPageSize(612,792)}
}
object TenKPdfMaker {
 /** Caller owns draw threading. Newly generated files are private and never overwrite existing ones. */
 fun create(cacheDirectory:File,pageCount:Int,size:TenKPdfPageSize=TenKPdfPageSize.A4,drawPage:(Canvas,Int)->Unit):File {
  require(pageCount in 1..1000)
  val directory=File(cacheDirectory,"tenk-pdf-exports").apply {check(mkdirs()||isDirectory)}
  val output=File(directory,"document-${UUID.randomUUID()}.pdf");val document=PdfDocument()
  try {
   repeat(pageCount){index->
    val page=document.startPage(PdfDocument.PageInfo.Builder(size.width,size.height,index+1).create())
    try {drawPage(page.canvas,index)}finally {document.finishPage(page)}
   }
   FileOutputStream(output).use {document.writeTo(it)}
   check(output.length()>0);return output
  }catch(error:Throwable){output.delete();throw error}finally {document.close()}
 }
 /** Host views must already be measured; Compose/native views draw on their owning main thread. */
 fun createFromViews(cacheDirectory:File,pages:List<View>,size:TenKPdfPageSize=TenKPdfPageSize.A4):File {
  check(Looper.myLooper()==Looper.getMainLooper()){"View drawing requires the main thread"}
  require(pages.all {it.width>0&&it.height>0})
  return create(cacheDirectory,pages.size,size){canvas,index->
   val view=pages[index];val scale=minOf(size.width.toFloat()/view.width,size.height.toFloat()/view.height)
   val save=canvas.save();try {canvas.scale(scale,scale);view.draw(canvas)}finally {canvas.restoreToCount(save)}
  }
 }
}
