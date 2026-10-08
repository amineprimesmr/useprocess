package com.process.android

/** Persisted IDs and migration match Process's live iOS flow. */
enum class OnboardingStep(val id:Int) {
    Gender(1),Age(2),Height(3),FirstName(4),Motivation(11),Estimation(22),SignIn(52),Referral(53),
    Creation(57),Biometric(58),Payment(60),Transformation(64),Complete(66),Weight(67),Dashboard(69),
    Commitment(70),FaceLeverage(71),Welcome(72),BodyFat(73),WaterRetention(74),LymphDrainage(75);
    val usesInternalContinue:Boolean get()=this in setOf(Motivation,Biometric,Transformation,Dashboard,Commitment,Creation,Payment,SignIn,FaceLeverage,Welcome,BodyFat,WaterRetention,LymphDrainage)
    val unpaidResume:OnboardingStep get()=if(this in setOf(Payment,SignIn,Commitment,Complete,Welcome,BodyFat,WaterRetention,LymphDrainage)) Commitment else this
    fun nextVisible(referralEnabled:Boolean=true):OnboardingStep? {
        val position=liveOrder.indexOf(this)
        if(position<0) return null
        return liveOrder.drop(position+1).firstOrNull { it!=Complete && (referralEnabled || it!=Referral) }
    }
    companion object {
        val liveOrder=listOf(Gender,Age,Height,Weight,FirstName,FaceLeverage,Motivation,Dashboard,Creation,Estimation,Biometric,Transformation,Referral,Commitment,Payment,Welcome,BodyFat,WaterRetention,LymphDrainage,SignIn,Complete)
        fun visibleFlow(referralEnabled:Boolean=true)=liveOrder.filter { it!=Complete && (referralEnabled || it!=Referral) }
        fun resolve(raw:Int):OnboardingStep = entries.firstOrNull { it.id==raw } ?: when(raw) {
            5,6,7,8,9,10->Motivation
            12,13,14,15,16,17,18,42->Dashboard
            19,20,21,23->Estimation
            in 24..41->Creation
            in 43..51,54,55,56->Biometric
            59->Commitment
            61,62,65->SignIn
            63->FirstName
            68->Weight
            else->Gender
        }
    }
}
