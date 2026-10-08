package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
private val originalContactNames=listOf("John Doe","Jane Smith","Alice Johnson","Bob Brown","Charlie White","David Clark","Eve Davis","Frank Miller","Grace Lee","Hank Wilson","Ivy Moore","Jack Taylor","Kathy Anderson","Louis Thomas","Mona Jackson","Nina Harris","Oscar King","Paul Scott","Quincy Adams","Rachel Parker","Sam Mitchell","Tina Garcia","Ursula Rodriguez","Victor Lee","Wendy Walker","Xander Lopez","Yara Perez","Zane Bennett","Abigail Cooper","Ben Foster","Catherine James","Dylan Simmons","Eva Roberts","Felix Gray","Georgia Miller","Holly Carter","Ian Phillips","Jasmine Bennett","Keith Walker","Lily Evans","Monica Ross","Nolan Gray","Olivia Young","Patrick Hayes","Quinn Hall","Riley Carter","Sophia Mitchell","Theo Sanchez","Ulysses Martinez","Vera Nelson","Willis Torres","Xena Foster","Yvonne King","Zoe Brooks","Aiden Bailey","Brenda Williams","Charlie Thomas","Danielle Roberts","Ethan Davis","Faith Lewis","Gabe Mitchell","Hannah Moore","Isaac Johnson","Jade Walker","Kara Evans","Liam Hill","Megan Lee","Nathan Hall","Olivia Carter","Paul Scott","Quinn Young","Rachel Brown","Samuel Gray","Tess Phillips","Ursula Ross","Vince Harris","Wesley Jones","Xander King","Yasmin Allen","Zara White","Adam Shaw","Beatrice Morris","Chris Harris","Diana Brooks","Elliot Clark","Fiona Hill","Gina White","Henry Cox","Ivy Stewart","Jackie Davis","Kevin Lewis")
@Composable fun TenKScrollIndicatorGallery(onBack:()->Unit) {
 val dark=isSystemInDarkTheme();val bg=if(dark)Color(0xFF1C1C1E)else Color.White;val fg=if(dark)Color.White else Color.Black
 val sections=remember {originalContactNames.groupBy {it.take(1)}.toSortedMap()};val state=rememberScrollState()
 var label by remember {mutableStateOf("A")};var viewportY by remember {mutableFloatStateOf(0f)};val density=androidx.compose.ui.platform.LocalDensity.current
 Column(Modifier.fillMaxSize().safeDrawingPadding().background(bg)) {
  Row(Modifier.padding(horizontal=20.dp),verticalAlignment=Alignment.CenterVertically){Text("Contacts",Modifier.weight(1f),fontSize=34.sp,fontWeight=FontWeight.Bold,color=fg);TextButton(onBack){Text("Retour")}}
  BoxWithConstraints(Modifier.weight(1f).onGloballyPositioned {viewportY=it.positionInRoot().y}) {
   val bottom=(maxHeight-250.dp).coerceAtLeast(0.dp)
   Column(Modifier.fillMaxSize().background(Color.Gray.copy(alpha=.15f)).verticalScroll(state).padding(20.dp).padding(bottom=bottom),verticalArrangement=Arrangement.spacedBy(12.dp)) {
    sections.forEach {(initial,contacts)->
     Column(Modifier.fillMaxWidth().onGloballyPositioned {val y=it.positionInRoot().y-viewportY;if(y>=0&&y<with(density){150.dp.toPx()})label=initial}.background(bg,RoundedCornerShape(10.dp)).padding(15.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
      Text(initial,fontSize=34.sp,fontWeight=FontWeight.Bold,color=fg)
      Column(verticalArrangement=Arrangement.spacedBy(15.dp)) {contacts.forEachIndexed {index,name->Text(name,Modifier.fillMaxWidth(),fontSize=17.sp,letterSpacing=0.sp,color=fg);if(index<contacts.lastIndex)HorizontalDivider(color=fg.copy(alpha=.15f))}}
     }
    }
   }
   TenKScrollIndicator(state,label,Modifier.align(Alignment.CenterEnd).height(maxHeight*.5f))
  }
 }
}
