package com.process.android

enum class ProcessMainSection(val id:String) {
    COACH("coach"),PLAN("plan"),SCAN("scan"),ROUTINE("routine"),STATISTICS("statistics"),PROFILE("profile"),FOOD("food");
    fun label(english:Boolean)=when(this) {
        COACH->if(english)"Process AI" else "Process IA";PLAN->if(english)"Home" else "Accueil"
        SCAN->"Scan";ROUTINE->"Routine";STATISTICS->if(english)"Streak" else "Série"
        PROFILE->if(english)"Progress" else "Progrès";FOOD->if(english)"Food" else "Alimentation"
    }
    companion object {val tabOrder=listOf(PLAN,FOOD,ROUTINE,PROFILE)}
}

/** Original direction-change anchor and 100dp collapse distance; input units are logical dp. */
class ProcessTabCollapseModel {
    var progress=0f;private set
    private var direction:Boolean?=null
    private var anchor=0f
    private var offset=0f
    fun update(oldOffset:Float,newOffset:Float,isDragging:Boolean,hasScrollableContent:Boolean):Float {
        if(!oldOffset.isFinite()||!newOffset.isFinite())return progress
        if(!hasScrollableContent) {expand();return progress}
        if(!isDragging)return progress
        offset=newOffset
        val increasing=oldOffset<newOffset
        if(direction!=increasing) {direction=increasing;anchor=newOffset-progress*100}
        progress=((newOffset-anchor)/100).coerceIn(0f,1f)
        return progress
    }
    fun endDrag(gestureVelocityY:Float,hasScrollableContent:Boolean):Float {
        val projected=offset-(if(gestureVelocityY.isFinite())gestureVelocityY else 0f)/5
        val candidate=((projected-anchor)/100).coerceIn(0f,1f)
        progress=if(projected>50 && hasScrollableContent && candidate>.5f)1f else 0f
        direction=null;anchor=offset-progress*100
        return progress
    }
    fun expand() {progress=0f;direction=null;anchor=offset}
}
