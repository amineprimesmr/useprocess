package com.process.android
enum class QrCameraPermission { UNREQUESTED,GRANTED,DENIED }
internal class QrCodeDelivery {
 private var closed=false;private var delivered=false
 @Synchronized fun accept(code:String?):String? {if(closed||delivered||code==null)return null;delivered=true;return code}
 @Synchronized fun close(){closed=true}
}
