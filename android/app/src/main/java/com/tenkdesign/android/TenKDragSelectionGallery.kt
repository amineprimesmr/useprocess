package com.tenkdesign.android
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.*
import androidx.compose.ui.unit.dp
@Composable fun TenKDragSelectionGallery(modifier:Modifier=Modifier,reduceMotion:Boolean=false) {
 var selected by remember {mutableStateOf(emptySet<String>())};var enabled by remember {mutableStateOf(false)};var message by remember {mutableStateOf<String?>(null)}
 val colors=listOf(0xFFFF3B30,0xFF007AFF,0xFF34C759,0xFFFFCC00,0xFFAF52DE,0xFF32ADE6,0xFFA2845E,0xFFFF9500,0xFFFF2D55).map {Color(it)}
 val items=remember {List(45){it}}
 TenKDragSelectionGrid(items,{it.toString()},selected,{selected=it},enabled,{enabled=it;if(!it)selected=emptySet()},{message="Preview: ${it.size} items selected for sharing."},{message="Preview: ${it.size} items selected. No deletion performed."},modifier,reduceMotion=reduceMotion) {item->
  val color=colors[item%colors.size];Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(color.copy(alpha=.8f),color)),RoundedCornerShape(18.dp)))
 }
 message?.let {text->AlertDialog(onDismissRequest={message=null},text={Text(text)},confirmButton={TextButton({message=null}){Text("Close")}})}
}
