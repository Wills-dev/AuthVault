package com.example.authvault

import android.content.pm.ApplicationInfo
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import java.util.concurrent.Executors

/** Only public metadata/signatures cross this channel. No exported private key or auth boolean. */
class BiometricKeyChannel(private val activity: FlutterFragmentActivity) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = ContextCompat.getMainExecutor(activity)
    private val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private var pending: MethodChannel.Result? = null
    private var prompt: BiometricPrompt? = null
    private val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") { cancel(); result.success(null); return }
        if (pending != null) { result.error("BUSY", "A biometric operation is already in progress.", null); return }
        if (call.method == "capabilities") {
            result.success(mapOf("status" to availability())); return
        }
        if (call.method !in listOf("create", "credential", "sign")) { result.notImplemented(); return }
        val subject = call.argument<String>("subjectId")
        if (subject == null || !uuid.matches(subject)) { result.error("INVALID_REQUEST", "Invalid account context.", null); return }
        pending = result
        executor.execute {
            try {
                val prefix = "authvault.v1.${subject.lowercase()}."
                val aliases = store.aliases().toList().filter { it.startsWith(prefix) }
                if (aliases.size > 1) throw KeyFailure("CREDENTIAL_CONFLICT")
                var alias = aliases.firstOrNull()
                if (call.method == "create" && alias == null) {
                    val available = availability()
                    if (available != "AVAILABLE") throw KeyFailure(available)
                    alias = prefix + UUID.randomUUID().toString()
                    val builder = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                        .setDigests(KeyProperties.DIGEST_SHA256)
                        .setUserAuthenticationRequired(true)
                        .setInvalidatedByBiometricEnrollment(true)
                    if (Build.VERSION.SDK_INT >= 30) {
                        builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                    } else {
                        @Suppress("DEPRECATION")
                        builder.setUserAuthenticationValidityDurationSeconds(-1)
                    }
                    KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
                        initialize(builder.build()); generateKeyPair()
                    }
                }
                if (alias == null) throw KeyFailure("KEY_MISSING")
                val privateKey = store.getKey(alias, null) as? PrivateKey ?: throw KeyFailure("KEY_MISSING")
                val info = KeyFactory.getInstance(privateKey.algorithm, "AndroidKeyStore").getKeySpec(privateKey, KeyInfo::class.java)
                if (privateKey.encoded != null || !info.isUserAuthenticationRequired ||
                    info.userAuthenticationValidityDurationSeconds > 0 || !info.isInvalidatedByBiometricEnrollment) {
                    throw KeyFailure("UNSAFE_KEY")
                }
                if (Build.VERSION.SDK_INT >= 30 && info.userAuthenticationType != KeyProperties.AUTH_BIOMETRIC_STRONG) throw KeyFailure("UNSAFE_KEY")
                @Suppress("DEPRECATION")
                val hardware = info.isInsideSecureHardware
                val debug = activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                if (!debug && !hardware) throw KeyFailure("HARDWARE_PROTECTION_REQUIRED")
                val id = alias.removePrefix(prefix)
                if (call.method != "sign") {
                    val metadata = mapOf("credentialId" to id,
                        "publicKey" to Base64.encodeToString(store.getCertificate(alias).publicKey.encoded, Base64.NO_WRAP),
                        "nonExportable" to true, "authPerUse" to true, "hardwareBackedReported" to hardware)
                    main.execute { finish(result, metadata) }
                } else {
                    if (call.argument<String>("credentialId") != id) throw KeyFailure("KEY_MISSING")
                    val purpose = call.argument<String>("purpose")
                    if (purpose !in listOf("ENROLMENT", "LOGIN")) throw KeyFailure("INVALID_REQUEST")
                    val payload = call.argument<String>("payload") ?: throw KeyFailure("INVALID_REQUEST")
                    if (payload.length > 2048 || !Regex("^[A-Za-z0-9_-]+$").matches(payload)) throw KeyFailure("INVALID_REQUEST")
                    val bytes = Base64.decode(payload, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                    val signature = Signature.getInstance("SHA256withECDSA").apply { initSign(privateKey) }
                    main.execute promptSetup@ {
                        if (pending !== result) return@promptSetup
                        try {
                            val ready = availability()
                            if (ready != "AVAILABLE") { fail(result, ready); return@promptSetup }
                            prompt = BiometricPrompt(activity, main, object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authentication: BiometricPrompt.AuthenticationResult) {
                                    if (pending !== result) return
                                    val authorized = authentication.cryptoObject?.signature
                                    if (authorized !== signature) { fail(result, "UNSAFE_KEY"); return }
                                    executor.execute {
                                        try {
                                            authorized.update(bytes)
                                            val signed = Base64.encodeToString(authorized.sign(), Base64.NO_WRAP)
                                            main.execute { finish(result, mapOf("signature" to signed)) }
                                    } catch (error: Exception) { main.execute { fail(result, errorCode(error)) } }
                                }
                            }
                            override fun onAuthenticationFailed() {
                                if (pending !== result) return
                                val active = prompt
                                fail(result, "AUTHENTICATION_FAILED"); active?.cancelAuthentication()
                            }
                            override fun onAuthenticationError(code: Int, message: CharSequence) {
                                fail(result, when (code) {
                                    BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_CANCELED -> "CANCELLED"
                                    BiometricPrompt.ERROR_LOCKOUT -> "TEMPORARY_LOCKOUT"
                                    BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "PERMANENT_LOCKOUT"
                                    BiometricPrompt.ERROR_NO_BIOMETRICS -> "NOT_ENROLLED"
                                    BiometricPrompt.ERROR_HW_NOT_PRESENT, BiometricPrompt.ERROR_HW_UNAVAILABLE -> "UNAVAILABLE"
                                    else -> "AUTHENTICATION_FAILED"
                                })
                            }
                        })
                        val options = BiometricPrompt.PromptInfo.Builder()
                            .setTitle(if (purpose == "ENROLMENT") "Enrol AuthVault biometrics" else "Verify AuthVault sign-in")
                            .setSubtitle("Authorize this device key to sign a one-time challenge")
                            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                            .setNegativeButtonText("Cancel").setConfirmationRequired(true).build()
                        prompt!!.authenticate(options, BiometricPrompt.CryptoObject(signature))
                        } catch (error: Exception) { fail(result, errorCode(error)) }
                    }
                }
            } catch (error: Exception) { main.execute { fail(result, errorCode(error)) } }
        }
    }
    private fun availability(): String = when (BiometricManager.from(activity).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
        BiometricManager.BIOMETRIC_SUCCESS -> "AVAILABLE"
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "NOT_ENROLLED"
        else -> "UNAVAILABLE"
    }
    private fun finish(result: MethodChannel.Result, value: Any?) {
        if (pending !== result) return
        pending = null; prompt = null; result.success(value)
    }
    private fun fail(result: MethodChannel.Result, code: String) {
        if (pending !== result) return
        pending = null; result.error(code, "The biometric key operation could not be completed.", null)
    }
    private fun errorCode(error: Exception): String = when (error) {
        is KeyPermanentlyInvalidatedException -> "KEY_INVALIDATED"
        is KeyFailure -> error.reason
        is android.security.keystore.UserNotAuthenticatedException -> "AUTHENTICATION_FAILED"
        else -> "KEY_OPERATION_FAILED"
    }
    fun cancel() {
        val result = pending ?: return
        val active = prompt
        fail(result, "CANCELLED"); active?.cancelAuthentication(); prompt = null
    }
    fun close() { cancel(); executor.shutdown() }
    private class KeyFailure(val reason: String) : Exception()
}
