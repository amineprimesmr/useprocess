package com.tenkdesign.android
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@Composable fun TenKVerificationGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var value by remember {mutableStateOf("")};var length by remember {mutableStateOf(VerificationCodeLength.FOUR)};var style by remember {mutableStateOf(VerificationCodeStyle.ROUNDED)}
 Column(modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
  Text("Verification code",style=MaterialTheme.typography.headlineLarge)
  Row {VerificationCodeLength.entries.forEach {type->FilterChip(length==type,{length=type;value=""},{Text("${type.digits} digits")},Modifier.padding(end=8.dp))}}
  Row {VerificationCodeStyle.entries.forEach {s->FilterChip(style==s,{style=s},{Text(if(s==VerificationCodeStyle.ROUNDED)"Rounded" else "Underlined")},Modifier.padding(end=8.dp))}}
  TenKVerificationCode(value,{value=it},length=length,style=style,reduceMotion=reduceMotion) {code ->
   if(code.length<length.digits)VerificationCodeState.TYPING else if(code==if(length==VerificationCodeLength.FOUR)"1235" else "451245")VerificationCodeState.VALID else VerificationCodeState.INVALID
  }
  Text("Preview only. Original demo codes: 1235 / 451245. No account authentication.",style=MaterialTheme.typography.bodySmall)
 }
}
