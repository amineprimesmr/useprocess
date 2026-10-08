package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.*

/** Host supplies national-number resolution, genuine provider operations, and real legal destinations. */
@Composable fun TenKMobileOtpLogin(
 contextKey:Any,service:MobileOtpService?,resolvePhone:(MobileOtpCountry,String)->String?,
 onVerified:(MobileOtpVerifiedSession)->Unit,onTerms:()->Unit,onPrivacy:()->Unit,
 modifier:Modifier=Modifier,reduceMotion:Boolean=false,countries:List<MobileOtpCountry>?=null,
 unavailableMessage:String="Phone authentication is not connected."
) {
 key(contextKey,service) {
  val context=LocalContext.current;val list=remember(context,countries){countries?:loadMobileOtpCountries(context)}
  var selected by remember {mutableStateOf(list.firstOrNull {it.code=="US"}?:list.firstOrNull {it.dialCode!=null})}
  var phone by remember {mutableStateOf("")};var picking by remember {mutableStateOf(false)}
  var request by remember {mutableStateOf<String?>(null)};var completed by remember {mutableStateOf(false)}
  val focus=LocalFocusManager.current;val verified by rememberUpdatedState(onVerified)
  val e164=selected?.let {resolvePhone(it,phone)}?.takeIf(::isMobileOtpE164)
  Column(modifier.fillMaxSize().padding(start=20.dp,end=20.dp,top=25.dp,bottom=10.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
   Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
    Text("Welcome Back",fontSize=34.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp)
    Text("Please Verify your Mobile Number to continue.",fontSize=17.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp)
   }
   Row(Modifier.padding(top=10.dp),horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically) {
    Surface(onClick={picking=true},shape=RoundedCornerShape(50),color=MaterialTheme.colorScheme.onSurface.copy(alpha=.06f),modifier=Modifier.height(50.dp)) {
     Row(Modifier.padding(horizontal=12.dp),verticalAlignment=Alignment.CenterVertically) {Text(selected?.let{"${it.dialCode} (${it.code})"}?:"Country",fontSize=15.sp);Icon(Icons.Default.ArrowDropDown,null)}
    }
    TextField(phone,{phone=it.take(32)},placeholder={Text("Mobile Number",fontSize=16.sp)},leadingIcon={Icon(Icons.Default.Phone,null,Modifier.size(20.dp))},singleLine=true,
     keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Phone),shape=RoundedCornerShape(50),
     colors=TextFieldDefaults.colors(focusedContainerColor=MaterialTheme.colorScheme.onSurface.copy(alpha=.06f),unfocusedContainerColor=MaterialTheme.colorScheme.onSurface.copy(alpha=.06f),focusedIndicatorColor=androidx.compose.ui.graphics.Color.Transparent,unfocusedIndicatorColor=androidx.compose.ui.graphics.Color.Transparent),modifier=Modifier.weight(1f).height(50.dp))
   }
   Button({focus.clearFocus();request=e164},enabled=service!=null&&e164!=null&&!completed&&request==null,shape=RoundedCornerShape(50),colors=ButtonDefaults.buttonColors(containerColor=MaterialTheme.colorScheme.onSurface,contentColor=MaterialTheme.colorScheme.surface),modifier=Modifier.fillMaxWidth().height(44.dp)) {Text("Get OTP",fontSize=17.sp,fontWeight=FontWeight.SemiBold)}
   if(service==null)Text(unavailableMessage,style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
   Spacer(Modifier.weight(1f))
   Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.Center,verticalAlignment=Alignment.CenterVertically) {
    TextButton(onTerms,colors=ButtonDefaults.textButtonColors(contentColor=MaterialTheme.colorScheme.onSurface.copy(alpha=.65f))){Text("Terms of Service",fontSize=14.sp)};Text("&");TextButton(onPrivacy,colors=ButtonDefaults.textButtonColors(contentColor=MaterialTheme.colorScheme.onSurface.copy(alpha=.65f))){Text("Privacy Policy",fontSize=14.sp)}
   }
  }
  if(picking)Dialog(onDismissRequest={picking=false}) {
   Surface(shape=RoundedCornerShape(24.dp)) {
    LazyColumn(Modifier.heightIn(max=540.dp).padding(vertical=12.dp)) {items(list.filter {!it.dialCode.isNullOrBlank()},key={it.code}) {country->
     TextButton({selected=country;picking=false},Modifier.fillMaxWidth()) {Text("${country.dialCode} (${country.code}) — ${country.name}")}
    }}
   }
  }
  val current=request
  if(current!=null&&service!=null)MobileOtpVerification(current,service,reduceMotion,{request=null}) {session ->
   if(!completed&&mobileOtpSessionMatches(current,session)){completed=true;request=null;verified(session)}
  }
 }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun MobileOtpVerification(phone:String,service:MobileOtpService,reduceMotion:Boolean,onClose:()->Unit,onVerified:(MobileOtpVerifiedSession)->Unit) {
 var challenge by remember(phone) {mutableStateOf<MobileOtpChallenge?>(null)};var code by remember(phone){mutableStateOf("")}
 var error by remember {mutableStateOf<String?>(null)};var finished by remember {mutableStateOf(false)}
 val verified by rememberUpdatedState(onVerified)
 LaunchedEffect(phone,service) {
  try {
   delay(2000)
   val result=withTimeout(60_000){service.send(phone)};currentCoroutineContext().ensureActive()
   when(result) {
    is MobileOtpSendResult.Sent->{check(result.challenge.e164==phone);challenge=result.challenge}
    is MobileOtpSendResult.Verified->{check(mobileOtpSessionMatches(phone,result.session));if(!finished){finished=true;verified(result.session)}}
   }
  }catch(_:TimeoutCancellationException){error="The request timed out. Please try again."}
  catch(e:CancellationException){throw e}catch(_:Exception){error="Unable to send the verification code. Please try again."}
 }
 val sheetState=rememberModalBottomSheetState(skipPartiallyExpanded=true,confirmValueChange={it!=SheetValue.Hidden})
 ModalBottomSheet(onDismissRequest={},sheetState=sheetState,dragHandle=null,shape=RoundedCornerShape(topStart=30.dp,topEnd=30.dp),containerColor=MaterialTheme.colorScheme.background,tonalElevation=0.dp) {
  Column(Modifier.fillMaxWidth().padding(20.dp).heightIn(min=190.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
   val sent=challenge
   if(sent==null) {
    if(error==null)MobileOtpSending(reduceMotion)else {Text("Something Went Wrong!",fontSize=22.sp,fontWeight=FontWeight.SemiBold);Text(error!!);TextButton(onClose){Text("Dismiss")}}
   } else {
    Row(Modifier.fillMaxWidth().padding(top=10.dp),verticalAlignment=Alignment.Top) {
     Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(8.dp)) {Text("Verification",fontSize=34.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp);Text("Enter the 6-digit code.",fontSize=17.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp)}
     IconButton(onClose){Icon(Icons.Default.Close,"Close verification")}
    }
    TenKVerificationCode(code,{code=it},Modifier.padding(top=12.dp).align(Alignment.CenterHorizontally),contextKey=sent.id,autoFocus=true,reduceMotion=reduceMotion,borderWidth=2.dp) {value ->
     if(value.length!=6)VerificationCodeState.TYPING else try {
      val session=withTimeout(60_000){service.verify(sent,value)};currentCoroutineContext().ensureActive()
      if(!mobileOtpSessionMatches(phone,session))VerificationCodeState.INVALID else {
       if(!finished){finished=true;verified(session)};VerificationCodeState.VALID
      }
     }catch(_:TimeoutCancellationException){VerificationCodeState.INVALID}catch(e:CancellationException){throw e}catch(_:Exception){VerificationCodeState.INVALID}
    }
   }
  }
 }
}
@Composable private fun MobileOtpSending(reduceMotion:Boolean) {
 var index by remember {mutableIntStateOf(0)};val lifecycle=LocalLifecycleOwner.current.lifecycle
 LaunchedEffect(lifecycle,reduceMotion){if(!reduceMotion)lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED){while(true){delay(1200);index=(index+1)%3}}}
 Column(Modifier.fillMaxWidth(),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(12.dp)) {
  AnimatedContent(index,transitionSpec={fadeIn(tween(if(reduceMotion)0 else 250)) togetherWith fadeOut(tween(if(reduceMotion)0 else 250))},label="sending symbol") {phase->Icon(when(phase){0->Icons.Default.Phone;1->Icons.Default.Email;else->Icons.Default.Send},null,Modifier.size(150.dp).padding(25.dp))}
  Text("Sending Verification Code...",fontSize=20.sp,fontWeight=FontWeight.SemiBold)
 }
}
