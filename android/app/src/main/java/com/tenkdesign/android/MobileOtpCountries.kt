package com.tenkdesign.android
import android.content.Context
import com.process.android.R
import org.json.JSONArray
/** Original source order and spellings retained. Dataset is archival, not current numbering metadata. */
fun loadMobileOtpCountries(context:Context):List<MobileOtpCountry> {
 val data=context.resources.openRawResource(R.raw.tenk_country_codes).bufferedReader().use {JSONArray(it.readText())}
 return (0 until data.length()).map {i->data.getJSONObject(i).let {MobileOtpCountry(it.getString("name"),if(it.isNull("dialCode"))null else it.getString("dialCode"),it.getString("code"))}}
}
