package com.process.android
import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import java.io.File
import kotlinx.coroutines.*
@Composable fun TenKPdfGallery(onBack:()->Unit) {
 val context=LocalContext.current;val scope=rememberCoroutineScope();var busy by remember {mutableStateOf(false)};var file by remember {mutableStateOf<File?>(null)};var status by remember {mutableStateOf("")}
 val save=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")){uri->
  val export=file
  if(uri!=null&&export!=null)scope.launch {busy=true;try {withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri,"w")?.use {output->export.inputStream().use {it.copyTo(output)}}?:error("Destination unavailable")};status="PDF enregistré"}catch(error:CancellationException){throw error}catch(_:Exception){status="Échec de l’enregistrement"}finally {busy=false}}
 }
 fun export(share:Boolean) {if(busy)return;busy=true;scope.launch {
  try {
   val pdf=file?.takeIf {it.exists()}?:withContext(Dispatchers.Default){TenKPdfSample.create(context.cacheDir)}.also {file=it}
   ensureActive()
   if(share){val uri=FileProvider.getUriForFile(context,"${context.packageName}.pdf-files",pdf);val intent=Intent(Intent.ACTION_SEND).setType("application/pdf").putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);context.startActivity(Intent.createChooser(intent,"Share PDF"))}
   else save.launch("sample-transactions.pdf")
  }catch(error:CancellationException){throw error}catch(_:Exception){status="Échec de la création du PDF"}finally {busy=false}
 }}
 val dark=isSystemInDarkTheme();val bg=if(dark)Color.Black else Color(0xFFF2F2F7);val fg=if(dark)Color.White else Color.Black
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(bg).padding(15.dp),verticalArrangement=Arrangement.spacedBy(15.dp)) {
  Row(verticalAlignment=Alignment.CenterVertically){Text("PDF Helper",Modifier.weight(1f),fontSize=34.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  Text("Usage",color=Color.Gray,fontSize=12.sp)
  Text("TenKPdfMaker.create(cacheDirectory, pageCount = 3) { canvas, pageIndex ->\n    // Draw page content\n}",Modifier.fillMaxWidth().background(if(dark)Color(0xFF1C1C1E)else Color.White,RoundedCornerShape(10.dp)).padding(15.dp),fontFamily=FontFamily.Monospace,fontSize=14.sp,color=fg)
  TextButton({export(true)},enabled=!busy){Text("Share Link Demo")}
  TextButton({export(false)},enabled=!busy){Text("File Mover Demo")}
  Text("50 opérations fictives originales, réparties sur 7 pages. Aucune donnée de compte n’est utilisée.",fontSize=12.sp,color=Color.Gray)
  if(busy)CircularProgressIndicator()
  if(status.isNotEmpty())Text(status,color=fg)
 }
}
