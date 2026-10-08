package com.process.android

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.compose.ui.platform.LocalDensity

/** KG remains canonical during unit toggles; the host owns persistence and navigation. */
@Composable fun ProcessWeightInput(
    valueKg: Double,
    onValueChange: (Double)->Unit,
    onContinue: ()->Unit,
    modifier: Modifier=Modifier,
    profileWeightKg: Double?=null,
    onValidationChange: (Boolean)->Unit={},
    initialUnit: ProcessWeightUnit=ProcessWeightUnit.KG,
    english: Boolean=false,
    dark: Boolean=isSystemInDarkTheme(),
    autoFocus: Boolean=true
) {
    val palette=InputPalette(dark)
    var unitName by rememberSaveable { mutableStateOf(initialUnit.name) }
    val unit=ProcessWeightUnit.valueOf(unitName)
    var input by rememberSaveable { mutableStateOf("") }
    val focus=remember { FocusRequester() }
    val manager=LocalFocusManager.current
    LaunchedEffect(Unit) {
        val initial=if(OnboardingInputRules.plausibleWeight(valueKg))valueKg else profileWeightKg?.takeIf(OnboardingInputRules::plausibleWeight) ?: 0.0
        onValueChange(initial);input=OnboardingInputRules.displayWeight(initial,unit)
    }
    LaunchedEffect(valueKg) { onValidationChange(OnboardingInputRules.plausibleWeight(valueKg)) }
    InputKeyboardLifecycle(focus,OnboardingInputRules.WEIGHT_FOCUS_DELAY_MS,autoFocus)
    val style=TextStyle(fontSize=56.sp,fontWeight=FontWeight.Bold,color=palette.primary,textAlign=TextAlign.Center)
    val measure=rememberTextMeasurer().measure(input.ifEmpty { "0" },style).size.width
    val width=with(LocalDensity.current) { (measure.toDp()+10.dp).coerceAtLeast(42.dp) }
    Box(modifier.fillMaxSize().background(palette.background)) {
        Text(if(english) "What’s your weight?" else "Quel est ton poids ?",Modifier.padding(start=40.dp,end=20.dp,top=54.dp),fontSize=26.sp,fontWeight=FontWeight.Bold,color=palette.primary,maxLines=3)
        Column(Modifier.fillMaxSize()) {
            Spacer(Modifier.height(210.dp))
            InputUnitToggle("KG","LBS",unit==ProcessWeightUnit.KG,{left->
                val next=if(left)ProcessWeightUnit.KG else ProcessWeightUnit.LBS
                unitName=next.name
                if(valueKg>0)input=OnboardingInputRules.displayWeight(valueKg,next)
            },palette)
            Spacer(Modifier.height(60.dp))
            Row(Modifier.fillMaxWidth().padding(horizontal=40.dp).clickable {focus.requestFocus()},horizontalArrangement=Arrangement.spacedBy(8.dp,Alignment.CenterHorizontally),verticalAlignment=Alignment.Bottom) {
                BasicTextField(input,{raw->input=OnboardingInputRules.normalizeWeight(raw);onValueChange(OnboardingInputRules.kilograms(input,unit))},
                    modifier=Modifier.width(width).focusRequester(focus).alignByBaseline().semantics {contentDescription=if(english) "Weight in ${unit.name.lowercase()}" else "Poids en ${unit.name.lowercase()}"},
                    textStyle=style,singleLine=true,cursorBrush=SolidColor(palette.primary),
                    keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal,autoCorrectEnabled=false,imeAction=ImeAction.Next),
                    keyboardActions=KeyboardActions(onNext={if(OnboardingInputRules.plausibleWeight(valueKg)){manager.clearFocus();onContinue()}}))
                Text(if(unit==ProcessWeightUnit.KG) "kg" else "lbs",Modifier.alignByBaseline(),fontSize=20.sp,fontWeight=FontWeight.Medium,color=palette.body)
            }
        }
    }
}
