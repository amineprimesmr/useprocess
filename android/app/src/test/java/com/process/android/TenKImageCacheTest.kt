package com.process.android
import java.nio.file.Files
import java.time.*
import org.junit.*
import org.junit.Assert.*
class TenKImageCacheTest {
 private lateinit var root:java.io.File
 @Before fun setup(){root=Files.createTempDirectory("tenk-cache-test").toFile()}
 @After fun cleanup(){root.deleteRecursively()}
 @Test fun expiresAtReadTimeRatherThanOnlyStartup(){var now=Instant.parse("2026-10-08T10:00:00Z");val c=TenKImageCache(root,"a",clock={now},zone=ZoneId.of("UTC"));c.put("k",byteArrayOf(1));now=now.plusSeconds(86400);assertNull(c.get("k"))}
 @Test fun evictsOldestCreationAndReplacementGetsNewCreation(){var now=Instant.EPOCH;val c=TenKImageCache(root,"a",limit=2,clock={now});c.put("a",byteArrayOf(1));now=now.plusSeconds(1);c.put("b",byteArrayOf(2));now=now.plusSeconds(1);c.put("a",byteArrayOf(3));now=now.plusSeconds(1);c.put("c",byteArrayOf(4));assertNull(c.get("b"));assertArrayEquals(byteArrayOf(3),c.get("a"));assertArrayEquals(byteArrayOf(4),c.get("c"))}
 @Test fun scopeAndHashedKeysPreventCrossAccountOrPathAccess(){val a=TenKImageCache(root,"one");val b=TenKImageCache(root,"two");a.put("../../private",byteArrayOf(1));assertNull(b.get("../../private"));b.put("b",byteArrayOf(2));a.clear();assertArrayEquals(byteArrayOf(2),b.get("b"))}
 @Test fun byteBudgetEvictsOnlyOwnedFiles(){var now=Instant.EPOCH;val c=TenKImageCache(root,"a",byteLimit=5,clock={now});c.put("a",byteArrayOf(1,2,3));now=now.plusSeconds(1);c.put("b",byteArrayOf(4,5,6));assertNull(c.get("a"));assertArrayEquals(byteArrayOf(4,5,6),c.get("b"))}
 @Test fun corruptEntryIsRejectedAndRemoved(){val c=TenKImageCache(root,"a");c.put("a",byteArrayOf(1));val f=root.walk().first {it.extension=="bin"};f.writeBytes(byteArrayOf(1,2));assertNull(c.get("a"));assertFalse(f.exists())}
 @Test fun calendarDayExpirationPreservesDstSemantics(){var now=Instant.parse("2026-10-24T12:00:00Z");val c=TenKImageCache(root,"a",clock={now},zone=ZoneId.of("Europe/Paris"));c.put("k",byteArrayOf(1));now=now.plusSeconds(86400);assertNotNull(c.get("k"));now=now.plusSeconds(3600);assertNull(c.get("k"))}
 @Test fun revisionAndPhysicalSizeArePartOfCacheIdentity(){assertNotEquals(TenKImageCache.imageKey("id","r1",100,100),TenKImageCache.imageKey("id","r2",100,100));assertNotEquals(TenKImageCache.imageKey("id","r1",100,100),TenKImageCache.imageKey("id","r1",200,100))}
}
