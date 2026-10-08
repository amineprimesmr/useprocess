package com.process.android

import java.util.Locale

enum class ProcessAppearance(val french:String,val english:String) {
    SYSTEM("Système","System"),DARK("Sombre","Dark"),LIGHT("Clair","Light")
}
enum class ProcessLanguage(val code:String,val nativeName:String,val flag:String) {
    FRENCH("fr","Français","🇫🇷"),ENGLISH("en","English","🇺🇸"),JAPANESE("ja","日本語","🇯🇵"),GERMAN("de","Deutsch","🇩🇪"),KOREAN("ko","한국어","🇰🇷"),SPANISH("es","Español","🇪🇸"),PORTUGUESE_BRAZIL("pt-BR","Português (Brasil)","🇧🇷");
    val label get()="$flag $nativeName"
    companion object {
        fun normalize(raw:String):ProcessLanguage {
            val lower=raw.lowercase(Locale.ROOT).replace('_','-')
            return entries.firstOrNull {lower.startsWith(it.code.substringBefore('-').lowercase(Locale.ROOT))}?:ENGLISH
        }
        fun resolve(preferred:List<String>):ProcessLanguage {
            for(tag in preferred) {
                val lower=tag.lowercase(Locale.ROOT).replace('_','-')
                entries.firstOrNull {lower.startsWith(it.code.substringBefore('-').lowercase(Locale.ROOT))}?.let {return it}
            }
            return ENGLISH
        }
    }
}
enum class ProcessSettingsAction {ACCOUNT,HEALTH,SUPPORT,HELP_CENTER,RATE,HELP_PRIVACY,NOTIFICATIONS,REFERRAL,STUDIO,SHARE,TIKTOK,INSTAGRAM}
data class ProcessSettingsState(
    val appearance:ProcessAppearance=ProcessAppearance.SYSTEM,
    val language:ProcessLanguage=ProcessLanguage.FRENCH,
    val firstName:String?=null,
    val notificationsEnabled:Boolean?=null,
    val healthConnected:Boolean?=null,
    val showsStudio:Boolean=false,
    val version:String="—",val build:String="—",
)
