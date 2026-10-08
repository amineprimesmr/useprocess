package com.process.android
import androidx.compose.ui.graphics.Color
internal data class ProcessSurfacePalette(val dark:Boolean) {
 val background=if(dark)Color(.07f,.08f,.11f)else Color(.968f,.972f,.988f)
 val primary=if(dark)Color.White else Color.Black
 val secondary=if(dark)Color(235/255f,235/255f,245/255f,.6f)else Color(60/255f,60/255f,67/255f,.6f)
 val accent=Color(.655f,.769f,.949f)
 val card=primary.copy(alpha=if(dark).08f else .05f)
 val strongCard=primary.copy(alpha=if(dark).12f else .07f)
 val recipeCard=if(dark)strongCard else Color(.84f,.90f,.99f)
 val stroke=if(dark)Color(84/255f,84/255f,88/255f,.3f)else Color(60/255f,60/255f,67/255f,.1015f)
}
