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

import android.net.Uri
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import org.connectbot.ui.screens.generatepubkey.KeyType
import org.connectbot.util.PubkeyUtils
import java.security.SecureRandom

internal suspend fun AndroidShellEngine.keyOperation(method: String, args: Wire): Any? {
    val list = activity.keyList
    list.clearError()
    return when (method) {
        "key.generate" -> {
            val generate = activity.keyGenerator
            check(!generate.uiState.value.isGenerating) { "키를 생성 중입니다." }
            require(keys.getByNickname(args.text("nickname")) == null) { "같은 이름의 키가 있습니다." }
            generate.updateNickname(args.text("nickname"))
            generate.updateKeyType(KeyType.valueOf(args.text("type", "ED25519")))
            args.optionalId("bits")?.let { generate.updateBits(it.toInt()) }
            generate.updateUseBiometric(args.flag("biometric"))
            generate.updatePassword1(args.text("password"))
            generate.updatePassword2(args.text("password"))
            generate.updateUnlockAtStartup(args.flag("startup"))
            generate.updateConfirmUse(args.flag("confirmation"))
            require(generate.uiState.value.canGenerate) { "키 생성 옵션을 확인하세요." }
            generate.generateKey { changed() }
            if (!args.flag("biometric")) generate.onEntropyGathered(SecureRandom().generateSeed(32))
            generate.uiState.first { !it.isGenerating }
            requireNotNull(keys.getByNickname(args.text("nickname"))) { "키 생성에 실패했습니다." }.toWire(false)
        }

        "key.delete" -> {
            keys.getById(args.number("id"))?.let {
                manager!!.removeKey(it.nickname)
                keys.delete(it)
            }
            changed()
            null
        }

        "key.load" -> {
            val key = requireNotNull(keys.getById(args.number("id")))
            list.toggleKeyLoaded(key) { _, respond -> respond(args.text("password")) }
            null
        }

        "key.biometricUnlock" -> {
            val key = requireNotNull(keys.getById(args.number("id")))
            if (activity.authenticate(key.nickname) != null) list.loadBiometricKey(key) else list.cancelBiometricAuth()
            null
        }

        "key.copy", "key.export" -> {
            val key = requireNotNull(keys.getById(args.number("id")))
            val public = args.text("format", "public") == "public"
            val password: (org.connectbot.data.entity.Pubkey, (String) -> Unit) -> Unit = { _, respond -> respond(args.text("password")) }
            val exportPassword: (org.connectbot.data.entity.Pubkey, (String) -> Unit) -> Unit = { _, respond -> respond(args.text("exportPassword")) }
            require(public || !key.isBiometric) { "생체인증 키의 비밀키는 내보낼 수 없습니다." }
            if (method == "key.copy") {
                when (args.text("format", "public")) {
                    "public" -> list.copyPublicKey(key)

                    "pem" -> list.copyPrivateKeyPem(key, password)

                    "encrypted" -> {
                        require(args.text("exportPassword").isNotEmpty())
                        list.copyPrivateKeyEncrypted(key, password, exportPassword)
                    }

                    "openssh" -> list.copyPrivateKeyOpenSSH(key, password)

                    else -> error("지원하지 않는 키 형식입니다.")
                }
            } else {
                when (args.text("format", "public")) {
                    "public" -> list.requestExportPublicKey(key)

                    "pem" -> list.requestExportPrivateKeyPem(key, password)

                    "encrypted" -> {
                        require(args.text("exportPassword").isNotEmpty())
                        list.requestExportPrivateKeyEncrypted(key, password, exportPassword)
                    }

                    "openssh" -> list.requestExportPrivateKeyOpenSSH(key, password)

                    else -> error("지원하지 않는 키 형식입니다.")
                }
                val uri = activity.createDocument(if (public) list.getPublicKeyExportFilename() else list.getExportFilename())
                if (uri != null) {
                    if (public) list.exportPublicKeyToUri(uri) else list.exportKeyToUri(uri)
                } else {
                    list.cancelExport()
                    list.cancelPublicKeyExport()
                }
            }
            null
        }

        "key.import" -> {
            val text = args.optionalText("text")
            if (text != null) {
                list.importKeyFromText(text, args.text("nickname"))
            } else {
                val uri = args.optionalText("uri")?.let { Uri.parse(it) } ?: activity.pickDocument(arrayOf("*/*"))
                if (uri != null) list.importKeyFromUri(uri)
            }
            null
        }

        "key.importPassword" -> {
            list.completeImportWithPassword(args.text("nickname"), args.text("password"), args.flag("encrypt"), args.optionalText("encryptPassword"))
            null
        }

        "key.importName" -> {
            list.confirmImportNickname(args.text("nickname"))
            null
        }

        "key.importCancel" -> {
            list.cancelImport()
            list.cancelImportNickname()
            null
        }

        "key.save" -> {
            val key = requireNotNull(keys.getById(args.number("id")))
            var updated = key.copy(nickname = args.text("nickname", key.nickname), startup = args.flag("startup", key.startup), confirmation = args.flag("confirmation", key.confirmation), allowBackup = !key.isBiometric && args.flag("allowBackup", key.allowBackup))
            require(updated.nickname.isNotBlank())
            if (args.containsKey("newPassword")) {
                require(!key.isBiometric && key.type != "IMPORTED") { "이 키의 암호는 원본 키 파일에서 변경하세요." }
                updated = withContext(activity.dispatchers.io) {
                    val private = requireNotNull(PubkeyUtils.decodePrivate(requireNotNull(key.privateKey), key.type, args.optionalText("oldPassword")))
                    updated.copy(privateKey = PubkeyUtils.getEncodedPrivate(private, args.text("newPassword")), encrypted = args.text("newPassword").isNotEmpty())
                }
            }
            require(!updated.isBiometric || !updated.startup)
            require(!updated.encrypted || !updated.startup) { "암호화된 키는 시작할 때 자동 해제할 수 없습니다." }
            manager!!.removeKey(key.nickname)
            keys.save(updated)
            changed()
            null
        }

        "key.enrollmentBegin" -> {
            activity.enrollment.begin(args.text("name"))
            changed()
            null
        }

        "key.enroll" -> {
            activity.enrollment.selectKey(args.optionalId("keyId"))
            activity.enrollment.updateName(args.text("name"))
            require(activity.enrollment.uiState.value.canSubmit) { "등록할 키를 확인하세요." }
            activity.enrollment.enroll(bridge(args.number("sessionId")))
            null
        }

        "key.startup" -> {
            val key = requireNotNull(keys.getById(args.number("id")))
            if (args.flag("cancel")) manager!!.dismissPendingStartupKey(key) else check(manager!!.unlockPendingStartupKey(key, args.text("password"))) { "키 암호를 확인하세요." }
            changed()
            null
        }

        else -> error("지원하지 않는 키 작업입니다.")
    }
}
