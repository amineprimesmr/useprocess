package com.process.android

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*

/** Host persists onCommit and resolves authenticated profile/username conflicts. No backend is embedded. */
@Composable fun ProcessFirstNameInput(
    value: String,
    onValueChange: (String)->Unit,
    onCommit: (String)->Unit,
    onComplete: ()->Unit,
    modifier: Modifier=Modifier,
    profileName: String?=null,
    authName: String?=null,
    onValidationChange: (Boolean)->Unit={},
    english: Boolean=false,
    dark: Boolean=isSystemInDarkTheme(),
    autoFocus: Boolean=true
) {
    val palette=InputPalette(dark)
    val focus=remember { FocusRequester() }
    val currentValue by rememberUpdatedState(value)
    val commit by rememberUpdatedState(onCommit)
    var lastCommitted by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(Unit) { onValueChange(OnboardingInputRules.initialName(value,profileName,authName)) }
    LaunchedEffect(value) { onValidationChange(OnboardingInputRules.trimName(value).isNotEmpty()) }
    DisposableEffect(Unit) {
        onDispose {
            val name=OnboardingInputRules.trimName(currentValue)
            if(OnboardingInputRules.isRealName(name) && name!=lastCommitted) { lastCommitted=name;commit(name) }
        }
    }
    InputKeyboardLifecycle(focus,OnboardingInputRules.NAME_FOCUS_DELAY_MS,autoFocus)
    Column(modifier.fillMaxSize().background(palette.background)) {
        Spacer(Modifier.height(282.dp))
        BasicTextField(value,onValueChange,singleLine=true,
            modifier=Modifier.fillMaxWidth().padding(horizontal=40.dp).focusRequester(focus).semantics {contentDescription=if(english) "First name" else "Prénom"},
            textStyle=TextStyle(fontSize=36.sp,fontWeight=FontWeight.Medium,color=palette.primary,textAlign=TextAlign.Center),cursorBrush=SolidColor(palette.primary),
            keyboardOptions=KeyboardOptions(capitalization=KeyboardCapitalization.Words,autoCorrectEnabled=false,imeAction=ImeAction.Next),
            keyboardActions=KeyboardActions(onNext={if(OnboardingInputRules.trimName(value).isNotEmpty())onComplete()}),
            decorationBox={input->Box {
                if(value.isEmpty())Text(if(english) "What should we call you?" else "Comment devons-nous t’appeler ?",Modifier.fillMaxWidth(),fontSize=22.sp,fontWeight=FontWeight.Medium,color=palette.muted,textAlign=TextAlign.Center)
                input()
            }})
    }
}
