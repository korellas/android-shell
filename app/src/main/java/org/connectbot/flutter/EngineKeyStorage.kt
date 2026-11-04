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
import org.connectbot.util.BiometricAvailability
import org.connectbot.util.BiometricKeyManager

internal suspend fun AndroidShellEngine.keyStorageOperation(method: String, args: Wire): Any? {
    check(authenticated) { activity.getString(R.string.flutter_app_locked) }
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
            "key.storageList" -> keys.getAll().map { it.storageWire(manager) }

            "key.storageDelete" -> {
                keys.getById(args.number("id"))?.let { key ->
                    key.keystoreAlias?.let(manager::deleteKey)
                    keys.delete(key)
                }
                changed()
                null
            }

            "key.storageGenerate" -> {
                require(manager.isBiometricAvailable() == BiometricAvailability.AVAILABLE) {
                    activity.getString(R.string.flutter_strong_biometrics_required)
                }
                require(args.text("type", "EC") == "EC" && args.number("bits", 256).toInt() == 256) {
                    activity.getString(R.string.flutter_p256_keys_only)
                }
                val nickname = args.text("nickname").trim()
                require(nickname.isNotEmpty()) { activity.getString(R.string.flutter_key_name_required) }
                require(keys.getByNickname(nickname) == null) { activity.getString(R.string.flutter_duplicate_key_name) }
                val alias = manager.generateKeyAlias()
                try {
                    val public = manager.generateEcKey(alias)
                    keys.save(
                        Pubkey(
                            nickname = nickname,
                            type = "EC",
                            privateKey = null,
                            publicKey = public.encoded,
                            encrypted = false,
                            startup = false,
                            confirmation = false,
                            createdDate = System.currentTimeMillis(),
                            storageType = KeyStorageType.ANDROID_KEYSTORE,
                            allowBackup = false,
                            keystoreAlias = alias,
                        ),
                    ).storageWire(manager)
                } catch (error: Exception) {
                    manager.deleteKey(alias)
                    throw error
                }
            }

            "key.storageSave" -> {
                val old = requireNotNull(keys.getById(args.number("id")))
                val nickname = args.text("nickname", old.nickname).trim()
                require(nickname.isNotEmpty()) { activity.getString(R.string.flutter_key_name_required) }
                require(keys.getByNickname(nickname)?.id.let { it == null || it == old.id }) {
                    activity.getString(R.string.flutter_duplicate_key_name)
                }
                val saved = keys.save(
                    old.copy(
                        nickname = nickname,
                        startup = false,
                        confirmation = args.flag("confirmation", old.confirmation),
                        allowBackup = false,
                    ),
                )
                changed()
                saved.storageWire(manager)
            }

            else -> error("Unknown key storage operation: $method")
        }
    }
}

internal fun Pubkey.storageWire(manager: BiometricKeyManager? = null): Wire {
    val eligible = manager?.let(::isKeystoreSshKeyEligible) ?: false
    return mapOf(
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
        "allowBackup" to false,
    )
}

private fun AndroidShellEngine.requireSshPublicKeyText(text: String) {
    require(text.length in 32..16384 && !text.contains('\n') && !text.contains('\r'))
    require(
        text.startsWith("ecdsa-sha2-nistp256 ") ||
            text.startsWith("ssh-ed25519 ") ||
            text.startsWith("ssh-rsa "),
    ) { activity.getString(R.string.flutter_public_keys_only) }
    require(!text.contains("PRIVATE KEY", ignoreCase = true))
}
