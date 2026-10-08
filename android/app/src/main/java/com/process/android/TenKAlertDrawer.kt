package com.process.android
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import kotlin.math.roundToInt

@Stable class AlertDrawerState internal constructor() {
 var isPresented by mutableStateOf(false);private set
 internal var overlayVisible by mutableStateOf(false)
 internal var sourceRect by mutableStateOf(Rect.Zero)
 internal var hostOrigin by mutableStateOf(Offset.Zero)
 fun present(){if(sourceRect.width>0f&&sourceRect.height>0f){overlayVisible=true;isPresented=true}}
 fun dismiss(){isPresented=false}
}
@Composable fun rememberAlertDrawerState(contextKey:Any)=remember(contextKey){AlertDrawerState()}
@Composable fun TenKDrawerSourceButton(title:String,state:AlertDrawerState,modifier:Modifier=Modifier,tint:Color=Color(0xFFFF3B30),foreground:Color=Color.White) {
 DrawerButton(title,{state.present()},modifier.onGloballyPositioned {state.sourceRect=it.boundsInRoot()}.alpha(if(state.overlayVisible)0f else 1f).then(if(state.overlayVisible)Modifier.clearAndSetSemantics {}else Modifier),tint,foreground,!state.overlayVisible)
}
@Composable private fun DrawerButton(title:String,onClick:()->Unit,modifier:Modifier,tint:Color,foreground:Color,enabled:Boolean=true) {
 val interaction=remember {MutableInteractionSource()};val pressed by interaction.collectIsPressedAsState()
 val scale by animateFloatAsState(if(pressed).95f else 1f,tween(100,easing=LinearEasing),label="drawer press")
 Box(modifier.scale(scale).background(tint,RoundedCornerShape(50)).clickable(interactionSource=interaction,indication=null,enabled=enabled,role=Role.Button,onClick=onClick).padding(vertical=12.dp),contentAlignment=Alignment.Center) {
  Text(title,fontSize=17.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=foreground)
 }
}
/** Mount at a bounded root viewport; source button and overlay share this state and coordinates. */
@Composable fun TenKAlertDrawer(
 state:AlertDrawerState,primaryTitle:String,secondaryTitle:String,onPrimary:()->Boolean,onSecondary:()->Boolean,
 modifier:Modifier=Modifier,tint:Color=Color(0xFFFF3B30),foreground:Color=Color.White,
 reduceMotion:Boolean=rememberProcessReducedMotion(),drawerContent:@Composable ()->Unit,content:@Composable ()->Unit,
) {
 val progress=remember(state){Animatable(0f)}
 LaunchedEffect(state.isPresented,state,reduceMotion) {
  progress.animateTo(if(state.isPresented)1f else 0f,if(reduceMotion)snap()else tween(350,easing=FastOutSlowInEasing))
  if(!state.isPresented)state.overlayVisible=false
 }
 BackHandler(state.overlayVisible){state.dismiss()}
 val dark=isSystemInDarkTheme();val surface=if(dark)Color(0xFF1C1C1E)else Color.White;val text=if(dark)Color.White else Color.Black
 Box(modifier.fillMaxSize().onGloballyPositioned {state.hostOrigin=it.positionInRoot()}) {
  Box(Modifier.fillMaxSize().then(if(state.overlayVisible)Modifier.clearAndSetSemantics {}else Modifier)){content()}
  if(state.overlayVisible) {
   val amount=progress.value;val enabled=state.isPresented&&!progress.isRunning
   Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.5f*amount)).clickable(interactionSource=remember{MutableInteractionSource()},indication=null){state.dismiss()}.semantics {contentDescription="Dismiss confirmation"})
   SubcomposeLayout(Modifier.fillMaxSize().semantics {paneTitle="Confirmation"}) {constraints->
    val inset=20.dp.roundToPx();val bottom=10.dp.roundToPx();val gap=10.dp.roundToPx();val bodyGap=25.dp.roundToPx();val bottomInside=15.dp.roundToPx()
    val cardWidth=(constraints.maxWidth-inset*2).coerceAtLeast(1);val inside=(cardWidth-inset*2).coerceAtLeast(1);val half=((inside-gap)/2).coerceAtLeast(1)
    val source=state.sourceRect.translate(-state.hostOrigin)
    val buttonHeight=source.height.roundToInt().coerceAtLeast(44.dp.roundToPx())
    val body=subcompose("body") {
     Box(Modifier.alpha(amount).then(if(!enabled)Modifier.clearAndSetSemantics {}else Modifier)) {
      Box(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(end=28.dp)){drawerContent()}
      IconButton({state.dismiss()},Modifier.align(Alignment.TopEnd).size(24.dp).background(text.copy(alpha=.08f),RoundedCornerShape(50)),enabled=enabled) {Icon(Icons.Default.Close,"Close confirmation",Modifier.size(15.dp),tint=text)}
     }
    }.single().measure(androidx.compose.ui.unit.Constraints(maxWidth=inside,maxHeight=(constraints.maxHeight-bottom-inset-bodyGap-buttonHeight-bottomInside).coerceAtLeast(1)))
    val targetHeight=inset+body.height+bodyGap+buttonHeight+bottomInside
    val targetY=constraints.maxHeight-bottom-targetHeight;val actionY=targetY+inset+body.height+bodyGap
    fun interpolate(a:Float,b:Float)=a+(b-a)*amount
    val left=interpolate(source.left,inset.toFloat());val top=interpolate(source.top,targetY.toFloat())
    val width=interpolate(source.width,cardWidth.toFloat()).coerceAtLeast(1f);val height=interpolate(source.height,targetHeight.toFloat()).coerceAtLeast(1f)
    val backdrop=subcompose("backdrop") {Box(Modifier.pointerInput(Unit){detectTapGestures {}}.shadow(if(amount>0f)5.dp else 0.dp,RoundedCornerShape((buttonHeight/2f).toDp())).background(surface,RoundedCornerShape((buttonHeight/2f).toDp())))}.single().measure(androidx.compose.ui.unit.Constraints.fixed(width.roundToInt(),height.roundToInt()))
    val secondary=subcompose("secondary") {DrawerButton(secondaryTitle,{if(onSecondary())state.dismiss()},Modifier.fillMaxSize().alpha(amount).then(if(!enabled)Modifier.clearAndSetSemantics {}else Modifier),text.copy(alpha=.07f),text,enabled)}.single().measure(androidx.compose.ui.unit.Constraints.fixed(half,buttonHeight))
    val primaryWidth=interpolate(source.width,half.toFloat()).roundToInt().coerceAtLeast(1)
    val primary=subcompose("primary") {DrawerButton(primaryTitle,{if(onPrimary())state.dismiss()},Modifier.fillMaxSize(),tint,foreground,enabled)}.single().measure(androidx.compose.ui.unit.Constraints.fixed(primaryWidth,buttonHeight))
    layout(constraints.maxWidth,constraints.maxHeight) {
     backdrop.place(left.roundToInt(),top.roundToInt())
     body.place(inset*2,targetY+inset)
     secondary.place(inset*2,actionY)
     primary.place(interpolate(source.left,(inset*2+half+gap).toFloat()).roundToInt(),interpolate(source.top,actionY.toFloat()).roundToInt())
    }
   }
  }
 }
}
