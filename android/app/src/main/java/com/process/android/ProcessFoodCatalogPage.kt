package com.process.android

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*

/** Native food catalog port. The host owns identity and grocery persistence. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProcessFoodCatalogPage(
    preferences:FoodPreferenceStore,
    onAddGroceries:(DebloatFood)->Unit,
    onBack:()->Unit,
    modifier:Modifier=Modifier,
    english:Boolean=false,
    dark:Boolean=isSystemInDarkTheme()
) {
    val palette=remember(dark) { FoodPalette(dark) }
    var tabName by rememberSaveable { mutableStateOf(FoodCatalogTab.Prefer.name) }
    val tab=FoodCatalogTab.valueOf(tabName)
    var query by rememberSaveable { mutableStateOf("") }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val state=preferences.state
    val prefer=remember(query,english) { FoodCatalogModel.sections(setOf(FoodTier.hero,FoodTier.prefer),query,english) }
    val avoid=remember(query,english) { FoodCatalogModel.sections(setOf(FoodTier.avoid),query,english) }
    val moderate=remember(query,english) { FoodCatalogModel.sections(setOf(FoodTier.moderate),query,english) }
    Column(modifier.fillMaxSize().background(palette.background)) {
        Box(Modifier.fillMaxWidth().height(44.dp)) {
            IconButton(onClick=onBack,modifier=Modifier.align(Alignment.CenterStart)) {
                Icon(Icons.Default.ArrowBack,foodText("Retour","Back",english),tint=palette.primary)
            }
            Text(foodText("Aliments","Foods",english),fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,modifier=Modifier.align(Alignment.Center))
        }
        LazyColumn(contentPadding=PaddingValues(start=20.dp,end=20.dp,top=12.dp,bottom=40.dp),modifier=Modifier.weight(1f)) {
            item("tabs") {
                Row(Modifier.fillMaxWidth().selectableGroup(),horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                    FoodCatalogTab.entries.forEach { item ->
                        val active=tab==item
                        val background by animateColorAsState(if(active) palette.primary else Color.Transparent,spring(.86f,322.27f),label="food.tab.background")
                        val title=when(item) {
                            FoodCatalogTab.Prefer->foodText("Privilégier","Prefer",english)
                            FoodCatalogTab.Avoid->foodText("Éviter","Avoid",english)
                            FoodCatalogTab.Tastes->foodText("Mes goûts","My tastes",english)
                        }
                        Row(Modifier.weight(1f).clip(RoundedCornerShape(50)).background(background)
                            .border(.5.dp,if(active) Color.Transparent else palette.primary.copy(alpha=if(dark).12f else .08f),RoundedCornerShape(50))
                            .selectable(selected=active,role=Role.Tab,onClick={tabName=item.name}).padding(vertical=9.dp,horizontal=6.dp),
                            horizontalArrangement=Arrangement.spacedBy(6.dp,Alignment.CenterHorizontally),verticalAlignment=Alignment.CenterVertically) {
                            val tint=if(active) { if(dark) Color.Black else Color.White } else palette.secondary
                            Icon(when(item) { FoodCatalogTab.Prefer->Icons.Default.ThumbUp; FoodCatalogTab.Avoid->Icons.Default.Warning; FoodCatalogTab.Tastes->Icons.Default.Favorite },null,Modifier.size(12.dp),tint=tint)
                            Text(title,fontSize=13.sp,fontWeight=FontWeight.Bold,color=tint,maxLines=1,overflow=TextOverflow.Ellipsis)
                        }
                    }
                }
                Spacer(Modifier.height(20.dp))
            }
            if(tab!=FoodCatalogTab.Tastes) {
                item("search") {
                    Row(Modifier.fillMaxWidth().foodSurface(palette,50).padding(horizontal=16.dp,vertical=13.dp),horizontalArrangement=Arrangement.spacedBy(10.dp),verticalAlignment=Alignment.CenterVertically) {
                        Icon(Icons.Default.Search,null,Modifier.size(19.dp),tint=palette.secondary)
                        BasicTextField(query,{query=it},modifier=Modifier.weight(1f).semantics { contentDescription=foodText("Rechercher un aliment","Search foods",english) },
                            singleLine=true,textStyle=TextStyle(fontSize=17.sp,color=palette.primary),cursorBrush=SolidColor(palette.primary),
                            keyboardOptions=KeyboardOptions(capitalization=KeyboardCapitalization.None,autoCorrectEnabled=false),
                            decorationBox={ input ->
                                Box {
                                    if(query.isEmpty()) Text(foodText("Rechercher un aliment…","Search a food…",english),fontSize=17.sp,color=palette.secondary,maxLines=1)
                                    input()
                                }
                            })
                        if(query.isNotEmpty()) Icon(Icons.Default.Close,foodText("Effacer la recherche","Clear search",english),Modifier.size(20.dp).clickable {query=""},tint=palette.secondary)
                    }
                    Spacer(Modifier.height(20.dp))
                }
            }
            when(tab) {
                FoodCatalogTab.Prefer -> {
                    if(prefer.isEmpty()) item("empty") { EmptyFoodSearch(palette,english) }
                    foodSections(prefer,"prefer",state,preferences::toggleLike,{selectedId=it.id},palette,english)
                }
                FoodCatalogTab.Avoid -> {
                    if(avoid.isEmpty() && moderate.isEmpty()) item("empty") { EmptyFoodSearch(palette,english) }
                    if(avoid.isNotEmpty()) item("avoid-intro") {
                        FoodTierIntro(foodText("À éviter","Avoid",english),foodText("Sodium, rétention et inflammation — impact direct sur le visage.","Sodium, retention, and inflammation — direct face impact.",english),FoodTier.avoid,palette)
                    }
                    foodSections(avoid,"avoid",state,preferences::toggleLike,{selectedId=it.id},palette,english)
                    if(moderate.isNotEmpty()) item("moderate-intro") {
                        FoodTierIntro(foodText("Avec modération","In moderation",english),foodText("OK parfois — pas en base quotidienne si tu vises un visage net.","OK sometimes — not as a daily base if you want a sharper face.",english),FoodTier.moderate,palette)
                    }
                    foodSections(moderate,"moderate",state,preferences::toggleLike,{selectedId=it.id},palette,english)
                }
                FoodCatalogTab.Tastes -> {
                    if(state.likedFoods.isEmpty()) item("empty-likes") {
                        FoodNotice(foodText("Aucun like pour l’instant","No likes yet",english),foodText("Like des aliments dans Privilégier pour générer courses et recettes visage dégonflé.","Like foods in Prefer to generate groceries and debloat face recipes.",english),palette)
                        Spacer(Modifier.height(18.dp))
                    } else {
                        item("likes-title") { FoodSectionTitle(foodText("Tes likes","Your likes",english),palette) }
                        items(state.likedFoods,key={"liked-${it.id}"}) { food -> FoodRow(food,food.id in state.likedIDs,{preferences.toggleLike(food.id)},{selectedId=food.id},palette,english);Spacer(Modifier.height(10.dp)) }
                    }
                    if(state.homeFoods.isNotEmpty()) {
                        item("home-title") { Spacer(Modifier.height(8.dp));FoodSectionTitle(foodText("Déjà chez toi","Already at home",english),palette) }
                        items(state.homeFoods,key={"home-${it.id}"}) { food -> FoodRow(food,food.id in state.likedIDs,{preferences.toggleLike(food.id)},{selectedId=food.id},palette,english);Spacer(Modifier.height(10.dp)) }
                    }
                }
            }
        }
    }
    selectedId?.let(DebloatFoods::item)?.let { food ->
        ModalBottomSheet(onDismissRequest={selectedId=null},sheetState=rememberModalBottomSheetState(),containerColor=palette.background,contentColor=palette.primary) {
            FoodDetail(food,state,preferences::toggleLike,preferences::toggleAtHome,{toAdd->onAddGroceries(toAdd);selectedId=null},{selectedId=null},palette,english)
        }
    }
}

internal fun Modifier.foodSurface(palette:FoodPalette,radius:Int)=clip(RoundedCornerShape(radius.dp)).background(palette.surface).border(.75.dp,palette.stroke,RoundedCornerShape(radius.dp))

private fun LazyListScope.foodSections(sections:List<FoodSection>,prefix:String,state:FoodPreferenceState,onLike:(String)->Unit,onSelect:(DebloatFood)->Unit,palette:FoodPalette,english:Boolean) {
    sections.forEach { section ->
        item("$prefix-${section.category}-title") { FoodSectionTitle(section.category.title(english),palette) }
        items(section.foods,key={"$prefix-${it.id}"}) { food ->
            FoodRow(food,food.id in state.likedIDs,{onLike(food.id)},{onSelect(food)},palette,english)
            Spacer(Modifier.height(8.dp))
        }
        item("$prefix-${section.category}-space") { Spacer(Modifier.height(14.dp)) }
    }
}
@Composable private fun FoodSectionTitle(title:String,palette:FoodPalette) {
    Text(title,fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,modifier=Modifier.padding(bottom=10.dp))
}
@Composable private fun FoodRow(food:DebloatFood,liked:Boolean,onLike:()->Unit,onSelect:()->Unit,palette:FoodPalette,english:Boolean) {
    Row(Modifier.fillMaxWidth().foodSurface(palette,14).clickable(onClick=onSelect).padding(12.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
        Box(Modifier.width(4.dp).height(44.dp).background(food.tier.tint,RoundedCornerShape(3.dp)))
        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically) {
                Text(FoodCopy.name(food,english),fontSize=15.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,maxLines=1,overflow=TextOverflow.Ellipsis,modifier=Modifier.weight(1f,fill=false))
                Text(food.tier.badge(english),fontSize=11.sp,fontWeight=FontWeight.Bold,color=food.tier.tint,modifier=Modifier.background(food.tier.tint.copy(alpha=.14f),RoundedCornerShape(50)).padding(horizontal=7.dp,vertical=3.dp),maxLines=1)
            }
            Text(FoodCopy.why(food,english),fontSize=12.sp,color=palette.secondary,maxLines=2,overflow=TextOverflow.Ellipsis,lineHeight=16.sp)
        }
        Text(food.score.toString(),fontSize=18.sp,fontWeight=FontWeight.Bold,color=palette.primary)
        IconToggleButton(checked=liked,onCheckedChange={onLike()},modifier=Modifier.size(28.dp)) {
            Icon(if(liked) Icons.Default.Favorite else Icons.Outlined.FavoriteBorder,foodText("Aimer ","Like ",english)+FoodCopy.name(food,english),Modifier.size(20.dp),tint=if(liked) Color(1f,.18f,.33f) else palette.secondary)
        }
    }
}
@Composable private fun FoodTierIntro(title:String,subtitle:String,tier:FoodTier,palette:FoodPalette) {
    Column(Modifier.padding(top=4.dp,bottom=22.dp),verticalArrangement=Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically) {
            Text(title,fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
            Text(DebloatFoods.all.count { it.tier==tier }.toString(),fontSize=12.sp,fontWeight=FontWeight.Bold,color=tier.tint,modifier=Modifier.background(tier.tint.copy(alpha=.14f),RoundedCornerShape(50)).padding(horizontal=8.dp,vertical=3.dp))
        }
        Text(subtitle,fontSize=15.sp,color=palette.secondary)
    }
}
@Composable private fun EmptyFoodSearch(palette:FoodPalette,english:Boolean)=FoodNotice(foodText("Aucun résultat","No results",english),foodText("Essaie un autre mot — ex. concombre, saumon, charcuterie.","Try another word — e.g. cucumber, salmon, deli meat.",english),palette)
@Composable private fun FoodNotice(title:String,body:String,palette:FoodPalette) {
    Column(Modifier.fillMaxWidth().foodSurface(palette,16).padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
        Text(title,fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary)
        Text(body,fontSize=15.sp,color=palette.secondary)
    }
}
@Composable private fun FoodDetail(food:DebloatFood,state:FoodPreferenceState,onLike:(String)->Unit,onHome:(String)->Unit,onAdd:(DebloatFood)->Unit,onDismiss:()->Unit,palette:FoodPalette,english:Boolean) {
    val swaps=remember(food) { FoodCatalogModel.swaps(food) }
    LazyColumn(contentPadding=PaddingValues(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp),modifier=Modifier.fillMaxWidth()) {
        item("title") {
            Row(verticalAlignment=Alignment.CenterVertically) {
                Text(FoodCopy.name(food,english),fontSize=17.sp,fontWeight=FontWeight.SemiBold,modifier=Modifier.weight(1f))
                IconButton(onClick=onDismiss) {Icon(Icons.Default.Close,foodText("Fermer","Close",english))}
            }
        }
        item("score") {
            Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.SpaceBetween) {
                Text(food.tier.badge(english),fontSize=12.sp,fontWeight=FontWeight.Bold,modifier=Modifier.background(palette.primary.copy(alpha=.08f),RoundedCornerShape(50)).padding(horizontal=10.dp,vertical=5.dp))
                Text("Score ≈${food.score}",fontSize=22.sp,fontWeight=FontWeight.Bold)
            }
        }
        item("why") { Text(FoodCopy.why(food,english),fontSize=17.sp) }
        item("metrics") {
            Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                listOf("K" to food.potassium,"Na" to food.sodium,"Mg" to food.magnesium).forEach { (label,value) ->
                    Column(Modifier.weight(1f).foodSurface(palette,12).padding(vertical=10.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(4.dp)) {
                        Text(label,fontSize=12.sp,fontWeight=FontWeight.Bold,color=palette.secondary)
                        Text(value?.let { "≈${it.toInt()} mg" } ?: "—",fontSize=15.sp,fontWeight=FontWeight.SemiBold)
                    }
                }
            }
        }
        food.portion?.let { portion -> item("portion") { Text(FoodCopy.portion(portion,english),fontSize=15.sp,color=palette.secondary) } }
        if(food.exceedsSaltLabelThreshold) item("salt-warning") { Text(foodText("Seuil dépassé : > 1,5 g de sel / 100 g — à éviter pour le visage.","Over threshold: > 1.5 g salt / 100 g — avoid for your face.",english),fontSize=13.sp,fontWeight=FontWeight.SemiBold,color=FoodTier.moderate.tint) }
        if(swaps.isNotEmpty()) item("swaps") {
            Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                Text(foodText("Alternatives visage","Face-friendly swaps",english),fontSize=17.sp,fontWeight=FontWeight.SemiBold)
                swaps.forEach { Text("→ ${FoodCopy.name(it,english)}",fontSize=15.sp,color=palette.secondary) }
            }
        }
        item("preferences") {
            Row(horizontalArrangement=Arrangement.spacedBy(10.dp)) {
                FoodAction(if(food.id in state.likedIDs) "Liked" else "Like",{onLike(food.id)},palette,checked=food.id in state.likedIDs)
                FoodAction(if(food.id in state.haveAtHomeIDs) foodText("Chez moi","At home",english) else foodText("J’ai chez moi","I have this",english),{onHome(food.id)},palette,checked=food.id in state.haveAtHomeIDs)
            }
        }
        val target=if(food.tier!=FoodTier.avoid) food else swaps.firstOrNull()
        if(target!=null) item("add") {
            val label=if(target.id==food.id) foodText("Ajouter aux courses","Add to groceries",english) else foodText("Remplacer par ","Replace with ",english)+FoodCopy.name(target,english)
            FoodAction(label,{onAdd(target)},palette,inverted=true)
        }
        item("disclaimer") { Text(foodText("Valeurs approximatives pour 100 g. Ce n’est pas un avis médical.","Approximate values per 100 g. This is not medical advice.",english),fontSize=11.sp,color=palette.secondary) }
    }
}
@Composable private fun FoodAction(title:String,onClick:()->Unit,palette:FoodPalette,inverted:Boolean=false,checked:Boolean?=null) {
    val shape=RoundedCornerShape(if(inverted)50.dp else 12.dp)
    val action=if(checked==null) Modifier.clickable(role=Role.Button,onClick=onClick) else Modifier.toggleable(value=checked,role=Role.Checkbox,onValueChange={onClick()})
    val modifier=Modifier.clip(shape).background(if(inverted) palette.primary else palette.surface).then(action).padding(horizontal=16.dp,vertical=12.dp)
    Text(title,fontSize=15.sp,fontWeight=FontWeight.SemiBold,color=if(inverted) palette.background else palette.primary,modifier=modifier)
}

/** Reuses the catalog detail with the same account-scoped preference store. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ProcessFoodDetailSheet(food:DebloatFood,preferences:FoodPreferenceStore,onAddGroceries:(DebloatFood)->Unit,onDismiss:()->Unit,english:Boolean=false,dark:Boolean=isSystemInDarkTheme()) {
 val palette=FoodPalette(dark)
 ModalBottomSheet(onDismissRequest=onDismiss,sheetState=rememberModalBottomSheetState(),containerColor=palette.background,contentColor=palette.primary) {
  FoodDetail(food,preferences.state,preferences::toggleLike,preferences::toggleAtHome,{onAddGroceries(it);onDismiss()},onDismiss,palette,english)
 }
}
