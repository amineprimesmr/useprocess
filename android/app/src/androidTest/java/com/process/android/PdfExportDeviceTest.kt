package com.process.android
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import java.util.UUID
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
/** Requires a real Android runtime. Never use host layout screenshots as proof this ran. */
@RunWith(AndroidJUnit4::class)
class PdfExportDeviceTest {
 @Test fun writesSevenReadablePagesAndCleansOnlyFailedNewOutput() {
  val root=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"pdf-test-${UUID.randomUUID()}").apply {mkdirs()}
  try {
   val pdf=TenKPdfSample.create(root);val before=pdf.readBytes()
   assertEquals("%PDF-",before.take(5).toByteArray().toString(Charsets.US_ASCII))
   PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY)).use {renderer->assertEquals(7,renderer.pageCount);renderer.openPage(6).use {assertEquals(595,it.width);assertEquals(842,it.height)}}
   try {TenKPdfMaker.create(root,2){_,_->error("Draw failed")};fail("Expected failure")}catch(_:IllegalStateException){}
   assertArrayEquals(before,pdf.readBytes());assertEquals(1,File(root,"tenk-pdf-exports").listFiles()!!.size)
  }finally {root.deleteRecursively()}
 }
}
