package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.*

/** Local shopping preview; full plan-based grocery page remains a separate port. */
@Composable
fun FoodShoppingListPage(store:FoodShoppingList,onBack:()->Unit,english:Boolean=false) {
    val palette=FoodPalette(isSystemInDarkTheme())
    Column(Modifier.fillMaxSize().background(palette.background)) {
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
            IconButton(onClick=onBack) { Icon(Icons.Default.ArrowBack,foodText("Retour","Back",english),tint=palette.primary) }
            Text(foodText("Courses","Groceries",english),fontSize=17.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,modifier=Modifier.weight(1f))
            if(store.entries.any { it.checked }) TextButton(onClick=store::clearChecked) { Text(foodText("Retirer les cochés","Clear checked",english),color=palette.primary) }
        }
        LazyColumn(contentPadding=PaddingValues(20.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            if(store.entries.isEmpty()) item { Text(foodText("Ta liste de courses est vide.","Your grocery list is empty.",english),color=palette.secondary) }
            items(store.entries,key={it.id}) { entry ->
                val food=DebloatFoods.item(entry.foodId)
                if(food!=null) Row(Modifier.fillMaxWidth().foodSurface(palette,14).padding(8.dp),verticalAlignment=Alignment.CenterVertically) {
                    Checkbox(entry.checked,{store.toggle(entry.id)},colors=CheckboxDefaults.colors(checkedColor=palette.primary,checkmarkColor=palette.background))
                    Column(Modifier.weight(1f)) {
                        Text(FoodCopy.name(food,english),fontSize=15.sp,fontWeight=FontWeight.SemiBold,color=palette.primary,textDecoration=if(entry.checked) TextDecoration.LineThrough else TextDecoration.None)
                        Text(FoodCopy.portion(entry.quantity,english),fontSize=12.sp,color=palette.secondary)
                    }
                    IconButton(onClick={store.remove(entry.id)}) {Icon(Icons.Default.Delete,foodText("Supprimer ","Delete ",english)+FoodCopy.name(food,english),tint=palette.secondary)}
                }
            }
        }
    }
}
