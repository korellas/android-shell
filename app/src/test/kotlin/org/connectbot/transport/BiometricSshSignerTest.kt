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
import com.trilead.ssh2.signature.ECDSASHA2Verify
import com.trilead.ssh2.signature.RSASHA256Verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec

@RunWith(RobolectricTestRunner::class)
class BiometricSshSignerTest {
    @Test fun ecSignatureIsSshEncodedAndAuthenticatesEveryChallenge() {
        val pair = KeyPairGenerator.getInstance("EC").apply { initialize(ECGenParameterSpec("secp256r1")) }.generateKeyPair()
        var authentications = 0
        val signer = BiometricSshSigner(pair.public, { algorithm ->
            BiometricPrompt.CryptoObject(Signature.getInstance(algorithm).apply { initSign(pair.private) })
        }, { crypto ->
            assertTrue(crypto.signature != null)
            authentications++
            true
        })
        val verifier = ECDSASHA2Verify.getVerifierForKey(pair.public as ECPublicKey)
        repeat(2) {
            val challenge = "challenge-$it".toByteArray()
            assertTrue(verifier.verifySignature(challenge, signer.sign(challenge, SignatureProxy.SHA256), pair.public))
        }
        assertEquals(2, authentications)
    }

    @Test fun rsaSignatureIsSshEncoded() {
        val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val signer = BiometricSshSigner(pair.public, { algorithm ->
            BiometricPrompt.CryptoObject(Signature.getInstance(algorithm).apply { initSign(pair.private) })
        }, { true })
        val data = "ssh-authentication-challenge".toByteArray()
        assertTrue(RSASHA256Verify.get().verifySignature(data, signer.sign(data, SignatureProxy.SHA256), pair.public))
    }

    @Test(expected = AuthenticationCancelledException::class)
    fun cancelledFingerprintDoesNotSign() {
        val pair = KeyPairGenerator.getInstance("EC").apply { initialize(ECGenParameterSpec("secp256r1")) }.generateKeyPair()
        BiometricSshSigner(pair.public, { algorithm ->
            BiometricPrompt.CryptoObject(Signature.getInstance(algorithm).apply { initSign(pair.private) })
        }, { false }).sign(byteArrayOf(1, 2), SignatureProxy.SHA256)
    }
}
