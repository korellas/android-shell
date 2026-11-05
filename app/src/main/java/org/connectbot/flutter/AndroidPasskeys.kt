/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.connectbot.flutter

import android.content.pm.PackageManager
import android.os.Build
import android.util.Base64
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialCancellationException
import kotlinx.coroutines.withContext
import org.connectbot.data.entity.Pubkey
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.interfaces.ECPublicKey
import java.security.spec.X509EncodedKeySpec

internal const val PASSKEY_RP_ID = "korellas.github.io"
internal const val PASSKEY_TYPE = "PASSKEY"
internal const val PASSKEY_SSH_ALGORITHM = "webauthn-sk-ecdsa-sha2-nistp256@openssh.com"

internal fun passkeyBytes(text: String): ByteArray = Base64.decode(text, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
internal fun passkeyText(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

internal fun validPasskeyPublicKey(bytes: ByteArray): Boolean = runCatching {
    val key = KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(bytes)) as ECPublicKey
    key.params.curve.field.fieldSize == 256
}.getOrDefault(false)

internal fun Pubkey.isPasskey(): Boolean = type == PASSKEY_TYPE && privateKey == null &&
    storageType == org.connectbot.data.entity.KeyStorageType.PASSKEY && validPasskeyPublicKey(publicKey) &&
    runCatching { keystoreAlias != null && passkeyBytes(keystoreAlias).size in 1..1023 && passkeyText(passkeyBytes(keystoreAlias)) == keystoreAlias }.getOrDefault(false)

internal class AndroidPasskeys(private val activity: FlutterShellActivity) {
    val available: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

    @Suppress("DEPRECATION")
    fun origin(): String {
        val manager = activity.packageManager
        val certificate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo!!.apkContentsSigners.single().toByteArray()
        } else {
            manager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES).signatures!!.single().toByteArray()
        }
        return "android:apk-key-hash:" + passkeyText(MessageDigest.getInstance("SHA-256").digest(certificate))
    }

    suspend fun create(requestJson: String): Wire? {
        check(available) { activity.getString(org.connectbot.R.string.flutter_passkeys_require_android9) }
        require(JSONObject(requestJson).getJSONObject("rp").getString("id") == PASSKEY_RP_ID)
        return try {
            val response = withContext(activity.dispatchers.main) {
                CredentialManager.create(activity).createCredential(activity, CreatePublicKeyCredentialRequest(requestJson))
            } as CreatePublicKeyCredentialResponse
            mapOf("responseJson" to response.registrationResponseJson, "origin" to withContext(activity.dispatchers.io) { origin() })
        } catch (_: CreateCredentialCancellationException) {
            null
        }
    }

    private suspend fun createPrfCredential(name: String): String? {
        fun randomText() = passkeyText(ByteArray(32).also(SecureRandom()::nextBytes))
        val user = randomText()
        val options = JSONObject().put("rp", JSONObject().put("id", PASSKEY_RP_ID).put("name", "Tilde"))
            .put("user", JSONObject().put("id", user).put("name", name).put("displayName", name))
            .put("challenge", randomText())
            .put("pubKeyCredParams", JSONArray().put(JSONObject().put("type", "public-key").put("alg", -7)))
            .put("authenticatorSelection", JSONObject().put("residentKey", "required").put("requireResidentKey", true).put("userVerification", "required"))
            .put("attestation", "none").put("extensions", JSONObject().put("prf", JSONObject()))
        val created = create(options.toString()) ?: return null
        val credential = JSONObject(created["responseJson"] as String)
        if (credential.optJSONObject("clientExtensionResults")?.optJSONObject("prf")?.optBoolean("enabled") != true) {
            throw UnsupportedOperationException("PRF is unavailable")
        }
        val credentialId = credential.getString("rawId")
        require(credential.getString("type") == "public-key" && passkeyBytes(credentialId).size in 1..1023 && passkeyText(passkeyBytes(credentialId)) == credentialId)
        return credentialId
    }

    suspend fun createPrfProbe(): String? {
        val credentialId = createPrfCredential("Tilde PRF test") ?: return null
        val salt = ByteArray(32).also(SecureRandom()::nextBytes)
        val secret = evaluatePrf(credentialId, salt) ?: return null
        return try {
            withContext(activity.dispatchers.default) { createPrfProbe(credentialId, salt, secret) }
        } finally {
            secret.fill(0)
        }
    }

    suspend fun verifyPrfProbe(text: String): Boolean {
        val probe = parsePrfProbe(text)
        val secret = evaluatePrf(probe.getString("credentialId"), passkeyBytes(probe.getString("salt"))) ?: return false
        try {
            withContext(activity.dispatchers.default) { verifyPrfProbe(probe, secret) }
        } finally {
            secret.fill(0)
        }
        return true
    }

    private suspend fun evaluatePrf(credentialId: String, salt: ByteArray): ByteArray? {
        check(available) { activity.getString(org.connectbot.R.string.flutter_passkeys_require_android9) }
        val options = JSONObject().put("rpId", PASSKEY_RP_ID)
            .put("challenge", passkeyText(ByteArray(32).also(SecureRandom()::nextBytes)))
            .put("userVerification", "required")
            .put("allowCredentials", JSONArray().put(JSONObject().put("type", "public-key").put("id", credentialId)))
            .put("extensions", JSONObject().put("prf", JSONObject().put("eval", JSONObject().put("first", passkeyText(salt)))))
        return try {
            val credential = withContext(activity.dispatchers.main) {
                CredentialManager.create(activity).getCredential(activity, GetCredentialRequest(listOf(GetPublicKeyCredentialOption(options.toString()))))
            }.credential as PublicKeyCredential
            prfProbeSecret(credential.authenticationResponseJson, credentialId)
        } catch (_: GetCredentialCancellationException) {
            null
        }
    }

    suspend fun generateCredential(args: Wire): PasskeyCredential? {
        val nickname = args.text("nickname").trim()
        val kind = args.text("kind", "key")
        require(nickname.isNotEmpty() && nickname.length <= 256 && kind in listOf("key", "password"))
        val password = args.text("password").toByteArray(Charsets.UTF_8)
        try {
            if (kind == "password") {
                require(password.size in 1..16384 && args.text("hostname").isNotBlank() && args.text("username").isNotBlank() && args.number("port", 22) in 1..65535)
            }
            val credentialId = createPrfCredential(nickname) ?: return null
            val salt = ByteArray(32).also(SecureRandom()::nextBytes)
            val secret = evaluatePrf(credentialId, salt) ?: return null
            return try {
                withContext(activity.dispatchers.default) {
                    if (kind == "key") {
                        PasskeyCredential.generateSshKey(nickname, credentialId, salt, secret)
                    } else {
                        PasskeyCredential.protectPassword(nickname, credentialId, salt, secret, password, args.text("hostname"), args.number("port", 22).toInt(), args.text("username"))
                    }
                }
            } finally {
                secret.fill(0)
            }
        } catch (_: UnsupportedOperationException) {
            throw IllegalStateException(activity.getString(org.connectbot.R.string.flutter_passkey_prf_unavailable))
        } finally {
            password.fill(0)
        }
    }

    suspend fun verifyCredential(credential: PasskeyCredential): Boolean {
        val secret = evaluatePrf(credential.credentialId, credential.salt) ?: return false
        try {
            withContext(activity.dispatchers.default) {
                if (credential.isPassword) {
                    credential.password(secret, credential.hostname, credential.port, credential.username).fill(0)
                } else {
                    credential.sign(secret, "Tilde SSH credential restore".toByteArray(Charsets.UTF_8))
                }
            }
        } finally {
            secret.fill(0)
        }
        return true
    }

    suspend fun signCredential(key: Pubkey, data: ByteArray): Wire {
        val credential = key.protectedCredential()
        require(!credential.isPassword && data.size in 1..16384)
        val secret = evaluatePrf(credential.credentialId, credential.salt) ?: return mapOf("authcancel" to true)
        return try {
            withContext(activity.dispatchers.default) { mapOf("signature" to credential.sign(secret, data)) }
        } finally {
            secret.fill(0)
        }
    }

    suspend fun unlockPassword(key: Pubkey, hostname: String, port: Int, username: String): String? {
        val credential = key.protectedCredential()
        require(credential.matchesTarget(hostname, port, username)) { activity.getString(org.connectbot.R.string.flutter_password_target_mismatch) }
        val secret = evaluatePrf(credential.credentialId, credential.salt) ?: return null
        return try {
            withContext(activity.dispatchers.default) {
                val password = credential.password(secret, hostname, port, username)
                try {
                    password.toString(Charsets.UTF_8)
                } finally {
                    password.fill(0)
                }
            }
        } finally {
            secret.fill(0)
        }
    }

    suspend fun sign(key: Pubkey, data: ByteArray): Wire {
        require(key.isPasskey())
        require(data.isNotEmpty() && data.size <= 16384)
        val options = JSONObject().put("rpId", PASSKEY_RP_ID).put("challenge", passkeyText(data))
            .put("userVerification", "required")
            .put("allowCredentials", JSONArray().put(JSONObject().put("type", "public-key").put("id", key.keystoreAlias)))
        return try {
            val result = withContext(activity.dispatchers.main) {
                CredentialManager.create(activity).getCredential(activity, GetCredentialRequest(listOf(GetPublicKeyCredentialOption(options.toString()))))
            }.credential as PublicKeyCredential
            val credential = JSONObject(result.authenticationResponseJson)
            require(credential.getString("type") == "public-key")
            require(passkeyText(passkeyBytes(credential.getString("rawId"))) == key.keystoreAlias)
            val response = credential.getJSONObject("response")
            mapOf(
                "signature" to passkeyBytes(response.getString("signature")),
                "authenticatorData" to passkeyBytes(response.getString("authenticatorData")),
                "clientDataJSON" to passkeyBytes(response.getString("clientDataJSON")),
            )
        } catch (_: GetCredentialCancellationException) {
            mapOf("authcancel" to true)
        }
    }
}
