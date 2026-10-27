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

import org.connectbot.data.entity.Pubkey
import org.connectbot.util.Encryptor
import java.security.PublicKey
import java.security.interfaces.ECPublicKey
import java.security.interfaces.RSAPublicKey

internal fun Pubkey.sshKeyMaterial(password: String?): Wire {
    val public = mapOf("id" to id, "type" to type, "publicKey" to publicKey, "biometric" to isBiometric)
    if (isBiometric) return public
    val stored = requireNotNull(privateKey) { "Missing private key" }
    if (type == "IMPORTED") return public + ("pem" to stored.toString(Charsets.UTF_8))
    val clear = if (encrypted) {
        require(!password.isNullOrEmpty()) { "Key password required" }
        require(stored.size > 8) { "Invalid encrypted key" }
        // Matches PubkeyUtils' existing salt-prefixed storage format.
        requireNotNull(Encryptor.decrypt(stored.copyOfRange(0, 8), 1000, password, stored.copyOfRange(8, stored.size)))
    } else {
        stored.copyOf()
    }
    return public + ("privateKey" to clear)
}

internal fun sshSigningAlgorithm(key: PublicKey, algorithm: String): String = when (key) {
    is RSAPublicKey -> when (algorithm) {
        "rsa-sha2-256" -> "SHA256withRSA"
        "rsa-sha2-512" -> "SHA512withRSA"
        else -> error("Unsupported RSA signature algorithm")
    }

    is ECPublicKey -> when (key.params.curve.field.fieldSize) {
        256 -> {
            require(algorithm == "ecdsa-sha2-nistp256")
            "SHA256withECDSA"
        }

        384 -> {
            require(algorithm == "ecdsa-sha2-nistp384")
            "SHA384withECDSA"
        }

        521 -> {
            require(algorithm == "ecdsa-sha2-nistp521")
            "SHA512withECDSA"
        }

        else -> error("Unsupported EC curve")
    }

    else -> error("Unsupported protected key")
}
