package com.process.android
import org.json.JSONArray
import org.json.JSONObject

/** Retain the full source JSON separately; the UI projection is deliberately read-only. */
data class ProcessPlanDocument(val rawJson:String,val plan:ProcessRemotePlan)
object ProcessPlanJson {
    fun decode(raw:String,expectedUserId:String):ProcessPlanDocument {
        require(raw.toByteArray(Charsets.UTF_8).size<=4*1024*1024){"Plan document exceeds size limit"}
        // Reject excessive nesting before JSONObject's recursive parser gets control.
        var depth=0;var quoted=false;var escaped=false
        for(char in raw) {
            if(quoted) {
                if(escaped)escaped=false else if(char=='\\')escaped=true else if(char=='"')quoted=false
            } else when(char) {
                '"'->quoted=true
                '{','['->{depth++;require(depth<=48){"Plan document is too deeply nested"}}
                '}',']'->{depth--;require(depth>=0){"Unbalanced plan document"}}
            }
        }
        require(!quoted&&depth==0){"Unbalanced plan document"}
        fun convert(value:Any?,depth:Int):Any? {
            require(depth<=48){"Plan document is too deeply nested"}
            return when(value) {
                null,JSONObject.NULL->null
                is JSONObject->value.keys().asSequence().associateWith{convert(value.get(it),depth+1)}
                is JSONArray->{require(value.length()<=10000);(0 until value.length()).map{convert(value.get(it),depth+1)}}
                else->value
            }
        }
        @Suppress("UNCHECKED_CAST") val decoded=convert(JSONObject(raw),0) as Map<String,Any?>
        return ProcessPlanDocument(raw,ProcessRemotePlanDecoder.decode(decoded,expectedUserId))
    }
}
