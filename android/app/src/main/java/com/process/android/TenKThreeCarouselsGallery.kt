package com.process.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*

val originalBackdropImages=listOf(
 BackdropCarouselImage("1",R.drawable.backdrop_1,"Photo by Mo Eid"),BackdropCarouselImage("2",R.drawable.backdrop_2,"Photo by Codioful"),
 BackdropCarouselImage("3",R.drawable.backdrop_3,"Photo by Cottonbro"),BackdropCarouselImage("4",R.drawable.backdrop_4,"Photo by Anni"))
val originalWallpapers=listOf(CarouselWallpaper("1","iOS 26",R.drawable.wallpaper_1),CarouselWallpaper("3","iOS 16",R.drawable.wallpaper_3),CarouselWallpaper("2","The Lake",R.drawable.wallpaper_2),CarouselWallpaper("4","iOS 18",R.drawable.wallpaper_4))
val originalScrollImages=listOf(
 ScrollInteractionImage("1",R.drawable.scrollfx_1,"Photo by Oleksandr P"),ScrollInteractionImage("2",R.drawable.scrollfx_2,"Photo by SenuScape"),
 ScrollInteractionImage("3",R.drawable.scrollfx_3,"Photo by Min An"),ScrollInteractionImage("4",R.drawable.scrollfx_4,"Photo by Artem Saranin"),
 ScrollInteractionImage("5",R.drawable.scrollfx_5,"Photo by Felix Mittermeier"),ScrollInteractionImage("6",R.drawable.scrollfx_6,"Photo by eberhard grossgasteiger"))
@Composable fun TenKThreeCarouselsGallery(kind:String,onBack:()->Unit,reduceMotion:Boolean=false) {
 var action by remember(kind){mutableStateOf<String?>(null)}
 Column(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding()) {
  TextButton(onBack){Text("Retour")}
  when(kind) {
   "backdropCarousel"->TenKBackdropCarousel(originalBackdropImages,Modifier.fillMaxSize()) {
    Row(Modifier.fillMaxSize(),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(15.dp)) {
     Text("ⓧ",fontSize=35.sp,color=Color.Black)
     Column {Text("iJustine",color=Color.Black,fontWeight=FontWeight.SemiBold);Text("Ⓖ 36,990",color=Color.Black,fontSize=12.sp)}
     Spacer(Modifier.weight(1f));Text("↑  ♧",fontSize=28.sp,color=Color.White)
    }
   }
   "wallpaperCarousel"->TenKWallpaperCarousel(originalWallpapers,Modifier.fillMaxSize(),reduceMotion=reduceMotion,onCustomize={action="Customize — ${it.title}"},onSecondary={action="Add"})
   else->Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){TenKScrollInteraction(originalScrollImages,Modifier.fillMaxWidth(),reduceMotion=reduceMotion)}
  }
 }
 action?.let{AlertDialog(onDismissRequest={action=null},title={Text(it)},text={Text("Action de démonstration de la source. Aucun fond d’écran installé.")},confirmButton={TextButton({action=null}){Text("OK")}})}
}
