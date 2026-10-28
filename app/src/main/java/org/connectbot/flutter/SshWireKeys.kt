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

import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.connectbot.util.BiometricKeyManager
import java.security.MessageDigest
import java.security.PublicKey
import java.security.interfaces.ECPublicKey

internal fun Pubkey.isKeystoreSshKeyEligible(manager: BiometricKeyManager): Boolean = runCatching {
    if (storageType != KeyStorageType.ANDROID_KEYSTORE || type != "EC" || privateKey != null) return@runCatching false
    val alias = keystoreAlias?.takeIf { it.isNotBlank() } ?: return@runCatching false
    if (!manager.keyExists(alias) || !manager.isAuthPerUse(alias)) return@runCatching false
    val actual = manager.getPublicKey(alias) as? ECPublicKey ?: return@runCatching false
    actual.params.curve.field.fieldSize == 256 && MessageDigest.isEqual(actual.encoded, publicKey)
}.getOrDefault(false)

internal fun Pubkey.sshKeyMaterial(manager: BiometricKeyManager): Wire {
    require(isKeystoreSshKeyEligible(manager)) { "SSH key is not an eligible Android Keystore P-256 key" }
    return mapOf("id" to id, "type" to type, "publicKey" to publicKey, "biometric" to true)
}

internal fun sshSigningAlgorithm(key: PublicKey, algorithm: String): String = when (key) {
    is ECPublicKey -> {
        require(key.params.curve.field.fieldSize == 256 && algorithm == "ecdsa-sha2-nistp256")
        "SHA256withECDSA"
    }

    else -> error("Unsupported protected key")
}
