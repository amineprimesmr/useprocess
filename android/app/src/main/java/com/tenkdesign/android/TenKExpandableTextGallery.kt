package com.tenkdesign.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Original TruncationEffect sample text, Balaji Venkatesh,16/12/25. */
val expandableSampleText = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
@Composable fun TenKExpandableTextGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
        Text("Instagram",fontSize=30.sp)
        repeat(2) {
            var collapsed by remember {mutableStateOf(true)}
            Column(verticalArrangement=Arrangement.spacedBy(6.dp)) {
                Box(Modifier.fillMaxWidth().height(250.dp).background(Color.Gray.copy(alpha=.15f)))
                TenKExpandableText(expandableSampleText,collapsed,{collapsed=it},reduceMotion=reduceMotion)
                Text("15 mins ago",fontSize=11.sp,color=Color.Gray,modifier=Modifier.padding(top=5.dp))
            }
        }
    }
}
