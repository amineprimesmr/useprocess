package com.process.android
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable internal fun ProcessSettingsPage(title:String,onBack:()->Unit,modifier:Modifier=Modifier,english:Boolean=false,content:@Composable ColumnScope.()->Unit) {
    val dark=isSystemInDarkTheme();val ink=if(dark)Color.White else Color.Black
    Column(modifier.fillMaxSize().background(if(dark)Color.Black else Color(0xfff2f2f7))) {
        Box(Modifier.fillMaxWidth().heightIn(min=56.dp).padding(horizontal=16.dp,vertical=8.dp),contentAlignment=Alignment.Center) {
            Text(title,fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=ink,maxLines=1,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis,modifier=Modifier.padding(horizontal=48.dp))
            IconButton(onClick=onBack,modifier=Modifier.align(Alignment.CenterStart).size(40.dp).background(ink.copy(alpha=.06f),RoundedCornerShape(50))) {Icon(Icons.AutoMirrored.Filled.ArrowBack,if(english)"Back"else"Retour",Modifier.size(18.dp),tint=ink)}
        }
        Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(bottom=74.dp + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),content=content)
    }
}
@Composable internal fun ProcessSettingsSection(title:String) {
    Text(title,fontSize=16.5.sp,fontWeight=FontWeight.Bold,color=(if(isSystemInDarkTheme())Color.White else Color.Black).copy(alpha=.92f),modifier=Modifier.fillMaxWidth().padding(horizontal=20.dp).padding(top=18.dp,bottom=10.dp))
}
@Composable internal fun ProcessSettingsCard(content:@Composable ColumnScope.()->Unit) {
    val dark=isSystemInDarkTheme();val ink=if(dark)Color.White else Color.Black;val shape=RoundedCornerShape(28.dp)
    Column(Modifier.padding(horizontal=16.dp).fillMaxWidth().clip(shape).background(if(dark)Color.White.copy(alpha=.062f)else Color.White).border(.5.dp,ink.copy(alpha=.096f),shape),content=content)
}
@Composable internal fun ProcessSettingsDivider() {
    HorizontalDivider(Modifier.padding(start=54.dp),thickness=androidx.compose.ui.platform.LocalDensity.current.run {1f.toDp()},color=(if(isSystemInDarkTheme())Color.White else Color.Black).copy(alpha=if(isSystemInDarkTheme()).10f else .28f))
}
@Composable internal fun ProcessSettingsRow(icon:ImageVector,title:String,status:String?=null,external:Boolean=false,onClick:(()->Unit)?=null) {
    val ink=if(isSystemInDarkTheme())Color.White else Color.Black
    Row(Modifier.fillMaxWidth().then(if(onClick!=null)Modifier.clickable(role=Role.Button,onClick=onClick)else Modifier).padding(horizontal=16.dp,vertical=9.dp).heightIn(min=46.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
        Icon(icon,null,Modifier.width(26.dp).size(19.dp),tint=ink.copy(alpha=.82f))
        Text(title,fontSize=16.sp,color=ink,modifier=Modifier.weight(1f))
        if(status!=null)Text(status,fontSize=17.sp,color=ink.copy(alpha=.48f))
        else if(external)Text("↗",fontSize=18.sp,fontWeight=FontWeight.SemiBold,color=ink.copy(alpha=.32f))
        else if(onClick!=null)Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight,null,Modifier.size(18.dp),tint=ink.copy(alpha=.32f))
    }
}
