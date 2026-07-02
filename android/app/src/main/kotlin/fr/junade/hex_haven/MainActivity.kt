package fr.junade.hex_haven

import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}

