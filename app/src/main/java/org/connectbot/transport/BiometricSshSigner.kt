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

package org.connectbot.transport

import androidx.biometric.BiometricPrompt
import com.trilead.ssh2.auth.SignatureProxy
import com.trilead.ssh2.crypto.SimpleDERReader
import com.trilead.ssh2.packets.TypesWriter
import com.trilead.ssh2.signature.ECDSASHA2Verify
import java.io.IOException
import java.security.PublicKey
import java.security.interfaces.ECPublicKey
import java.security.interfaces.RSAPublicKey

internal class BiometricSshSigner(
    publicKey: PublicKey,
    private val createCryptoObject: (String) -> BiometricPrompt.CryptoObject,
    private val authenticate: (BiometricPrompt.CryptoObject) -> Boolean,
) : SignatureProxy(publicKey) {
    override fun sign(data: ByteArray, hashAlgorithm: String): ByteArray {
        val digest = when (hashAlgorithm) {
            SHA256 -> "SHA256"
            SHA384 -> "SHA384"
            SHA512 -> "SHA512"
            else -> throw IOException("Unsupported digest for a protected SSH key: $hashAlgorithm")
        }
        val algorithm = when (publicKey) {
            is RSAPublicKey -> "${digest}withRSA"
            is ECPublicKey -> "${digest}withECDSA"
            else -> throw IOException("Unsupported protected SSH key type")
        }
        val crypto = createCryptoObject(algorithm)
        val signature = crypto.signature ?: throw IOException("Missing SSH signing operation")
        if (!authenticate(crypto)) throw AuthenticationCancelledException()
        signature.update(data)
        val raw = signature.sign()
        val encoded = TypesWriter()
        when (val key = publicKey) {
            is RSAPublicKey -> {
                val keyFormat = when (hashAlgorithm) {
                    SHA256 -> "rsa-sha2-256"
                    SHA512 -> "rsa-sha2-512"
                    else -> throw IOException("Unsupported SSH RSA digest")
                }
                encoded.writeString(keyFormat)
                encoded.writeString(raw, 0, raw.size)
            }

            is ECPublicKey -> {
                val sequence = SimpleDERReader(raw)
                val values = SimpleDERReader(sequence.readSequenceAsByteArray())
                if (sequence.available() != 0) throw IOException("Invalid ECDSA signature")
                val components = TypesWriter()
                components.writeMPInt(values.readInt())
                components.writeMPInt(values.readInt())
                if (values.available() != 0) throw IOException("Invalid ECDSA signature")
                val body = components.bytes
                encoded.writeString(ECDSASHA2Verify.getSshKeyType(key))
                encoded.writeString(body, 0, body.size)
            }
        }
        return encoded.bytes
    }
}
