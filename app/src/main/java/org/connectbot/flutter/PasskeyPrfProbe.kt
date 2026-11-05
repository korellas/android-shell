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

import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

private const val PRF_PROBE_CONTEXT = "tilde-prf-probe/v1"
private val prfProbeMessage get() = "Tilde passkey PRF probe v1".toByteArray(Charsets.UTF_8)

internal fun parsePrfProbe(text: String): JSONObject {
    require(text.length <= 65536) { "Invalid PRF test file" }
    return try {
        JSONObject(text).also {
            require(it.getString("format") == "tilde-prf-probe" && it.getInt("version") == 1 && it.getString("rpId") == PASSKEY_RP_ID)
            require(probeBytes(it, "credentialId").size in 1..1023)
            require(probeBytes(it, "salt").size == 32)
            require(probeBytes(it, "nonce").size == 12)
            require(probeBytes(it, "ciphertext").size == prfProbeMessage.size + 16)
        }
    } catch (_: Exception) {
        throw IllegalArgumentException("Invalid PRF test file")
    }
}

private fun probeBytes(probe: JSONObject, field: String): ByteArray {
    val text = probe.getString(field)
    return passkeyBytes(text).also { require(passkeyText(it) == text) }
}

internal fun prfProbeSecret(responseJson: String, credentialId: String): ByteArray {
    val credential = try {
        require(responseJson.length <= 65536)
        JSONObject(responseJson)
    } catch (_: Exception) {
        throw IllegalArgumentException("Invalid PRF response")
    }
    val encoded = credential.optJSONObject("clientExtensionResults")?.optJSONObject("prf")?.optJSONObject("results")?.optString("first")
        ?.takeIf { it.isNotEmpty() } ?: throw UnsupportedOperationException("PRF is unavailable")
    return try {
        passkeyBytes(encoded).also {
            if (it.size != 32 || credential.optString("type") != "public-key" || credential.optString("rawId") != credentialId) {
                it.fill(0)
                throw IllegalArgumentException()
            }
        }
    } catch (_: Exception) {
        // Never include the credential response or PRF output in an error.
        throw IllegalArgumentException("Invalid PRF response")
    }
}

private fun prfProbeAad(probe: JSONObject) = "$PRF_PROBE_CONTEXT\n$PASSKEY_RP_ID\n${probe.getString("credentialId")}\n${probe.getString("salt")}".toByteArray(Charsets.UTF_8)

internal fun createPrfProbe(credentialId: String, salt: ByteArray, secret: ByteArray): String {
    var key: ByteArray? = null
    return try {
        key = passkeyEncryptionKey(secret, salt, PRF_PROBE_CONTEXT)
        val nonce = ByteArray(12).also(SecureRandom()::nextBytes)
        val probe = JSONObject().put("format", "tilde-prf-probe").put("version", 1).put("rpId", PASSKEY_RP_ID)
            .put("credentialId", credentialId).put("salt", passkeyText(salt)).put("nonce", passkeyText(nonce))
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        cipher.updateAAD(prfProbeAad(probe))
        probe.put("ciphertext", passkeyText(cipher.doFinal(prfProbeMessage)))
        parsePrfProbe(probe.toString()).toString()
    } finally {
        key?.fill(0)
        secret.fill(0)
    }
}

internal fun verifyPrfProbe(probe: JSONObject, secret: ByteArray) {
    var key: ByteArray? = null
    var plaintext: ByteArray? = null
    try {
        key = passkeyEncryptionKey(secret, probeBytes(probe, "salt"), PRF_PROBE_CONTEXT)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, probeBytes(probe, "nonce")))
        cipher.updateAAD(prfProbeAad(probe))
        plaintext = cipher.doFinal(probeBytes(probe, "ciphertext"))
        require(MessageDigest.isEqual(plaintext, prfProbeMessage)) { "PRF test did not match" }
    } finally {
        plaintext?.fill(0)
        key?.fill(0)
        secret.fill(0)
    }
}
