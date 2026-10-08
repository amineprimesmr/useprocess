package com.process.android
import java.net.URI
import java.net.URLEncoder

enum class ProcessLegalPage(val path:String,val fragment:String?=null) {
    TERMS("cgu"),PRIVACY("confidentialite"),FACE_DATA("confidentialite","donnees-faciales"),AI_DATA("confidentialite","intelligence-artificielle"),NOTICE("mentions-legales"),SUPPORT("support"),SOURCES("sources-sante")
}
class ProcessLegalLinks(websiteOrigin:String="https://processdebloat.com",supportEmail:String="contact@processdebloat.com") {
    val origin:String=runCatching {URI(websiteOrigin)}.getOrNull()?.takeIf {it.scheme=="https"&&it.host in setOf("useprocess.xyz","processdebloat.com")&&it.userInfo==null&&it.port==-1}?.let {"https://${it.host}"} ?: "https://processdebloat.com"
    val supportEmail:String=supportEmail.takeIf {it.matches(Regex("[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"))} ?: "contact@processdebloat.com"
    fun page(page:ProcessLegalPage,language:String="fr"):String {
        val locale=language.takeIf {it in setOf("fr","en","de","es","it","pt-BR","ja","ko")} ?: "fr"
        return "$origin/${page.path}"+(if(locale=="fr")""else"?lang=$locale")+(page.fragment?.let {"#$it"}?:"")
    }
    fun supportDraft(body:String?=null):String {
        fun encode(s:String)=URLEncoder.encode(s,"UTF-8").replace("+","%20")
        return "mailto:$supportEmail?subject=${encode("Process — Support")}"+(body?.takeIf {it.isNotEmpty()}?.let {"&body=${encode(it)}"}?:"")
    }
}
