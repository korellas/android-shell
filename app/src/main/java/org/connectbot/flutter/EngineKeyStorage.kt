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
import android.net.Uri
import kotlinx.coroutines.withContext
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec

internal suspend fun AndroidShellEngine.keyStorageOperation(method: String, args: Wire): Any? {
    check(authenticated) { "App is locked" }
    if (method == "key.storagePick") {
        val uri = args.optionalText("uri")?.let(Uri::parse) ?: activity.pickDocument(arrayOf("*/*")) ?: return null
        return withContext(activity.dispatchers.io) {
            mapOf("text" to requireNotNull(activity.contentResolver.openInputStream(uri)).use { it.readBytes().toString(Charsets.UTF_8) }, "nickname" to (uri.lastPathSegment ?: "Imported key"))
        }
    }
    if (method == "key.storageWrite") {
        val uri = activity.createDocument(args.text("name")) ?: return null
        return withContext(activity.dispatchers.io) {
            requireNotNull(activity.contentResolver.openOutputStream(uri)).use { it.write(args.text("text").toByteArray()) }
            null
        }
    }
    if (method == "key.storageCopy") {
        activity.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("SSH key", args.text("text")))
        return null
    }
    return withContext(activity.dispatchers.io) {
        when (method) {
            "key.storageList" -> keys.getAll().map { it.storageWire() }

            "key.storageMaterial" -> requireNotNull(keys.getById(args.number("id"))).sshKeyMaterial(args.optionalText("password"))

            "key.storageDelete" -> {
                keys.getById(args.number("id"))?.let { key ->
                    key.keystoreAlias?.let { activity.biometricKeys.deleteKey(it) }
                    keys.delete(key)
                }
                changed()
                null
            }

            "key.storageGenerate" -> {
                val type = args.text("type", "ED25519")
                val bits = args.number("bits", if (type == "RSA") 4096 else 256).toInt()
                require(type in setOf("RSA", "EC")) { "Unsupported key generation algorithm" }
                if (args.flag("biometric")) {
                    require(type != "ED25519" && !args.flag("startup"))
                    val alias = activity.biometricKeys.generateKeyAlias()
                    try {
                        val public = activity.biometricKeys.generateKey(alias, type, bits)
                        keys.save(
                            Pubkey(
                                nickname = args.text("nickname"), type = type, privateKey = null, publicKey = public.encoded,
                                encrypted = false, startup = false, confirmation = args.flag("confirmation"), createdDate = System.currentTimeMillis(),
                                storageType = KeyStorageType.ANDROID_KEYSTORE, allowBackup = false, keystoreAlias = alias,
                            ),
                        ).storageWire()
                    } catch (error: Exception) {
                        activity.biometricKeys.deleteKey(alias)
                        throw error
                    }
                } else {
                    val generator = KeyPairGenerator.getInstance(type)
                    when (type) {
                        "RSA" -> {
                            require(bits in 1024..8192 && bits % 8 == 0)
                            generator.initialize(bits)
                        }

                        "EC" -> generator.initialize(
                            ECGenParameterSpec(
                                when (bits) {
                                    256 -> "secp256r1"
                                    384 -> "secp384r1"
                                    521 -> "secp521r1"
                                    else -> error("Unsupported EC size")
                                },
                            ),
                        )
                    }
                    val pair = generator.generateKeyPair()
                    mapOf("privateKey" to pair.private.encoded, "publicKey" to pair.public.encoded)
                }
            }

            "key.storageSave" -> {
                val old = args.optionalId("id")?.let { requireNotNull(keys.getById(it)) }
                val nickname = args.text("nickname", old?.nickname ?: "")
                require(nickname.isNotBlank())
                require(keys.getByNickname(nickname)?.id.let { it == null || it == old?.id }) { "A key with that name already exists" }
                val pem = args.optionalText("pem")
                require(old?.isBiometric != true || pem == null)
                val updated = old?.copy(
                    nickname = nickname,
                    startup = args.flag("startup", old.startup),
                    confirmation = args.flag("confirmation", old.confirmation),
                    allowBackup = !old.isBiometric && args.flag("allowBackup", old.allowBackup),
                    type = if (pem != null) "IMPORTED" else old.type,
                    privateKey = pem?.toByteArray() ?: old.privateKey,
                    publicKey = (args["publicKey"] as? ByteArray) ?: old.publicKey,
                    encrypted = if (pem != null) args.flag("encrypted") else old.encrypted,
                )
                    ?: Pubkey(
                        nickname = nickname,
                        type = "IMPORTED",
                        privateKey = requireNotNull(pem).toByteArray(),
                        publicKey = (args["publicKey"] as? ByteArray) ?: byteArrayOf(),
                        encrypted = args.flag("encrypted"),
                        startup = args.flag("startup"),
                        confirmation = args.flag("confirmation"),
                        createdDate = System.currentTimeMillis(),
                    )
                require(!updated.isBiometric || !updated.startup)
                val saved = keys.save(updated)
                changed()
                saved.storageWire()
            }

            else -> error("Unknown key storage operation: $method")
        }
    }
}

internal fun Pubkey.storageWire(): Wire = mapOf(
    "id" to id, "nickname" to nickname, "type" to type, "encrypted" to encrypted,
    "publicBytes" to publicKey, "startup" to startup, "confirmation" to confirmation,
    "createdDate" to createdDate, "biometric" to isBiometric, "allowBackup" to allowBackup,
)
