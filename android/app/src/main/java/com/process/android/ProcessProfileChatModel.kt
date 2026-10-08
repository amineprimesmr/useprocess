package com.process.android

enum class ProfileChatKind { INFO, CHOICE, SUMMARY }
data class ProfileChatChoice(val id:String,val label:String)
data class ProfileChatQuestion(val id:String,val blocks:List<String>,val kind:ProfileChatKind,val choices:List<ProfileChatChoice> = emptyList(),val continueLabel:String="") {
    fun lines(number:Int?=null)=blocks.mapIndexed {index,text->
        val numbered=if(number!=null&&index==blocks.lastIndex)"$text ($number/5)" else text
        MossLine("process.chat.$id.$index",numbered,MossTimeline.graphemes(numbered).size>120,id=="intro_swollen_face"&&index==0)
    }
}
data class ProfileChatProgress(val completed:Set<String> = emptySet(),val answers:Map<String,String> = emptyMap())
data class ProfileChatProfile(val debloatDriver:String?,val hydrationLevel:String?,val sufficientHydration:Boolean?,val nutritionQuality:String?,val sleepHours:Double?,val sleepQuality:String?,val trainingFrequency:String?,val hasSportActivity:Boolean?)
data class ProfileSummarySection(val title:String,val chips:List<String>)

/** Stable persisted IDs and French raw enum values match the live iOS questionnaire. */
object ProcessProfileChatModel {
    val order=listOf("intro_swollen_face","intro_causes","intro_next","debloat_driver","hydration_level","junk_food","sleep_hours","cardio_frequency","profile_summary")
    fun questions(firstName:String,english:Boolean=false):List<ProfileChatQuestion> {
        fun t(fr:String,en:String)=if(english)en else fr
        val name=OnboardingInputRules.trimName(firstName).takeIf(OnboardingInputRules::isRealName)
        fun choices(vararg entries:Triple<String,String,String>)=entries.map {(id,fr,en)->ProfileChatChoice(id,t(fr,en))}
        return listOf(
            ProfileChatQuestion("intro_swollen_face",listOf(
                if(name!=null)t("$name, un visage gonflé, ce n’est presque jamais de la graisse.","$name, a puffy face is almost never fat.") else t("Un visage gonflé, ce n’est presque jamais de la graisse.","A puffy face is almost never fat."),
                t("C’est surtout du liquide retenue qui s’accumule sous ta peau.","It’s mostly retained fluid building up under your skin.")),ProfileChatKind.INFO,continueLabel=t("C’est quoi ce liquide ?","What is that fluid?")),
            ProfileChatQuestion("intro_causes",listOf(t("L’apparence du visage peut varier d’un jour à l’autre et selon les conditions de prise de vue.\n\nProcess t’aide à suivre tes habitudes. Un scan ne permet pas de déterminer la cause d’un gonflement, ni de mesurer tes hormones.","Facial appearance can vary from day to day and with capture conditions.\n\nProcess helps you track your habits. A scan cannot determine the cause of swelling or measure your hormones.")),ProfileChatKind.INFO,continueLabel=t("Et ensuite ?","And then?")),
            ProfileChatQuestion("intro_next",listOf(t("On va noter tes habitudes, puis réaliser un scan pour commencer ton suivi personnel.","We’ll record your habits, then take a scan to start your personal tracking.")),ProfileChatKind.INFO,continueLabel=t("C’est parti","Let’s go")),
            ProfileChatQuestion("debloat_driver",listOf(t("Ton visage est plus gonflé au réveil ?","Is your face more puffy when you wake up?")),ProfileChatKind.CHOICE,choices(
                Triple("sleep","Oui, tous les matins","Yes, every morning"),Triple("sedentary","Oui, certains jours","Yes, some days"),Triple("stress","Surtout en fin de journée","Mostly later in the day"),Triple("unknown","Non, pas vraiment","No, not really"))),
            ProfileChatQuestion("hydration_level",listOf(t("Combien d’eau tu bois par jour ?","How much water do you drink per day?")),ProfileChatKind.CHOICE,choices(
                Triple("Mauvaise","Moins d’1 L","Less than 1 L"),Triple("Bonne","Environ 1 L","About 1 L"),Triple("Très bonne","1,5 à 2 L","1.5 to 2 L"),Triple("Excellente","Plus de 2 L","More than 2 L"))),
            ProfileChatQuestion("junk_food",listOf(t("À quelle fréquence tu manges de la malbouffe ?","How often do you eat junk food?")),ProfileChatKind.CHOICE,choices(
                Triple("Très mauvaise","Tous les jours","Every day"),Triple("Non adaptée","Plusieurs fois par semaine","Several times a week"),Triple("Moyenne","1 à 2 fois par semaine","1 to 2 times a week"),Triple("Excellente","Rarement","Rarely"))),
            ProfileChatQuestion("sleep_hours",listOf(t("Combien d’heures tu dors par nuit ?","How many hours do you sleep per night?")),ProfileChatKind.CHOICE,choices(
                Triple("4.5","Moins de 5 h","Less than 5 hrs"),Triple("5.5","5 à 6 h","5 to 6 hrs"),Triple("6.5","6 à 7 h","6 to 7 hrs"),Triple("7.5","7 à 8 h","7 to 8 hrs"),Triple("8.5","Plus de 8 h","More than 8 hrs"))),
            ProfileChatQuestion("cardio_frequency",listOf(t("Combien de fois tu fais du cardio dans la semaine ?","How many times a week do you do cardio?")),ProfileChatKind.CHOICE,choices(
                Triple("0-2","Presque jamais","Almost never"),Triple("1-2","1 à 2 fois","1 to 2 times"),Triple("3-4","3 à 4 fois","3 to 4 times"),Triple("5+","5 fois ou plus","5 times or more"))),
            ProfileChatQuestion("profile_summary",listOf(
                if(name!=null)t("Merci de me faire confiance, $name.","Thanks for trusting me with this, $name.") else t("Merci de me faire confiance.","Thanks for trusting me with this."),
                t("J’ai verrouillé tes réponses — ton dashboard est prêt 🙌","I've locked your answers in — your dashboard is ready 🙌")),ProfileChatKind.SUMMARY,continueLabel=t("Voir mon dashboard","See my dashboard"))
        )
    }
    fun normalize(progress:ProfileChatProgress):ProfileChatProgress {
        val completed=progress.completed.toMutableSet()
        if("face_scan_offer" in completed)completed.add("profile_summary")
        val questions=questions("")
        val valid=mutableSetOf<String>();val answers=mutableMapOf<String,String>()
        for(q in questions) {
            if(q.id !in completed)break
            val answer=progress.answers[q.id]
            if(q.kind==ProfileChatKind.CHOICE && q.choices.none {it.id==answer})break
            valid.add(q.id);if(answer!=null)answers[q.id]=answer
        }
        return ProfileChatProgress(valid,answers)
    }
    fun current(progress:ProfileChatProgress)=order.firstOrNull {it !in progress.completed}
    fun submit(progress:ProfileChatProgress,questionId:String,choiceId:String?=null,trackingExplainerConfirmed:Boolean=false):ProfileChatProgress {
        if(current(progress)!=questionId)return progress
        val question=questions("").firstOrNull {it.id==questionId} ?: return progress
        if(question.id=="intro_next"&&!trackingExplainerConfirmed)return progress
        if(question.kind==ProfileChatKind.CHOICE && question.choices.none {it.id==choiceId})return progress
        return ProfileChatProgress(progress.completed+questionId,if(choiceId!=null)progress.answers+(questionId to choiceId) else progress.answers)
    }
    fun rewind(progress:ProfileChatProgress):ProfileChatProgress? {
        val last=order.indexOfLast {it in progress.completed};if(last<0)return null
        val keep=order.take(last).toSet()
        return ProfileChatProgress(progress.completed.intersect(keep),progress.answers.filterKeys {it in keep})
    }
    fun answerDisplay(question:ProfileChatQuestion,progress:ProfileChatProgress):String? =
        if(question.id !in progress.completed)null else if(question.kind==ProfileChatKind.CHOICE)question.choices.firstOrNull {it.id==progress.answers[question.id]}?.label else question.continueLabel
    fun profile(progress:ProfileChatProgress):ProfileChatProfile {
        val a=progress.answers;val hours=a["sleep_hours"]?.toDoubleOrNull();val hydration=a["hydration_level"];val cardio=a["cardio_frequency"]
        val quality=hours?.let {when {it<5->"Très mauvais";it<6->"Mauvais";it<7->"Moyen";it<8->"Bon";else->"Excellent"}}
        return ProfileChatProfile(a["debloat_driver"],hydration,hydration?.let {it!in listOf("Mauvaise","Très mauvaise")},a["junk_food"],hours,quality,cardio,cardio?.let {it!="0-2"})
    }
    fun summary(progress:ProfileChatProgress,english:Boolean):List<ProfileSummarySection> {
        fun t(fr:String,en:String)=if(english)en else fr
        val profile=profile(progress)
        val driver=when(profile.debloatDriver) {
            "sleep"->t("Gonflement au réveil","Puffiness when I wake up");"sedentary"->t("Gonflement certains jours","Puffiness some days")
            "stress"->t("Gonflement en fin de journée","Puffiness later in the day");"unknown"->t("Pas de gonflement marqué","No major puffiness")
            else->t("Je ne sais pas quoi améliorer","I'm unsure what to improve")
        }
        val goals=if(profile.hydrationLevel==null)listOf("💎 "+t("Visage moins gonflé","Less puffy face"),"👤 "+t("Profil plus net","Sharper side profile")) else listOf("💧 "+when(profile.hydrationLevel) {
            "Très mauvaise","Mauvaise"->t("Mieux m’hydrater","Hydrate better");"Moyenne","Bonne"->t("Boire plus d’eau","Drink more water");else->t("Garder mes bonnes habitudes","Keep my good habits")
        },"💎 "+t("Visage moins gonflé","Less puffy face"))
        return listOf(ProfileSummarySection(t("Ce qui te freine","Getting in your way"),listOf("🤔 $driver")),ProfileSummarySection(t("Tes objectifs","Your goals"),goals),
            ProfileSummarySection(t("Comment tu veux te sentir","How you want to feel"),listOf("😎 "+if(profile.trainingFrequency in listOf("0-2","1-2"))t("Plus énergique au quotidien","More energy day to day") else t("Confiant dans toutes les situations","Confident in any situation"))),
            ProfileSummarySection(t("Ton pourquoi","Your why"),listOf("💪 "+t("Confiance","Confidence"))))
    }
}
