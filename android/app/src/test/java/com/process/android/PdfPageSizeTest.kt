package com.process.android
import org.junit.Test
import org.junit.Assert.*
class PdfPageSizeTest {
 @Test fun standardPaperDimensionsAndSamplePagination(){assertEquals(TenKPdfPageSize(595,842),TenKPdfPageSize.A4);assertEquals(TenKPdfPageSize(612,792),TenKPdfPageSize.USLetter);assertEquals(7,TenKPdfSample.pageCount)}
 @Test(expected=IllegalArgumentException::class) fun rejectsZeroWidth(){TenKPdfPageSize(0,842)}
 @Test(expected=IllegalArgumentException::class) fun rejectsExcessivePageSize(){TenKPdfPageSize(14401,842)}
}
