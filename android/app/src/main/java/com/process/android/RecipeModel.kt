package com.process.android

import java.text.Normalizer
import java.util.Locale

data class RecipeCopy(val french:String,val english:String) {fun text(english:Boolean)=if(english)this.english else french}
data class RecipeIngredient(val name:RecipeCopy,val quantity:RecipeCopy,val role:String) {
    val isBeverage:Boolean get() {
        val n=Normalizer.normalize(name.french,Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"").lowercase(Locale.ROOT)
        return role.lowercase(Locale.ROOT).contains("hydrat")||n.contains("eau de coco")||n.contains("eau coco")||(n.contains("verre")&&n.contains("eau"))||n=="eau"||n.startsWith("eau ")||listOf("eau filtree","eau minerale","eau citron").any {it in n}
    }
    fun displayLine(english:Boolean):String {
        val n=name.text(english).trim();val q=quantity.text(english).trim()
        if(n.isEmpty())return q
        if(q.lowercase(Locale.ROOT) in setOf("","—","-","n/a","na"))return n
        if(n.startsWith("$q ",ignoreCase=true)||n.contains("($q)",ignoreCase=true))return n
        return "$q $n"
    }
}
data class ProcessRecipe(
    val id:String,val name:RecipeCopy,val slot:String,val section:String,val summary:RecipeCopy,
    val ingredients:List<RecipeIngredient>,val preparationMinutes:Int,val preparation:RecipeCopy,val tip:RecipeCopy,val imageResource:Int,
) {val foodIngredients get()=ingredients.filterNot {it.isBeverage}}

/** A host-provided nutrition estimate, never inferred from the ignored legacy recipe scores. */
data class RecipeAssessment(
    val score:Int,val fluidBalance:Int,val digestiveComfort:Int,val foodQuality:Int,
    val label:RecipeCopy,val summary:RecipeCopy,val ratioLabel:String,val optimized:Boolean,
    val caution:RecipeCopy?=null,val estimated:Boolean=true,
) {init {require(listOf(score,fluidBalance,digestiveComfort,foodQuality).all {it in 0..100})}}

object RecipePreparation {
    private fun clean(raw:String):String {
        val s=raw.trim().replace(Regex("^\\d+[.)]\\s*"),"").trim('.','…',' ')
        if(s.isEmpty())return ""
        val first=s.substring(0,s.offsetByCodePoints(0,1));val upper=first.uppercase(Locale.ROOT)+s.substring(first.length)
        return if(upper.last() in ".!?")upper else "$upper."
    }
    fun steps(raw:String):List<String> {
        val trimmed=raw.trim();if(trimmed.isEmpty()||trimmed.startsWith('{')||trimmed.startsWith('['))return emptyList()
        val normalized=trimmed.replace("\r\n","\n").replace('\r','\n').replace(" ; ",". ").replace("; ",". ").replace(" ;",". ").trim()
        val numbered=Regex("(?:^|\\n)\\s*\\d+[.)]\\s*")
        if(numbered.containsMatchIn(normalized))return normalized.lines().flatMap {line ->
            val matches=Regex("\\d+[.)]\\s*").findAll(line).toList()
            if(matches.isEmpty())listOf(line)else matches.mapIndexed {i,m ->line.substring(m.range.last+1,if(i+1<matches.size)matches[i+1].range.first else line.length)}
        }.map(::clean).filter {it.isNotEmpty()}
        val lines=normalized.lines().map(::clean).filter {it.isNotEmpty()};if(lines.size>=2)return lines
        val dashed=normalized.split(" — ").map(::clean).filter {it.isNotEmpty()}
        if(dashed.size>=2&&dashed.all {it.length>=12})return dashed
        val sentences=Regex("[^.!?]+[.!?]?").findAll(normalized).map {clean(it.value)}.filter {it.length>=6}.toList()
        return sentences.ifEmpty {listOf(clean(normalized)).filter {it.isNotEmpty()}}
    }
}
