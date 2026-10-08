package com.tenkdesign.android

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged

/** Observes the default route; connected is path availability, not an internet-service guarantee. */
class TenKNetworkMonitor(context:Context) {
    private val manager=context.applicationContext.getSystemService(ConnectivityManager::class.java)
    val status=callbackFlow {
        fun fromCapabilities(capabilities:NetworkCapabilities):NetworkStatus {
            val transports=buildSet {
                if(capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI))add(NetworkTransport.WIFI)
                if(capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR))add(NetworkTransport.CELLULAR)
                if(capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))add(NetworkTransport.ETHERNET)
                if(capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN))add(NetworkTransport.VPN)
                if(isEmpty())add(NetworkTransport.OTHER)
            }
            return NetworkStatus(true,NetworkStatusModel.preferredTransport(transports),capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
        }
        var currentNetwork:Network?=null
        val callback=object:ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network:Network) {currentNetwork=network;trySend(NetworkStatus(true))}
            override fun onLost(network:Network) {if(network==currentNetwork){currentNetwork=null;trySend(NetworkStatus(false))}}
            override fun onCapabilitiesChanged(network:Network,networkCapabilities:NetworkCapabilities) {
                if(network==currentNetwork)trySend(fromCapabilities(networkCapabilities))
            }
            override fun onUnavailable() {if(currentNetwork==null)trySend(NetworkStatus(false))}
        }
        var registered=false
        try {
            manager.registerDefaultNetworkCallback(callback,Handler(Looper.getMainLooper()));registered=true
            currentNetwork=manager.activeNetwork
            val initial=currentNetwork?.let {manager.getNetworkCapabilities(it)}
            trySend(if(currentNetwork==null)NetworkStatus(false) else if(initial!=null)fromCapabilities(initial) else NetworkStatus())
        } catch(_:SecurityException) {trySend(NetworkStatus(unavailable=true));close()}
        catch(_:RuntimeException) {trySend(NetworkStatus(unavailable=true));close()}
        awaitClose {if(registered)runCatching {manager.unregisterNetworkCallback(callback)}}
    }.distinctUntilChanged()
}

@Composable fun rememberNetworkStatus():State<NetworkStatus> {
    val context=LocalContext.current.applicationContext
    val monitor=remember(context) {TenKNetworkMonitor(context)}
    return monitor.status.collectAsStateWithLifecycle(initialValue=NetworkStatus())
}

/** Original sample UI; status comes from ConnectivityManager and cannot be set by this view. */
@Composable
fun TenKNetworkMonitorPage(modifier:Modifier=Modifier,english:Boolean=true,reduceMotion:Boolean=false) {
    val status by rememberNetworkStatus()
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(if(english)"Network Monitor"else"État du réseau",fontSize=30.sp,fontWeight=FontWeight.Bold)
        Text(if(english)"Environment Usage"else"Utilisation",color=MaterialTheme.colorScheme.onSurfaceVariant)
        Surface(shape=RoundedCornerShape(10.dp)) {Text("val status by rememberNetworkStatus()",modifier=Modifier.fillMaxWidth().padding(15.dp),fontSize=14.sp)}
        Text(if(english)"Status"else"État",color=MaterialTheme.colorScheme.onSurfaceVariant)
        Text(when {status.unavailable->if(english)"Network status unavailable"else"État du réseau indisponible";status.connected==true->if(english)"Connected"else"Connecté";else->if(english)"No Internet"else"Hors connexion"})
        status.transport?.let {transport ->
            Text(if(english)"Connection Type"else"Type de connexion",color=MaterialTheme.colorScheme.onSurfaceVariant)
            Text(transport.name)
        }
    }
    if(status.showOffline) TenKNoInternetSheet(english,reduceMotion)
}

@Composable
fun TenKNoInternetSheet(english:Boolean=true,reduceMotion:Boolean=false) {
    val morph=remember {Animatable(0f)}
    val lifecycle=LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle,reduceMotion) {
        morph.snapTo(0f)
        if(!reduceMotion) lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while(true) {
                delay(2000);morph.animateTo(1f,tween(1000,easing=CubicBezierEasing(.42f,0f,.58f,1f)))
                delay(2000);morph.animateTo(0f,tween(1000,easing=CubicBezierEasing(.42f,0f,.58f,1f)))
            }
        }
    }
    Dialog(onDismissRequest={},properties=DialogProperties(dismissOnBackPress=false,dismissOnClickOutside=false,usePlatformDefaultWidth=false)) {
        Box(Modifier.fillMaxSize().navigationBarsPadding(),contentAlignment=Alignment.BottomCenter) {
            Column(Modifier.padding(horizontal=20.dp).padding(bottom=10.dp).fillMaxWidth().heightIn(min=310.dp).clip(RoundedCornerShape(20.dp)).background(MaterialTheme.colorScheme.surface)
                .padding(top=20.dp).semantics {liveRegion=LiveRegionMode.Polite},horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
                val ink=MaterialTheme.colorScheme.onSurface
                Box(Modifier.height(100.dp).width(110.dp),contentAlignment=Alignment.Center) {
                    NetworkGlyph(false,ink,Modifier.fillMaxSize().graphicsLayer {alpha=1-morph.value}.blur((20*morph.value).dp))
                    NetworkGlyph(true,ink,Modifier.fillMaxSize().graphicsLayer {alpha=morph.value}.blur((20*(1-morph.value)).dp))
                }
                Text(if(english)"No Internet Connectivity"else"Aucune connexion Internet",fontSize=20.sp,fontWeight=FontWeight.SemiBold,textAlign=TextAlign.Center,modifier=Modifier.padding(horizontal=20.dp))
                Text(if(english)"Please check your internet connection\nto continue using the app."else"Vérifie ta connexion Internet\npour continuer à utiliser l’app.",textAlign=TextAlign.Center,color=Color.Gray,modifier=Modifier.padding(horizontal=20.dp))
                Text(if(english)"Waiting for internet connection..."else"En attente d’une connexion Internet…",fontSize=12.sp,color=MaterialTheme.colorScheme.surface,textAlign=TextAlign.Center,modifier=Modifier.fillMaxWidth().background(ink).padding(vertical=12.dp))
            }
        }
    }
}

@Composable
private fun NetworkGlyph(cellular:Boolean,ink:Color,modifier:Modifier) {
    Canvas(modifier.clearAndSetSemantics {}) {
        val unit=size.minDimension/100;val stroke=Stroke(6*unit,cap=StrokeCap.Round)
        val x=size.width/2;val y=size.height/2
        if(!cellular) {
            listOf(35f,24f,13f).forEach {r->drawArc(ink,-140f,100f,false,Offset(x-r*unit,y-r*unit+20*unit),Size(r*2*unit,r*2*unit),style=stroke)}
            drawCircle(ink,3*unit,Offset(x,y+20*unit))
            drawLine(ink,Offset(x+35*unit,y-4*unit),Offset(x+35*unit,y+13*unit),6*unit,StrokeCap.Round)
            drawCircle(ink,3*unit,Offset(x+35*unit,y+24*unit))
        } else {
            drawLine(ink,Offset(x,y-12*unit),Offset(x,y+29*unit),5*unit,StrokeCap.Round)
            drawCircle(ink,5*unit,Offset(x,y-19*unit))
            listOf(19f,31f).forEach {r ->
                drawArc(ink,-50f,100f,false,Offset(x-r*unit,y-r*unit-15*unit),Size(r*2*unit,r*2*unit),style=stroke)
                drawArc(ink,130f,100f,false,Offset(x-r*unit,y-r*unit-15*unit),Size(r*2*unit,r*2*unit),style=stroke)
            }
            drawLine(ink,Offset(x-35*unit,y-36*unit),Offset(x+35*unit,y+34*unit),5*unit,StrokeCap.Round)
        }
    }
}
