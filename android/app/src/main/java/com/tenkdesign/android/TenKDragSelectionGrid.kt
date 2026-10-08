package com.tenkdesign.android

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*

@Composable fun <T> TenKDragSelectionGrid(
 items:List<T>,itemKey:(T)->String,selectedKeys:Set<String>,onSelectionChange:(Set<String>)->Unit,
 selectionEnabled:Boolean,onSelectionEnabledChange:(Boolean)->Unit,onShare:(Set<String>)->Unit,onDelete:(Set<String>)->Unit,
 modifier:Modifier=Modifier,contextKey:Any=Unit,reduceMotion:Boolean=false,title:String="Grid View",content:@Composable (T)->Unit
) {
 val keys=items.map(itemKey);require("__tenk_header" !in keys&&keys.distinct().size==keys.size){"Selection keys must be unique"}
 val grid=rememberLazyGridState();val density=LocalDensity.current
 val region=with(density){60.dp.toPx()};val speed=with(density){300.dp.toPx()}
 val currentSelected by rememberUpdatedState(selectedKeys);val changed by rememberUpdatedState(onSelectionChange)
 var drag by remember(contextKey,keys,selectionEnabled) {mutableStateOf<DragSelectionRange?>(null)}
 var pointer by remember {mutableStateOf<Offset?>(null)}
 fun updateSelection(position:Offset) {
  val item=grid.layoutInfo.visibleItemsInfo.firstOrNull {info->info.key!="__tenk_header"&&position.x>=info.offset.x&&position.x<=info.offset.x+info.size.width&&position.y>=info.offset.y&&position.y<=info.offset.y+info.size.height}
  val index=item?.key?.let {keys.indexOf(it)}?.takeIf {it>=0}?:return
  val range=drag?:DragSelectionRange(index,currentSelected.mapNotNull {keys.indexOf(it).takeIf {it>=0}}.toSet()).also {drag=it}
  val result=range.selectionAt(index).mapTo(linkedSetOf()) {keys[it]}
  if(result!=currentSelected)changed(result)
 }
 fun cancelDrag() {drag?.let {range->changed(range.baseline.mapTo(linkedSetOf()){keys[it]})};drag=null;pointer=null}
 val lifecycle=LocalLifecycleOwner.current.lifecycle
 DisposableEffect(lifecycle,contextKey,keys,selectionEnabled) {
  val observer=LifecycleEventObserver {_,event->if(event==Lifecycle.Event.ON_STOP)cancelDrag()}
  lifecycle.addObserver(observer);onDispose {lifecycle.removeObserver(observer)}
 }
 LaunchedEffect(contextKey,keys,selectionEnabled,drag!=null) {
  if(drag==null)return@LaunchedEffect
  var previous=withFrameNanos {it}
  while(isActive&&drag!=null) {
   val time=withFrameNanos {it};val elapsed=((time-previous)/1_000_000_000f).coerceIn(0f,.05f);previous=time
   val point=pointer?:continue
   val height=grid.layoutInfo.viewportEndOffset.toFloat()
   val direction=if(point.y<region)-1 else if(point.y>height-region)1 else 0
   if(direction!=0&&lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {grid.scrollBy(direction*speed*elapsed);updateSelection(point)}
  }
 }
 Column(modifier) {
  LazyVerticalGrid(columns=GridCells.Fixed(4),state=grid,contentPadding=PaddingValues(15.dp),horizontalArrangement=Arrangement.spacedBy(8.dp),verticalArrangement=Arrangement.spacedBy(8.dp),userScrollEnabled=!selectionEnabled,modifier=Modifier.weight(1f).fillMaxWidth().pointerInput(contextKey,keys,selectionEnabled) {
   if(selectionEnabled)detectDragGestures(onDragStart={pointer=it;updateSelection(it)},onDrag={change,_->change.consume();pointer=change.position;updateSelection(change.position)},onDragEnd={drag=null;pointer=null},onDragCancel={cancelDrag()})
  }) {
   item(key="__tenk_header",span={GridItemSpan(4)}) {
    Row(Modifier.padding(bottom=12.dp).fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
     Text(title,Modifier.weight(1f),fontSize=28.sp,fontWeight=FontWeight.Bold)
     Text(if(selectionEnabled)"Cancel" else "Select",fontSize=13.sp,fontWeight=FontWeight.SemiBold,color=MaterialTheme.colorScheme.onSurface,modifier=Modifier.background(MaterialTheme.colorScheme.onSurface.copy(alpha=.1f),androidx.compose.foundation.shape.CircleShape).clickable(role=Role.Button){onSelectionEnabledChange(!selectionEnabled)}.padding(horizontal=12.dp,vertical=4.dp))
    }
   }
   items(items,key=itemKey) {item->
    val id=itemKey(item);val selected=id in selectedKeys
    Box(Modifier.height(80.dp).then(if(selectionEnabled)Modifier.toggleable(selected,role=Role.Checkbox){checked->changed(if(checked)currentSelected+id else currentSelected-id)}else Modifier).semantics {contentDescription="Grid item $id"}) {
     content(item)
     androidx.compose.animation.AnimatedVisibility(selected,enter=fadeIn(tween(if(reduceMotion)0 else 250))+scaleIn(tween(if(reduceMotion)0 else 250)),exit=fadeOut(tween(if(reduceMotion)0 else 250))) {
      Surface(color=androidx.compose.ui.graphics.Color.White,shape=androidx.compose.foundation.shape.CircleShape,modifier=Modifier.padding(5.dp).size(20.dp)) {Icon(Icons.Default.Check,null,tint=androidx.compose.ui.graphics.Color.Black,modifier=Modifier.padding(2.dp))}
     }
    }
   }
  }
  AnimatedVisibility(selectionEnabled,enter=slideInVertically(tween(if(reduceMotion)0 else 250)){it},exit=slideOutVertically(tween(if(reduceMotion)0 else 250)){-it}) {
   Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.onSurface.copy(alpha=.06f)).padding(horizontal=15.dp,vertical=10.dp),horizontalArrangement=Arrangement.SpaceBetween) {
    IconButton({onShare(selectedKeys.intersect(keys.toSet()))},modifier=Modifier.size(24.dp),enabled=selectedKeys.any {it in keys}) {Icon(Icons.Default.Share,"Share selection")}
    IconButton({onDelete(selectedKeys.intersect(keys.toSet()))},modifier=Modifier.size(24.dp),enabled=selectedKeys.any {it in keys}) {Icon(Icons.Default.Delete,"Delete selection",tint=MaterialTheme.colorScheme.error)}
   }
  }
 }
}
