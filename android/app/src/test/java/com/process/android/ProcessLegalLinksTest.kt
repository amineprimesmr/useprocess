package com.process.android
import org.junit.Test
import org.junit.Assert.*
class ProcessLegalLinksTest {
 @Test fun sourceLocaleAndFragmentOrder() {val l=ProcessLegalLinks();assertEquals("https://processdebloat.com/confidentialite?lang=en#donnees-faciales",l.page(ProcessLegalPage.FACE_DATA,"en"));assertEquals("https://processdebloat.com/cgu",l.page(ProcessLegalPage.TERMS,"en&evil=1"))}
 @Test fun unexpectedOriginsAndMailHeadersAreRejected() {for(url in listOf("http://useprocess.xyz","https://evil.test","https://evil@useprocess.xyz","https://useprocess.xyz:8443"))assertEquals("https://processdebloat.com",ProcessLegalLinks(url).origin);assertEquals("contact@processdebloat.com",ProcessLegalLinks(supportEmail="a@b.com\r\nBcc: bad@example.com").supportEmail);assertEquals("https://useprocess.xyz",ProcessLegalLinks("https://useprocess.xyz/a").origin)}
 @Test fun emailDraftEncodesUserTextWithoutAdditionalHeaders() {val url=ProcessLegalLinks().supportDraft("help&bcc=other@example.com\nthanks");assertTrue(url.contains("body=help%26bcc%3Dother%40example.com%0Athanks"));assertFalse(url.contains("&bcc="))}
}
