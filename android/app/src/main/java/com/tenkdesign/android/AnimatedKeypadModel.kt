package com.tenkdesign.android

/** Whole-number input matching the original nine-digit keypad, without floating-point conversion. */
data class AnimatedKeypadValue(val digits:String="") {
    init {require(digits.length<=9&&digits.all {it in '0'..'9'}&&(digits.isEmpty()||digits.first()!='0')) {"Keypad accepts up to nine digits without a leading zero"}}
    val atLimit:Boolean get()=digits.length>=9
    val amount:Int get()=digits.toIntOrNull()?:0
    val formatted:String get()=if(digits.isEmpty())"0" else digits.reversed().chunked(3).joinToString(",").reversed()
    fun append(number:Int)=if(number !in 0..9||atLimit||(number==0&&digits.isEmpty()))this else AnimatedKeypadValue(digits+number.toString())
    fun deleteLast()=if(digits.isEmpty())this else AnimatedKeypadValue(digits.dropLast(1))
}
