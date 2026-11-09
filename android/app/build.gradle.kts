import java.util.Properties

plugins {
	alias(libs.plugins.android.application)
	alias(libs.plugins.kotlin.compose)
	alias(libs.plugins.kotlin.serialization)
}

val localProps = Properties().apply {
	rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
// Signing key for release APKs: only on Nelson's Mac (git-ignored), see PLAN.md §2.
val keystoreProps = Properties().apply {
	rootProject.file("keystore.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

android {
	namespace = "com.nelsul.curitibatrip"
	compileSdk = 37

	defaultConfig {
		applicationId = "com.nelsul.curitibatrip"
		minSdk = 26
		targetSdk = 37
		versionCode = 10
		versionName = "0.6.2"
		buildConfigField("String", "API_BASE_URL", "\"https://viagem.nelsul.com\"")
	}

	signingConfigs {
		if (keystoreProps.getProperty("storeFile") != null) {
			create("release") {
				storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
				storePassword = keystoreProps.getProperty("storePassword")
				keyAlias = keystoreProps.getProperty("keyAlias")
				keyPassword = keystoreProps.getProperty("keyPassword")
			}
		}
	}

	buildTypes {
		debug {
			// local web server for testing (the emulator reaches the Mac at 10.0.2.2)
			localProps.getProperty("apiBaseUrl")?.let { buildConfigField("String", "API_BASE_URL", "\"$it\"") }
			applicationIdSuffix = ".debug"
		}
		release {
			// real phones only (the emulator uses debug builds): a much smaller APK
			ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }
			isMinifyEnabled = true
			isShrinkResources = true
			proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
			signingConfig = signingConfigs.findByName("release")
		}
	}

	buildFeatures {
		compose = true
		buildConfig = true
	}
}

dependencies {
	implementation(libs.androidx.core.ktx)
	implementation(libs.androidx.activity.compose)
	implementation(libs.androidx.lifecycle.runtime.compose)
	implementation(libs.androidx.lifecycle.viewmodel.compose)
	implementation(libs.androidx.navigation.compose)
	implementation(platform(libs.compose.bom))
	implementation(libs.compose.ui)
	implementation(libs.compose.foundation)
	implementation(libs.compose.material3)
	implementation(libs.compose.ui.tooling.preview)
	debugImplementation(libs.compose.ui.tooling)
	implementation(libs.kotlinx.serialization.json)
	implementation(libs.kotlinx.coroutines.android)
	implementation(libs.okhttp)
	implementation(libs.coil.compose)
	implementation(libs.coil.network.okhttp)
	implementation(libs.coil.video)
	implementation(libs.androidx.work)
	implementation(libs.androidx.exifinterface)
	implementation(libs.play.location)
	implementation(libs.maplibre)
}
