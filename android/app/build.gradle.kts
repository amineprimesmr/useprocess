import java.util.Properties

plugins {
    id("com.google.gms.google-services")
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
// Private upload credentials stay outside the repository and reusable packages.
val uploadPropertiesFile = file(
    providers.environmentVariable("PROCESS_ANDROID_SIGNING_FILE").orNull
        ?: "${System.getProperty("user.home")}/Library/Application Support/Process Android Signing/keystore.properties"
)
val uploadProperties = Properties().apply {
    if (uploadPropertiesFile.isFile) uploadPropertiesFile.inputStream().use { load(it) }
}
val hasUploadSigning = uploadPropertiesFile.isFile
if (hasUploadSigning) {
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach {
        require(!uploadProperties.getProperty(it).isNullOrBlank()) { "Missing private signing field: $it" }
    }
    require(file(uploadProperties.getProperty("storeFile")).isFile) { "Configured upload keystore is unavailable" }
}

val enableUiTests = providers.gradleProperty("process.uiTests").orNull == "true"

android {
    testOptions.unitTests.isIncludeAndroidResources = enableUiTests
    if (enableUiTests) sourceSets.getByName("test").java.srcDir("src/uiTest/java")
    if (hasUploadSigning) {
        signingConfigs.create("upload") {
            storeFile = file(uploadProperties.getProperty("storeFile"))
            storePassword = uploadProperties.getProperty("storePassword")
            keyAlias = uploadProperties.getProperty("keyAlias")
            keyPassword = uploadProperties.getProperty("keyPassword")
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("upload")
    }
    namespace = "com.process.android"
    compileSdk = 36
    defaultConfig { applicationId = "com.process.android"; minSdk = 28; targetSdk = 36; versionCode = 1; versionName = "0.1.0"; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
dependencies {
    implementation("androidx.camera:camera-camera2:1.6.2")
    implementation("androidx.camera:camera-lifecycle:1.6.2")
    implementation("androidx.camera:camera-view:1.6.2")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation(platform("com.google.firebase:firebase-bom:35.0.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-functions")
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    testImplementation("junit:junit:4.13.2")
    if (enableUiTests) {
        testImplementation("org.robolectric:robolectric:4.17")
        testImplementation("androidx.compose.ui:ui-test-junit4")
        debugImplementation("androidx.compose.ui:ui-test-manifest")
    }
}

// Isolated host rendering is opt-in; no emulator or physical-device controls are used.
tasks.withType<org.gradle.api.tasks.testing.Test>().configureEach {
    maxParallelForks = 1
    maxHeapSize = "1024m"
    jvmArgs("-XX:ActiveProcessorCount=2")
    if (enableUiTests) {
        listOf("java.base/java.lang", "java.base/java.util", "java.base/java.io", "java.base/java.net", "java.base/java.security", "java.base/java.text", "java.base/jdk.internal.access", "java.desktop/java.awt.font", "jdk.compiler/com.sun.tools.javac.api").forEach {
            jvmArgs("--add-opens=$it=ALL-UNNAMED")
        }
        systemProperty("robolectric.dependency.repo.url", "https://repo.maven.apache.org/maven2")
    }
}
