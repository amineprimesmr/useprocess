package com.tenkdesign.android

/** InternetConnectivity original source: Balaji Venkatesh, 16/04/25. */
enum class NetworkTransport { WIFI,CELLULAR,ETHERNET,VPN,OTHER }
data class NetworkStatus(val connected:Boolean?=null,val transport:NetworkTransport?=null,val validated:Boolean=false,val unavailable:Boolean=false) {
    // Unknown at startup never shows the source's non-dismissible offline sheet.
    val showOffline:Boolean get()=connected==false && !unavailable
}
object NetworkStatusModel {
    fun preferredTransport(types:Set<NetworkTransport>):NetworkTransport? = listOf(NetworkTransport.WIFI,NetworkTransport.CELLULAR,NetworkTransport.ETHERNET,NetworkTransport.VPN,NetworkTransport.OTHER).firstOrNull {it in types}
}
