package com.tenkdesign.android
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
@Composable fun TenKMobileOtpGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var legal by remember {mutableStateOf<String?>(null)}
 TenKMobileOtpLogin("preview",null,{_,_->null},{},{legal="Terms of Service"},{legal="Privacy Policy"},modifier,reduceMotion,unavailableMessage="Preview only. SMS provider and current phone-number validation are not connected.")
 legal?.let {title->AlertDialog(onDismissRequest={legal=null},title={Text(title)},text={Text("Connect your real legal destination in the host app. The original placeholder URL is not used.")},confirmButton={TextButton({legal=null}){Text("Close")}})}
}
