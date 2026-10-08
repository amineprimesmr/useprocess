package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable fun TenKStaggeredGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    var shown by remember {mutableStateOf(false)}
    var horizontal by remember {mutableStateOf(false)}
    var same by remember {mutableStateOf(false)}
    var scale by remember {mutableFloatStateOf(.95f)}
    val config=StaggeredConfig(offsetX=if(horizontal)420.dp else 0.dp,offsetY=if(horizontal)0.dp else 100.dp,scale=scale,disappearInSameDirection=same)
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(15.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text("Staggered Animation",fontSize=24.sp)
        Row(verticalAlignment=Alignment.CenterVertically) {Text("Same Direction",Modifier.weight(1f));Switch(same,{same=it})}
        Row(verticalAlignment=Alignment.CenterVertically) {Text("Horizontally",Modifier.weight(1f));Switch(horizontal,{horizontal=it})}
        Text("Scale");Slider(scale,{scale=it})
        Button(onClick={shown=!shown},modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(10.dp)){Text("Toggle View")}
        TenKStaggeredColumn(shown,10,config=config,reduceMotion=reduceMotion) {
            val brush=Brush.verticalGradient(listOf(Color.Gray.copy(alpha=.8f),Color.Gray.copy(alpha=.6f)))
            Row(horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
                Box(Modifier.size(55.dp).background(brush,CircleShape))
                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.fillMaxWidth().padding(end=20.dp).height(10.dp).background(brush,RoundedCornerShape(5.dp)))
                    Box(Modifier.fillMaxWidth().padding(end=140.dp).height(10.dp).background(brush,RoundedCornerShape(5.dp)))
                    Box(Modifier.width(100.dp).height(10.dp).background(brush,RoundedCornerShape(5.dp)))
                }
            }
        }
    }
}
