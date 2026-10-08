package com.tenkdesign.android

// Android adaptation of VerticalSC, original source by Balaji Venkatesh, 22/09/26.
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** Host-controlled vertical picker. Pass real map/content updates via onSelectionChange. */
@Composable fun <T> TenKVerticalSegmentedControl(
    items:List<T>,selected:T,onSelectionChange:(T)->Unit,label:(T)->String,
    modifier:Modifier=Modifier,tint:Color=if(isSystemInDarkTheme())Color.Black.copy(alpha=.35f)else Color.Gray.copy(alpha=.35f),
    reduceMotion:Boolean=false,icon:@Composable (T)->Unit,
) {
    require(items.isNotEmpty() && items.distinct().size==items.size) {"Vertical items must be non-empty and unique"}
    val density=LocalDensity.current.density
    val latestChange by rememberUpdatedState(onSelectionChange)
    var pressedIndex by remember {mutableStateOf<Int?>(null)}
    val index=items.indexOf(selected).coerceAtLeast(0)
    val highlight by animateFloatAsState((pressedIndex?:index).toFloat(),if(reduceMotion)snap()else spring(.85f,650f),label="vertical.selection")
    val dark=isSystemInDarkTheme()
    val shape=RoundedCornerShape(50)
    Box(modifier.padding(start=1.dp).width(50.dp).height((items.size*60).dp).clip(shape)
        .background(Brush.linearGradient(if(dark)listOf(Color(.16f,.16f,.17f,.84f),Color(.07f,.07f,.08f,.78f))else listOf(Color.White.copy(alpha=.82f),Color(.9f,.9f,.92f,.72f))))
        .border(.5.dp,Color.White.copy(alpha=if(dark).20f else .55f),shape).selectableGroup()
        .pointerInput(items,density) {
            awaitEachGesture {
                val down=awaitFirstDown(requireUnconsumed=false)
                fun row(y:Float)=(y/(60*density)).toInt().coerceIn(items.indices)
                pressedIndex=row(down.position.y)
                try {
                    while(true) {
                        val change=awaitPointerEvent().changes.firstOrNull {it.id==down.id}?:break
                        if(change.isConsumed)break
                        if(!change.pressed) {
                            if(change.position.x in 0f..size.width.toFloat() && change.position.y in 0f..size.height.toFloat())latestChange(items[row(change.position.y)])
                            change.consume();break
                        }
                        pressedIndex=row(change.position.y)
                        if(change.position!=down.position)change.consume()
                    }
                } finally {pressedIndex=null}
            }
        }) {
        Box(Modifier.fillMaxWidth().height(60.dp).graphicsLayer {translationY=highlight*60*density}.padding(3.dp).background(tint,RoundedCornerShape(50)))
        Column {
            items.forEach {item ->
                Box(Modifier.width(50.dp).height(60.dp).selectable(selected=item==items[index],role=Role.RadioButton,onClick={latestChange(item)}).semantics {contentDescription=label(item)},contentAlignment=Alignment.Center) {
                    Box(Modifier.size(18.dp),contentAlignment=Alignment.Center) {icon(item)}
                }
            }
        }
    }
}
