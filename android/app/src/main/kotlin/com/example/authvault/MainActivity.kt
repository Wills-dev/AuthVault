package com.example.authvault

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var biometricKeys: BiometricKeyChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        biometricKeys = BiometricKeyChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "authvault/biometric_keys")
            .setMethodCallHandler(biometricKeys)
    }
    override fun onStop() {
        if (!isChangingConfigurations) biometricKeys?.cancel()
        super.onStop()
    }
    override fun onDestroy() { biometricKeys?.close(); super.onDestroy() }
}
