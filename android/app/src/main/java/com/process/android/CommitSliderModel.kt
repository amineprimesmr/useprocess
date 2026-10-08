package com.process.android

class CommitSliderModel {
    var progress=0f;private set
    var committed=false;private set
    private var bucket=-1
    fun drag(translation:Float,travel:Float):Int? {
        if(committed||!translation.isFinite()||!travel.isFinite()||travel<=0)return null
        progress=(translation/travel).coerceIn(0f,1f)
        val next=(progress*10).toInt()
        return if(next>=2&&next>bucket){bucket=next;next}else null
    }
    fun release():Boolean {
        if(committed)return false
        if(progress>=.92f)return activate()
        cancel();return false
    }
    fun cancel() {if(!committed){progress=0f;bucket=-1}}
    fun activate():Boolean {if(committed)return false;committed=true;progress=1f;return true}
    fun titleReveal()=if(committed)1f else ((progress-.06f)/.78f).coerceIn(0f,1f)
}
