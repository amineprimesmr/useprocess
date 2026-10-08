package com.process.android
import com.tenkdesign.android.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Test
import org.junit.Assert.*
class WaveformModelTest {
 @Test fun originalPositivePeakAndDiscardedRemainderArePreserved() {
  assertArrayEquals(floatArrayOf(.2f,-.1f),WaveformModel.downsample(floatArrayOf(-.9f,.2f,-.3f,-.1f,1f),2),.00001f)
  assertArrayEquals(FloatArray(4),WaveformModel.downsample(floatArrayOf(.9f),4),0f)
  assertTrue(WaveformModel.downsample(floatArrayOf(1f),0).isEmpty())
 }
 private fun wav(format:Int,bits:Int,channels:Int,data:ByteArray):ByteArray {
  val b=ByteBuffer.allocate(44+data.size).order(ByteOrder.LITTLE_ENDIAN)
  b.put("RIFF".toByteArray());b.putInt(36+data.size);b.put("WAVEfmt ".toByteArray());b.putInt(16)
  b.putShort(format.toShort());b.putShort(channels.toShort());b.putInt(8000);b.putInt(8000*channels*bits/8)
  b.putShort((channels*bits/8).toShort());b.putShort(bits.toShort());b.put("data".toByteArray());b.putInt(data.size);b.put(data)
  return b.array()
 }
 @Test fun stereoReaderKeepsOnlyOriginalFirstChannel() {
  val pcm=ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putShort(16384).putShort(-32768).putShort(-16384).putShort(32767).array()
  val result=WaveformWavReader.decode(wav(1,16,2,pcm))
  assertArrayEquals(floatArrayOf(.5f,-.5f),result.firstChannel,0f);assertEquals(.00025,result.durationSeconds,0.0)
 }
 @Test fun signed24BitAndFloatAreDecodedWithoutNaN() {
  assertArrayEquals(floatArrayOf(-1f,0.5f),WaveformWavReader.decode(wav(1,24,1,byteArrayOf(0,0,0x80.toByte(),0,0,0x40))).firstChannel,0f)
  val floats=ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putFloat(Float.NaN).putFloat(.25f).array()
  assertArrayEquals(floatArrayOf(0f,.25f),WaveformWavReader.decode(wav(3,32,1,floats)).firstChannel,0f)
 }
 @Test fun malformedAndCompressedFilesFailExplicitly() {
  for(bytes in listOf(ByteArray(12),wav(6,16,1,ByteArray(4)),wav(1,16,2,ByteArray(3)),wav(1,16,1,ByteArray(4)).dropLast(1).toByteArray())) {
   try {WaveformWavReader.decode(bytes);fail("Malformed WAV accepted")}catch(_:IllegalArgumentException){}
  }
 }
 @Test fun progressAndClockAreBounded() {
  assertEquals(0f,WaveformModel.progress(Float.NaN),0f);assertEquals(1f,WaveformModel.progress(2f),0f)
  assertEquals("1:05",WaveformModel.clock(65.9));assertEquals("0:00",WaveformModel.clock(Double.NaN))
 }
}
