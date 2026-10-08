package com.process.android

enum class HomeTutorialStep(val frenchTitle:String,val englishTitle:String,val frenchMessage:String,val englishMessage:String) {
 FACE_SCAN("Scan analyse","Scan analysis","Photographie ton visage pour mesurer ton debloat. Process compare tes scans et te montre ta progression visuelle jour après jour.","Photograph your face to track debloat. Process compares your scans and shows your visual progress day after day."),
 HYDRATION("Hydratation","Hydration","Suis ton eau du jour, ajoute des verres en un tap et lance le minuteur d’hydratation.","Track daily water intake, log glasses in one tap, and start the hydration timer."),
 NUTRITION("Alimentation debloat","Debloat nutrition","Tes 3 plats du jour anti-inflammatoires. Touche la carte pour ouvrir le catalogue et changer un repas.","Your 3 anti-inflammatory dishes of the day. Tap the card to open the catalog and swap a meal."),
 ROUTINE("Circuit lymphatique","Lymphatic circuit","Drainage lymphatique guidé pour réduire le gonflement du visage. Quelques minutes par jour suffisent.","Guided lymphatic drainage to reduce facial puffiness. Just a few minutes a day."),
 STREAK("Série","Streak","Suis ta régularité, valide tes jours et garde ta série active. Chaque jour compte pour ton debloat.","Track consistency, validate your days, and keep your streak alive. Every day counts for your debloat.");
 val requestedTab get()=if(this==STREAK)"profile"else"plan"
 val isTabStep get()=this==STREAK
 fun title(english:Boolean)=if(english)englishTitle else frenchTitle
 fun message(english:Boolean)=if(english)englishMessage else frenchMessage
}
data class HomeTutorialProgress(val active:Boolean=false,val index:Int=0,val completed:Boolean=false) {
 init {require(index in HomeTutorialStep.entries.indices);require(!active||!completed)}
 val step get()=HomeTutorialStep.entries[index]
 fun begin(planAvailable:Boolean,suppressed:Boolean)=if(planAvailable&&!suppressed&&!completed&&!active)copy(active=true,index=0)else this
 fun advance()=if(!active)this else if(index==HomeTutorialStep.entries.lastIndex)finish()else copy(index=index+1)
 fun finish()=copy(active=false,completed=true)
 fun constrainsHome(planAvailable:Boolean,suppressed:Boolean)=active&&planAvailable&&!suppressed&&!step.isTabStep
 fun showsSection(section:HomeTutorialStep,planAvailable:Boolean=true,suppressed:Boolean=false):Boolean {
  if(!constrainsHome(planAvailable,suppressed))return true
  val sectionOrder=when(section){HomeTutorialStep.FACE_SCAN->0;HomeTutorialStep.HYDRATION,HomeTutorialStep.NUTRITION->1;HomeTutorialStep.ROUTINE->2;HomeTutorialStep.STREAK->3}
  val currentOrder=when(step){HomeTutorialStep.FACE_SCAN->0;HomeTutorialStep.HYDRATION,HomeTutorialStep.NUTRITION->1;HomeTutorialStep.ROUTINE->2;HomeTutorialStep.STREAK->3}
  return sectionOrder<=currentOrder
 }
 fun showsMealCards(planAvailable:Boolean=true,suppressed:Boolean=false)=!(constrainsHome(planAvailable,suppressed)&&step==HomeTutorialStep.HYDRATION)
 val shouldScrollVertically get()=active&&!step.isTabStep&&step!=HomeTutorialStep.NUTRITION
}
