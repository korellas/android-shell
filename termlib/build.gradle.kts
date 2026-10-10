plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

val upstreamNative = configurations.create("upstreamNative") {
    isCanBeConsumed = false
    isTransitive = false
}

// Reuse the published native engine, not its JVM classes.
val extractUpstreamNative = tasks.register<Sync>("extractUpstreamNative") {
    from(provider { upstreamNative.map { zipTree(it) } })
    include("jni/**")
    into(layout.buildDirectory.dir("upstream-native"))
}

android {
    namespace = "org.connectbot.terminal"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        minSdk = libs.versions.minSdk.get().toInt()
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions.unitTests.isIncludeAndroidResources = true
}

androidComponents {
    onVariants { variant ->
        variant.sources.jniLibs?.addStaticSourceDirectory(
            layout.buildDirectory.dir("upstream-native/jni").get().asFile.absolutePath,
        )
    }
}

tasks.named("preBuild") {
    dependsOn(extractUpstreamNative)
}

dependencies {
    upstreamNative(libs.termlib)

    api(platform(libs.androidx.compose.bom))
    api(libs.androidx.compose.ui)
    implementation(libs.androidx.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)

    testImplementation(libs.junit)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.mockito.core)
}
