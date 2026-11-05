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

import android.os.Build
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.json.JSONObject
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

internal const val PASSKEY_WRAPPED_TYPE = "PASSKEY_SSH"
internal const val PASSKEY_PASSWORD_TYPE = "PASSKEY_PASSWORD"
private const val CREDENTIAL_CONTEXT = "tilde-passkey-credential/v1"

internal fun passkeyEncryptionKey(secret: ByteArray, salt: ByteArray, context: String): ByteArray {
    require(secret.size == 32 && salt.size == 32)
    val mac = Mac.getInstance("HmacSHA256")
    mac.init(SecretKeySpec(salt, "HmacSHA256"))
    val extracted = mac.doFinal(secret)
    return try {
        mac.init(SecretKeySpec(extracted, "HmacSHA256"))
        mac.doFinal(context.toByteArray(Charsets.UTF_8) + byteArrayOf(1))
    } finally {
        extracted.fill(0)
    }
}

private fun normalizedPasswordHost(hostname: String) = hostname.trim().lowercase(Locale.ROOT).removeSuffix(".")
private fun destroyPrivateKey(key: PrivateKey?) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) runCatching { key?.destroy() }
}

internal class PasskeyCredential private constructor(private val envelope: JSONObject) {
    val backup: String get() = envelope.toString()
    val nickname: String get() = envelope.getString("nickname")
    val credentialId: String get() = envelope.getString("credentialId")
    val salt: ByteArray get() = bytes("salt")
    val isPassword: Boolean get() = envelope.getString("kind") == "password"
    val publicKey: ByteArray get() = if (isPassword) byteArrayOf() else bytes("publicKey")
    val hostname: String get() = if (isPassword) envelope.getString("hostname") else ""
    val port: Int get() = if (isPassword) envelope.getInt("port") else 0
    val username: String get() = if (isPassword) envelope.getString("username") else ""

    fun backupWithName(name: String): String = JSONObject(backup).put("nickname", name).toString()
    private fun bytes(field: String): ByteArray {
        val encoded = envelope.getString(field)
        return passkeyBytes(encoded).also { require(passkeyText(it) == encoded) }
    }
    private fun aad(): ByteArray = listOf(
        CREDENTIAL_CONTEXT, envelope.getString("kind"), PASSKEY_RP_ID, credentialId,
        envelope.getString("salt"), if (isPassword) "" else envelope.getString("publicKey"),
        hostname, port.toString(), username,
    ).joinToString("\n").toByteArray(Charsets.UTF_8)

    private fun crypt(mode: Int, secret: ByteArray, input: ByteArray): ByteArray {
        val key = passkeyEncryptionKey(secret, salt, "$CREDENTIAL_CONTEXT/${envelope.getString("kind")}")
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(128, bytes("nonce")))
            cipher.updateAAD(aad())
            cipher.doFinal(input)
        } finally {
            key.fill(0)
        }
    }

    fun sign(secret: ByteArray, data: ByteArray): ByteArray {
        var encoded: ByteArray? = null
        var privateKey: PrivateKey? = null
        return try {
            require(!isPassword && data.size in 1..16384)
            encoded = crypt(Cipher.DECRYPT_MODE, secret, bytes("ciphertext"))
            privateKey = KeyFactory.getInstance("EC").generatePrivate(PKCS8EncodedKeySpec(encoded))
            val signature = Signature.getInstance("SHA256withECDSA").run {
                initSign(privateKey)
                update(data)
                sign()
            }
            val public = KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(publicKey))
            require(
                Signature.getInstance("SHA256withECDSA").run {
                    initVerify(public)
                    update(data)
                    verify(signature)
                },
            ) { "SSH public key mismatch" }
            signature
        } finally {
            encoded?.fill(0)
            destroyPrivateKey(privateKey)
            secret.fill(0)
        }
    }

    fun matchesTarget(host: String, targetPort: Int, user: String): Boolean = isPassword && hostname == normalizedPasswordHost(host) && port == targetPort && username == user

    fun password(secret: ByteArray, host: String, targetPort: Int, user: String): ByteArray = try {
        require(matchesTarget(host, targetPort, user)) { "Password belongs to a different server or account" }
        crypt(Cipher.DECRYPT_MODE, secret, bytes("ciphertext"))
    } finally {
        secret.fill(0)
    }

    companion object {
        fun parse(text: String): PasskeyCredential {
            require(text.length <= 65536) { "Invalid encrypted credential file" }
            return try {
                val json = JSONObject(text)
                require(json.getString("format") == "tilde-passkey-credential" && json.get("version") == 1 && json.getString("rpId") == PASSKEY_RP_ID)
                require(json.getString("nickname").trim().isNotEmpty() && json.getString("nickname").length <= 256)
                val key = PasskeyCredential(json)
                require(json.getString("kind") in listOf("key", "password"))
                val fields = setOf("format", "version", "rpId", "nickname", "credentialId", "salt", "nonce", "ciphertext", "kind") +
                    if (key.isPassword) setOf("hostname", "port", "username") else setOf("algorithm", "publicKey")
                require(json.keys().asSequence().toSet() == fields)
                require(key.bytes("credentialId").size in 1..1023 && key.salt.size == 32 && key.bytes("nonce").size == 12)
                require(key.bytes("ciphertext").size in 17..16400)
                if (key.isPassword) {
                    require(key.hostname.isNotEmpty() && key.hostname == normalizedPasswordHost(key.hostname) && key.hostname.none { it.isWhitespace() || it == '\u0000' })
                    require(key.port in 1..65535 && key.username.isNotEmpty() && key.username.none { it == '\n' || it == '\r' || it == '\u0000' })
                    require(!json.has("publicKey") && !json.has("algorithm"))
                } else {
                    require(json.getString("algorithm") == "ecdsa-sha2-nistp256")
                    require(key.publicKey.size == 91 && validPasskeyPublicKey(key.publicKey))
                    require(key.bytes("ciphertext").size in 64..1024)
                    require(!json.has("hostname") && !json.has("port") && !json.has("username"))
                }
                key
            } catch (_: Exception) {
                throw IllegalArgumentException("Invalid encrypted credential file")
            }
        }

        private fun seal(nickname: String, id: String, salt: ByteArray, secret: ByteArray, payload: ByteArray, metadata: JSONObject): PasskeyCredential = try {
            metadata.put("format", "tilde-passkey-credential").put("version", 1).put("rpId", PASSKEY_RP_ID)
                .put("nickname", nickname).put("credentialId", id).put("salt", passkeyText(salt))
                .put("nonce", passkeyText(ByteArray(12).also(SecureRandom()::nextBytes)))
            val key = PasskeyCredential(metadata)
            metadata.put("ciphertext", passkeyText(key.crypt(Cipher.ENCRYPT_MODE, secret, payload)))
            parse(metadata.toString())
        } finally {
            payload.fill(0)
            secret.fill(0)
        }

        fun generateSshKey(nickname: String, id: String, salt: ByteArray, secret: ByteArray): PasskeyCredential {
            var privateKey: PrivateKey? = null
            return try {
                val pair = KeyPairGenerator.getInstance("EC").apply { initialize(ECGenParameterSpec("secp256r1")) }.generateKeyPair()
                privateKey = pair.private
                seal(nickname, id, salt, secret, pair.private.encoded, JSONObject().put("kind", "key").put("algorithm", "ecdsa-sha2-nistp256").put("publicKey", passkeyText(pair.public.encoded)))
            } finally {
                destroyPrivateKey(privateKey)
                secret.fill(0)
            }
        }

        fun protectPassword(nickname: String, id: String, salt: ByteArray, secret: ByteArray, password: ByteArray, hostname: String, port: Int, username: String): PasskeyCredential = try {
            require(password.size in 1..16384) { "Invalid password length" }
            seal(nickname, id, salt, secret, password, JSONObject().put("kind", "password").put("hostname", normalizedPasswordHost(hostname)).put("port", port).put("username", username))
        } finally {
            password.fill(0)
            secret.fill(0)
        }
    }
}

internal fun Pubkey.protectedCredential(): PasskeyCredential {
    require(storageType == KeyStorageType.PASSKEY && encrypted && type in listOf(PASSKEY_WRAPPED_TYPE, PASSKEY_PASSWORD_TYPE))
    val blob = requireNotNull(privateKey)
    require(blob.size <= 65536)
    return PasskeyCredential.parse(blob.toString(Charsets.UTF_8)).also {
        require(it.isPassword == (type == PASSKEY_PASSWORD_TYPE) && it.credentialId == keystoreAlias && MessageDigest.isEqual(it.publicKey, publicKey))
    }
}
internal fun Pubkey.isWrappedPasskey(): Boolean = type == PASSKEY_WRAPPED_TYPE && runCatching {
    protectedCredential()
    true
}.getOrDefault(false)
internal fun Pubkey.isPasskeyPassword(): Boolean = type == PASSKEY_PASSWORD_TYPE && runCatching {
    protectedCredential()
    true
}.getOrDefault(false)
