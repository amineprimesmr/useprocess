package com.tenkdesign.android
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import com.process.android.R

/** Original tutorial avatar, recovered unchanged from its hash-matched source ZIP. */
@Composable fun TenKAnimatedKeypadGallery(onContinue:()->Unit,modifier:Modifier=Modifier,reduceMotion:Boolean=false,english:Boolean=false) {
    var value by remember {mutableStateOf(AnimatedKeypadValue())}
    TenKAnimatedKeypad(value,{value=it},{onContinue()},modifier,reduceMotion=reduceMotion,recipient={
        Column(horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(6.dp)) {
            Image(painterResource(R.drawable.keypad_recipient),"iJustine",Modifier.size(100.dp).clip(CircleShape),contentScale=ContentScale.Crop)
            Text("iJustine",color=Color.White,fontSize=12.sp,fontWeight=FontWeight.SemiBold)
            Text(if(english)"Preview — no money is sent"else"Aperçu — aucun argent envoyé",color=Color.Gray,fontSize=11.sp)
        }
    })
}
