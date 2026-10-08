package com.tenkdesign.android

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

/** The original uses positive peaks of the first channel, not absolute amplitude or RMS. */
object WaveformModel {
    fun downsample(samples:FloatArray,count:Int):FloatArray {
        require(count in 0..100_000)
        if(count==0)return floatArrayOf()
        val chunk=samples.size/count
        return FloatArray(count) {index ->
            val start=index*chunk;val end=min((index+1)*chunk,samples.size)
            if(start==end)0f else {
                var peak=Float.NEGATIVE_INFINITY
                for(i in start until end) {val sample=samples[i].takeIf {it.isFinite()}?:0f;if(sample>peak)peak=sample}
                peak
            }
        }
    }
    fun progress(value:Float)=if(value.isFinite())value.coerceIn(0f,1f)else 0f
    fun clock(seconds:Double):String {
        val total=if(seconds.isFinite())seconds.coerceIn(0.0,Int.MAX_VALUE.toDouble()).toInt()else 0
        return "${total/60}:${(total%60).toString().padStart(2,'0')}"
    }
}
data class WaveformAudio(val firstChannel:FloatArray,val sampleRate:Int) {
    init {require(sampleRate>0)}
    val durationSeconds:Double get()=firstChannel.size.toDouble()/sampleRate
}

/** Local RIFF/WAVE PCM16/24/32 and IEEE float32 reader. Compressed/RF64/extensible formats require a host decoder. */
object WaveformWavReader {
    const val MAX_BYTES=64*1024*1024
    fun decode(bytes:ByteArray):WaveformAudio {
        require(bytes.size in 12..MAX_BYTES) {"WAV size is invalid or exceeds 64 MiB"}
        fun ascii(offset:Int,count:Int)=String(bytes,offset,count,Charsets.US_ASCII)
        require(ascii(0,4)=="RIFF"&&ascii(8,4)=="WAVE") {"Expected RIFF WAVE"}
        val b=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        fun u32(at:Int)=b.getInt(at).toLong() and 0xffffffffL
        val declaredEnd=8L+u32(4)
        require(declaredEnd in 12..bytes.size.toLong()) {"Truncated RIFF payload"}
        var offset=12L;var format=0;var channels=0;var rate=0;var bits=0;var align=0
        var dataStart=-1;var dataSize=0
        while(offset+8<=declaredEnd) {
            val position=offset.toInt();val length=u32(position+4);val end=offset+8+length
            require(end<=declaredEnd) {"Truncated WAV chunk"}
            when(ascii(position,4)) {
                "fmt " -> {
                    require(length>=16) {"Truncated WAV format"}
                    format=b.getShort(position+8).toInt() and 0xffff
                    channels=b.getShort(position+10).toInt() and 0xffff
                    rate=b.getInt(position+12)
                    align=b.getShort(position+20).toInt() and 0xffff
                    bits=b.getShort(position+22).toInt() and 0xffff
                }
                "data" -> if(dataStart<0){dataStart=position+8;dataSize=length.toInt()}
            }
            offset=end+(length and 1)
        }
        require(channels in 1..32&&rate in 1..768000) {"Invalid channel count or sample rate"}
        require((format==1&&bits in listOf(16,24,32))||(format==3&&bits==32)) {"Unsupported WAV encoding"}
        require(align==channels*(bits/8)&&dataStart>=0&&dataSize%align==0) {"Invalid PCM frame layout"}
        val samples=FloatArray(dataSize/align) {frame ->
            val at=dataStart+frame*align
            val value=when {
                format==3 -> b.getFloat(at)
                bits==16 -> b.getShort(at)/32768f
                bits==24 -> (((bytes[at].toInt() and 255) or ((bytes[at+1].toInt() and 255) shl 8) or (bytes[at+2].toInt() shl 16)))/8388608f
                else -> b.getInt(at)/2147483648f
            }
            if(value.isFinite())value.coerceIn(-1f,1f)else 0f
        }
        return WaveformAudio(samples,rate)
    }
}
