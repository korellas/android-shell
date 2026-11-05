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

import android.content.ClipData
import android.content.ClipboardManager
import kotlinx.coroutines.withContext
import org.connectbot.R
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.connectbot.util.BiometricKeyManager

internal suspend fun AndroidShellEngine.keyStorageOperation(method: String, args: Wire): Any? {
    check(authenticated) { activity.getString(R.string.flutter_app_locked) }
    if (method == "key.storageGenerateProtectedPasskey" || method == "key.storageRestoreProtectedPasskey") {
        if (method == "key.storageGenerateProtectedPasskey") {
            val nickname = args.text("nickname").trim()
            require(nickname.isNotEmpty()) { activity.getString(R.string.flutter_key_name_required) }
            require(withContext(activity.dispatchers.io) { keys.getByNickname(nickname) } == null) { activity.getString(R.string.flutter_duplicate_key_name) }
        }
        val credential = if (method == "key.storageGenerateProtectedPasskey") {
            activity.passkeys.generateCredential(args) ?: return null
        } else {
            withContext(activity.dispatchers.default) { PasskeyCredential.parse(args.text("text")) }.also {
                if (!activity.passkeys.verifyCredential(it)) return null
            }
        }
        return saveProtectedCredential(credential)
    }
    if (method == "key.storageExportProtectedPasskey") {
        val text = withContext(activity.dispatchers.io) {
            val key = requireNotNull(keys.getById(args.number("id")))
            key.protectedCredential().backupWithName(key.nickname)
        }
        val uri = activity.createDocument("tilde-passkey-credential.json") ?: return null
        withContext(activity.dispatchers.io) {
            requireNotNull(activity.contentResolver.openOutputStream(uri)).use { it.write(text.toByteArray(Charsets.UTF_8)) }
        }
        return null
    }
    if (method == "key.storageCreatePasskey") return activity.passkeys.create(args.text("requestJson"))
    if (method == "key.storagePrfProbeCreate" || method == "key.storagePrfProbeVerify") {
        return try {
            if (method == "key.storagePrfProbeCreate") {
                val text = activity.passkeys.createPrfProbe() ?: return null
                val uri = activity.createDocument("tilde-prf-probe.json") ?: return null
                withContext(activity.dispatchers.io) {
                    requireNotNull(activity.contentResolver.openOutputStream(uri)).use { it.write(text.toByteArray(Charsets.UTF_8)) }
                }
                mapOf("status" to "saved")
            } else {
                val text = readPasskeyDocument() ?: return null
                if (activity.passkeys.verifyPrfProbe(text)) mapOf("status" to "verified") else null
            }
        } catch (_: UnsupportedOperationException) {
            mapOf("status" to "unsupported")
        } catch (_: javax.crypto.AEADBadTagException) {
            mapOf("status" to "mismatch")
        }
    }
    if (method == "key.storageReadPasskey") return readPasskeyDocument()
    if (method == "key.storageWritePasskey") {
        val uri = activity.createDocument("tilde-passkey.json") ?: return null
        return withContext(activity.dispatchers.io) {
            requireNotNull(activity.contentResolver.openOutputStream(uri)).use { it.write(args.text("text").toByteArray()) }
            null
        }
    }
    if (method == "key.storageWrite" || method == "key.storageCopy") {
        val text = args.text("text").also { requireSshPublicKeyText(it) }
        if (method == "key.storageCopy") {
            activity.getSystemService(ClipboardManager::class.java)
                .setPrimaryClip(ClipData.newPlainText(activity.getString(R.string.flutter_public_key_label), text))
            return null
        }
        val name = args.text("name").takeIf { it.endsWith(".pub") && !it.contains('/') && !it.contains('\\') }
            ?: "id_ecdsa.pub"
        val uri = activity.createDocument(name) ?: return null
        return withContext(activity.dispatchers.io) {
            requireNotNull(activity.contentResolver.openOutputStream(uri)).use {
                it.write((text + "\n").toByteArray())
            }
            null
        }
    }
    return withContext(activity.dispatchers.io) {
        val manager = activity.biometricKeys
        when (method) {
            "key.storageSavePasskey" -> {
                require(args.text("rpId") == PASSKEY_RP_ID)
                val public = requireNotNull(args["publicKey"] as? ByteArray)
                require(validPasskeyPublicKey(public))
                val credentialId = args.text("credentialId")
                require(passkeyBytes(credentialId).size in 1..1023 && passkeyText(passkeyBytes(credentialId)) == credentialId)
                val existing = keys.getAll().firstOrNull { it.isPasskey() && it.keystoreAlias == credentialId }
                if (existing != null) {
                    require(java.security.MessageDigest.isEqual(existing.publicKey, public)) { "Passkey public key mismatch" }
                    return@withContext existing.storageWire(manager)
                }
                val nickname = args.text("nickname").trim()
                require(nickname.isNotEmpty()) { activity.getString(R.string.flutter_key_name_required) }
                require(keys.getByNickname(nickname) == null) { activity.getString(R.string.flutter_duplicate_key_name) }
                val saved = keys.save(
                    Pubkey(
                        nickname = nickname, type = PASSKEY_TYPE, privateKey = null, publicKey = public,
                        encrypted = false, startup = false, confirmation = false, createdDate = System.currentTimeMillis(),
                        storageType = KeyStorageType.PASSKEY, allowBackup = true, keystoreAlias = credentialId,
                    ),
                )
                withContext(activity.dispatchers.main) { changed() }
                saved.storageWire(manager)
            }

            "key.storageList" -> keys.getAll().map { it.storageWire(manager) }

            "key.storageDelete" -> {
                keys.getById(args.number("id"))?.let { key ->
                    if (key.storageType == KeyStorageType.ANDROID_KEYSTORE) key.keystoreAlias?.let(manager::deleteKey)
                    keys.delete(key)
                }
                withContext(activity.dispatchers.main) { changed() }
                null
            }

            "key.storageSave" -> {
                val old = requireNotNull(keys.getById(args.number("id")))
                val nickname = args.text("nickname", old.nickname).trim()
                require(nickname.isNotEmpty()) { activity.getString(R.string.flutter_key_name_required) }
                if (old.isWrappedPasskey() || old.isPasskeyPassword()) {
                    require(nickname.length <= 256) { activity.getString(R.string.flutter_key_name_required) }
                }
                require(keys.getByNickname(nickname)?.id.let { it == null || it == old.id }) {
                    activity.getString(R.string.flutter_duplicate_key_name)
                }
                val saved = keys.save(
                    old.copy(
                        nickname = nickname,
                        startup = false,
                        confirmation = args.flag("confirmation", old.confirmation),
                        allowBackup = old.isPasskey() || old.isWrappedPasskey() || old.isPasskeyPassword(),
                    ),
                )
                withContext(activity.dispatchers.main) { changed() }
                saved.storageWire(manager)
            }

            else -> error("Unknown key storage operation: $method")
        }
    }
}

private suspend fun AndroidShellEngine.saveProtectedCredential(credential: PasskeyCredential): Wire {
    val saved = withContext(activity.dispatchers.io) {
        val type = if (credential.isPassword) PASSKEY_PASSWORD_TYPE else PASSKEY_WRAPPED_TYPE
        val existing = keys.getAll().firstOrNull { it.type == type && it.keystoreAlias == credential.credentialId }
        if (existing != null) {
            require(existing.isWrappedPasskey() || existing.isPasskeyPassword())
            require(java.security.MessageDigest.isEqual(existing.publicKey, credential.publicKey)) { "SSH public key mismatch" }
            if (credential.isPassword) require(existing.protectedCredential().matchesTarget(credential.hostname, credential.port, credential.username))
            existing
        } else {
            require(keys.getByNickname(credential.nickname) == null) { activity.getString(R.string.flutter_duplicate_key_name) }
            keys.save(
                Pubkey(
                    nickname = credential.nickname, type = type, privateKey = credential.backup.toByteArray(Charsets.UTF_8),
                    publicKey = credential.publicKey, encrypted = true, startup = false, confirmation = false, createdDate = System.currentTimeMillis(),
                    storageType = KeyStorageType.PASSKEY, allowBackup = true, keystoreAlias = credential.credentialId,
                ),
            )
        }
    }
    withContext(activity.dispatchers.main) { changed() }
    return saved.storageWire(activity.biometricKeys)
}

private suspend fun AndroidShellEngine.readPasskeyDocument(): String? {
    val uri = activity.pickDocument(arrayOf("application/json", "text/plain", "application/octet-stream")) ?: return null
    return withContext(activity.dispatchers.io) {
        requireNotNull(activity.contentResolver.openInputStream(uri)).use {
            val bytes = ByteArray(65537)
            var size = 0
            while (size < bytes.size) {
                val count = it.read(bytes, size, bytes.size - size)
                if (count < 0) break
                size += count
            }
            require(size <= 65536) { "Passkey metadata is too large" }
            String(bytes, 0, size, Charsets.UTF_8)
        }
    }
}

internal fun Pubkey.storageWire(manager: BiometricKeyManager? = null): Wire {
    val passkey = isPasskey()
    val wrapped = isWrappedPasskey()
    val password = isPasskeyPassword()
    val eligible = passkey || wrapped || password || (manager?.let(::isKeystoreSshKeyEligible) ?: false)
    return mapOf(
        "passkey" to passkey,
        "passkeyWrapped" to wrapped,
        "passkeyPassword" to password,
        "deprecated" to !(wrapped || password),
        "rpId" to if (passkey) PASSKEY_RP_ID else null,
        "credentialId" to if (passkey) keystoreAlias else null,
        "providerLabel" to if (passkey || wrapped || password) "Passkey" else "Android Keystore",
        "id" to id,
        "nickname" to nickname,
        "type" to type,
        "encrypted" to encrypted,
        "publicBytes" to publicKey,
        "startup" to false,
        "confirmation" to confirmation,
        "createdDate" to createdDate,
        "biometric" to isBiometric,
        "eligible" to eligible,
        "allowBackup" to (passkey || wrapped || password),
    )
}

private fun AndroidShellEngine.requireSshPublicKeyText(text: String) {
    require(text.length in 32..16384 && !text.contains('\n') && !text.contains('\r'))
    require(
        text.startsWith("sk-ecdsa-sha2-nistp256@openssh.com ") ||
            text.startsWith("ecdsa-sha2-nistp256 ") ||
            text.startsWith("ssh-ed25519 ") ||
            text.startsWith("ssh-rsa "),
    ) { activity.getString(R.string.flutter_public_keys_only) }
    require(!text.contains("PRIVATE KEY", ignoreCase = true))
}
