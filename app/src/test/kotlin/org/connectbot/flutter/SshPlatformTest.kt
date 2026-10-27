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

import androidx.biometric.BiometricPrompt
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.KnownHost
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.BiometricKeyManager
import org.connectbot.util.Encryptor
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import java.nio.charset.UnmappableCharacterException
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec

@RunWith(RobolectricTestRunner::class)
class SshPlatformTest {
    @Test
    fun existingSaltPrefixedKeyDecryptsWithoutReencodingOrChangingStorage() {
        val original = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair().private.encoded
        val salt = ByteArray(8)
        val encrypted = salt.let {
            val ciphertext = requireNotNull(Encryptor.encrypt(it, 1000, "key password", original))
            it + ciphertext
        }
        val key = key(encrypted, encrypted = true)
        assertArrayEquals(original, key.sshKeyMaterial("key password")["privateKey"] as ByteArray)
        assertArrayEquals(encrypted, key.privateKey)
        assertThrows(IllegalArgumentException::class.java) { key.sshKeyMaterial(null) }
        assertThrows(Exception::class.java) { key.sshKeyMaterial("incorrect password") }
    }

    @Test
    fun protectedMaterialNeverExposesPrivateBytesEvenIfDatabaseContainsThem() {
        val material = key(byteArrayOf(1, 2, 3)).copy(storageType = KeyStorageType.ANDROID_KEYSTORE).sshKeyMaterial(null)
        assertEquals(true, material["biometric"])
        assertFalse(material.containsKey("privateKey"))
        assertFalse(material.containsKey("pem"))
        assertArrayEquals(byteArrayOf(4), material["publicKey"] as ByteArray)
    }

    @Test
    fun importedPemRemainsOriginalAndSoftwareMaterialIsACopy() {
        val pem = "-----BEGIN OPENSSH PRIVATE KEY-----\noriginal bytes\n"
        assertEquals(pem, key(pem.toByteArray()).copy(type = "IMPORTED").sshKeyMaterial(null)["pem"])
        val original = byteArrayOf(1, 2)
        val material = key(original).sshKeyMaterial(null)["privateKey"] as ByteArray
        material[0] = 9
        assertArrayEquals(byteArrayOf(1, 2), original)
    }

    @Test
    fun protectedSigningAllowsOnlyMatchingSha2Algorithms() {
        val rsa = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair().public
        assertEquals("SHA256withRSA", sshSigningAlgorithm(rsa, "rsa-sha2-256"))
        assertEquals("SHA512withRSA", sshSigningAlgorithm(rsa, "rsa-sha2-512"))
        assertThrows(IllegalStateException::class.java) { sshSigningAlgorithm(rsa, "ssh-rsa") }
        for ((curve, wire, jca) in listOf(
            Triple("secp256r1", "ecdsa-sha2-nistp256", "SHA256withECDSA"),
            Triple("secp384r1", "ecdsa-sha2-nistp384", "SHA384withECDSA"),
            Triple("secp521r1", "ecdsa-sha2-nistp521", "SHA512withECDSA"),
        )) {
            val ec = KeyPairGenerator.getInstance("EC").apply { initialize(ECGenParameterSpec(curve)) }.generateKeyPair().public
            assertEquals(jca, sshSigningAlgorithm(ec, wire))
            assertThrows(IllegalArgumentException::class.java) { sshSigningAlgorithm(ec, "rsa-sha2-256") }
        }
    }

    @Test
    fun hostTrustComparesExistingRawBytesAndExplicitFingerprintsWithoutConfusingStorage() {
        val original = KnownHost(hostId = 1, hostname = "server", port = 22, hostKeyAlgo = "ssh-ed25519", hostKey = byteArrayOf(1, 2, 3))
        val fingerprint = original.sshFingerprint()
        assertEquals("match", sshTrustStatus(listOf(original), "ssh-ed25519", fingerprint))
        val rsa = original.copy(hostKeyAlgo = "ssh-rsa")
        assertEquals("match", sshTrustStatus(listOf(rsa), "rsa-sha2-512", fingerprint))
        assertEquals("match", sshTrustStatus(listOf(rsa.copy(hostKeyAlgo = "rsa-sha2-256")), "rsa-sha2-512", fingerprint))
        val explicit = original.copy(hostKey = byteArrayOf(), sha256Fingerprint = fingerprint)
        assertEquals("match", sshTrustStatus(listOf(explicit), "ssh-ed25519", fingerprint))
        assertEquals("changed", sshTrustStatus(listOf(explicit), "ssh-rsa", fingerprint))
        assertEquals("new", sshTrustStatus(emptyList(), "ssh-rsa", fingerprint))
        assertEquals(fingerprint, normalizeSshFingerprint(fingerprint.removePrefix("SHA256:") + "="))
        assertThrows(IllegalArgumentException::class.java) { normalizeSshFingerprint("MD5:aa:bb") }
        assertArrayEquals(byteArrayOf(1, 2, 3), original.hostKey)
        assertTrue(explicit.hostKey.isEmpty())
    }

    @Test
    fun streamingDecoderPreservesSplitUtf8AndLegacyMultibyteSequences() {
        for (encoding in listOf("UTF-8", "EUC-KR", "Shift_JIS")) {
            val text = if (encoding == "Shift_JIS") "日本語" else "한글"
            val bytes = text.toByteArray(charset(encoding))
            val codecs = SshCodecs()
            val decoded = StringBuilder()
            for ((index, byte) in bytes.withIndex()) {
                decoded.append(codecs.operation("ssh.decode", mapOf("sessionId" to "test", "encoding" to encoding, "bytes" to byteArrayOf(byte), "final" to (index == bytes.lastIndex))))
            }
            assertEquals(text, decoded.toString())
            codecs.operation("ssh.closeCodec", mapOf("sessionId" to "test"))
        }
    }

    @Test
    fun encoderRetainsSplitSurrogatesAndRejectsLossyMapping() {
        val codecs = SshCodecs()
        fun encode(text: String, final: Boolean) = codecs.operation("ssh.encode", mapOf("sessionId" to "emoji", "encoding" to "UTF-8", "text" to text, "final" to final)) as ByteArray
        assertTrue(encode("\uD83D", false).isEmpty())
        assertArrayEquals("😀".toByteArray(), encode("\uDE00", true))
        assertThrows(UnmappableCharacterException::class.java) {
            codecs.operation("ssh.encode", mapOf("sessionId" to "ascii", "encoding" to "US-ASCII", "text" to "한", "final" to true))
        }
        assertThrows(IllegalArgumentException::class.java) {
            codecs.operation("ssh.decode", mapOf("sessionId" to "emoji", "encoding" to "US-ASCII", "bytes" to byteArrayOf()))
        }
    }

    @Test
    fun codecIdsAreBoundedAndExplicitCloseReleasesCapacity() {
        val codecs = SshCodecs()
        for (id in 0 until 128) codecs.operation("ssh.decode", mapOf("sessionId" to "$id", "encoding" to "UTF-8", "bytes" to byteArrayOf()))
        assertThrows(IllegalArgumentException::class.java) {
            codecs.operation("ssh.decode", mapOf("sessionId" to "overflow", "encoding" to "UTF-8", "bytes" to byteArrayOf()))
        }
        codecs.operation("ssh.closeCodec", mapOf("sessionId" to "0"))
        assertEquals("ok", codecs.operation("ssh.decode", mapOf("sessionId" to "overflow", "encoding" to "UTF-8", "bytes" to "ok".toByteArray())))
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun biometricCancellationDoesNotSignAndAuthorizedCallbackUsesExactOperation() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        val activity = mock(FlutterShellActivity::class.java)
        val engine = mock(AndroidShellEngine::class.java)
        val repository = mock(PubkeyRepository::class.java)
        val biometrics = mock(BiometricKeyManager::class.java)
        val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val signature = Signature.getInstance("SHA256withRSA").apply { initSign(pair.private) }
        val crypto = BiometricPrompt.CryptoObject(signature)
        val key = key(byteArrayOf()).copy(id = 9, storageType = KeyStorageType.ANDROID_KEYSTORE, keystoreAlias = "device-key")
        `when`(engine.authenticated).thenReturn(true)
        `when`(engine.activity).thenReturn(activity)
        `when`(engine.keys).thenReturn(repository)
        `when`(activity.dispatchers).thenReturn(CoroutineDispatchers(dispatcher, dispatcher, dispatcher))
        `when`(activity.biometricKeys).thenReturn(biometrics)
        `when`(repository.getById(9)).thenReturn(key)
        `when`(biometrics.getPublicKey("device-key")).thenReturn(pair.public)
        `when`(biometrics.getCryptoObject("device-key", "SHA256withRSA")).thenReturn(crypto)
        `when`(activity.authenticate(key.nickname, crypto)).thenReturn(null)
        val data = byteArrayOf(1, 2, 3)
        val args = mapOf("id" to 9L, "algorithm" to "rsa-sha2-256", "data" to data)
        assertEquals(mapOf("authcancel" to true), engine.sshPlatformOperation("ssh.sign", args))
        assertFalse(mockingDetails(biometrics).invocations.any { it.method.name == "sign" })
        val result = mock(BiometricPrompt.AuthenticationResult::class.java)
        `when`(result.cryptoObject).thenReturn(crypto)
        `when`(activity.authenticate(key.nickname, crypto)).thenReturn(result)
        `when`(biometrics.sign(signature, data)).thenReturn(byteArrayOf(7, 8))
        val reply = engine.sshPlatformOperation("ssh.sign", args) as Map<*, *>
        assertArrayEquals(byteArrayOf(7, 8), reply["signature"] as ByteArray)
        assertEquals(1, mockingDetails(biometrics).invocations.count { it.method.name == "sign" })
    }

    private fun key(private: ByteArray, encrypted: Boolean = false) = Pubkey(
        nickname = "test",
        type = "RSA",
        privateKey = private,
        publicKey = byteArrayOf(4),
        encrypted = encrypted,
        startup = false,
        confirmation = false,
        createdDate = 0,
    )
}
