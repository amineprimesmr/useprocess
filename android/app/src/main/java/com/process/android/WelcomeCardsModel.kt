package com.process.android

data class WelcomeCardDismissal(val frontDismissed:Boolean=false,val stackDismissed:Boolean=false) {
    fun normalized()=if(stackDismissed)copy(frontDismissed=true)else this
    fun dismissTop()=if(frontDismissed||stackDismissed)WelcomeCardDismissal(true,true)else WelcomeCardDismissal(true,false)
}
