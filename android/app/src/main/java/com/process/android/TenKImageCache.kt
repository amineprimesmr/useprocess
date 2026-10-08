package com.process.android
import java.io.*
import java.nio.file.*
import java.security.MessageDigest
import java.time.*
import java.util.UUID

/** A private, scoped, FIFO disk cache. Its operations only touch its own hashed image files. */
class TenKImageCache(
 cacheDirectory:File,scopeKey:String,private val limit:Int=30,private val byteLimit:Long=64L*1024*1024,
 private val clock:()->Instant={Instant.now()},private val zone:ZoneId=ZoneId.systemDefault(),
) {
 init {require(scopeKey.isNotBlank());require(limit>0);require(byteLimit>0)}
 private val directory=File(File(cacheDirectory,"tenk-downsized-images"),digest(scopeKey)).apply {check(mkdirs()||isDirectory)}
 private data class Entry(val file:File,val created:Long,val expires:Long,val size:Int)
 private fun files()=directory.listFiles()?.filter {it.isFile&&it.name.matches(Regex("image-[0-9a-f]{64}\\.bin"))}.orEmpty()
 private fun file(key:String)=File(directory,"image-${digest(key)}.bin")
 private fun metadata(file:File):Entry? {
  if(!file.exists())return null
  return try {DataInputStream(BufferedInputStream(FileInputStream(file))).use {input->
   require(input.readInt()==0x54454E4B);val created=input.readLong();val expires=input.readLong();val size=input.readInt()
   require(size>0&&size.toLong()<=byteLimit&&size<=32*1024*1024&&file.length()==size.toLong()+24)
   Entry(file,created,expires,size)
  }}catch(_:IOException){file.delete();null}catch(_:IllegalArgumentException){file.delete();null}
 }
 private fun validEntries():List<Entry> {
  val now=clock().toEpochMilli()
  return files().mapNotNull {f->metadata(f)?.takeIf {if(it.expires<=now){f.delete();false}else true}}.sortedWith(compareBy<Entry>{it.created}.thenBy {it.file.name})
 }
 @Synchronized fun get(key:String):ByteArray? {
  require(key.isNotBlank());val entry=metadata(file(key))?:return null
  if(entry.expires<=clock().toEpochMilli()){entry.file.delete();return null}
  return try {DataInputStream(BufferedInputStream(FileInputStream(entry.file))).use {it.skipBytes(24);ByteArray(entry.size).also {bytes->it.readFully(bytes)}}}catch(_:IOException){entry.file.delete();null}
 }
 @Synchronized fun put(key:String,data:ByteArray,expirationDays:Long=1) {
  require(key.isNotBlank());require(data.isNotEmpty()&&data.size<=32*1024*1024&&data.size.toLong()<=byteLimit);require(expirationDays>0)
  val now=clock();val expires=now.atZone(zone).plusDays(expirationDays).toInstant().toEpochMilli();val destination=file(key)
  val temp=File(directory,"writing-${UUID.randomUUID()}.tmp")
  try {
   DataOutputStream(BufferedOutputStream(FileOutputStream(temp))).use {it.writeInt(0x54454E4B);it.writeLong(now.toEpochMilli());it.writeLong(expires);it.writeInt(data.size);it.write(data)}
   try {Files.move(temp.toPath(),destination.toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING)}
   catch(_:AtomicMoveNotSupportedException){Files.move(temp.toPath(),destination.toPath(),StandardCopyOption.REPLACE_EXISTING)}
   val entries=validEntries().toMutableList();var total=entries.sumOf {it.size.toLong()}
   while(entries.size>limit||total>byteLimit) {val oldest=entries.removeAt(0);if(!oldest.file.delete())throw IOException("Cannot trim image cache");total-=oldest.size}
  }finally {temp.delete()}
 }
 @Synchronized fun remove(key:String){require(key.isNotBlank());file(key).delete()}
 @Synchronized fun clear(){files().forEach {it.delete()}}
 @Synchronized fun prune(){validEntries()}
 companion object {
  private fun digest(value:String)=MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8)).joinToString(""){"%02x".format(it)}
  fun imageKey(id:String,revision:String,width:Int,height:Int):String {
   require(id.isNotBlank()&&revision.isNotBlank()&&width>0&&height>0)
   return "${id.length}:$id:${revision.length}:$revision:$width:$height"
  }
 }
}
