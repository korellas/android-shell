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
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

@RunWith(RobolectricTestRunner::class)
class PasskeyCredentialTest {
    private fun generate() = PasskeyCredential.generateSshKey("work", "AQID", ByteArray(32) { 4 }, ByteArray(32) { 7 })

    @Test
    fun portableEncryptedBackupRestoresSameStandardSshSigner() {
        val secret = ByteArray(32) { 7 }
        val original = PasskeyCredential.generateSshKey("work", "AQID", ByteArray(32) { 4 }, secret)
        assertArrayEquals(ByteArray(32), secret)
        val restored = PasskeyCredential.parse(original.backup)
        val data = "SSH authentication challenge".toByteArray()
        val unlocking = ByteArray(32) { 7 }
        val signature = restored.sign(unlocking, data)
        assertArrayEquals(ByteArray(32), unlocking)
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(original.publicKey)))
        verifier.update(data)
        assertTrue(verifier.verify(signature))
        assertFalse(original.backup.contains(passkeyText(ByteArray(32) { 7 })))
        assertFalse(JSONObject(original.backup).has("privateKey"))
    }

    @Test
    fun wrongPrfAndTamperingFailWithoutKeepingAnUnlockedKey() {
        val key = generate()
        key.sign(ByteArray(32) { 7 }, byteArrayOf(1))
        val wrong = ByteArray(32) { 8 }
        assertThrows(Exception::class.java) { key.sign(wrong, byteArrayOf(1)) }
        assertArrayEquals(ByteArray(32), wrong)
        for (field in listOf("credentialId", "salt", "nonce", "ciphertext")) {
            val envelope = JSONObject(key.backup)
            val value = passkeyBytes(envelope.getString(field))
            value[0] = (value[0].toInt() xor 1).toByte()
            envelope.put(field, passkeyText(value))
            val secret = ByteArray(32) { 7 }
            assertThrows(Exception::class.java) { PasskeyCredential.parse(envelope.toString()).sign(secret, byteArrayOf(1)) }
            assertArrayEquals(ByteArray(32), secret)
        }
        val replaced = JSONObject(key.backup).put("publicKey", passkeyText(generate().publicKey))
        assertThrows(Exception::class.java) { PasskeyCredential.parse(replaced.toString()).sign(ByteArray(32) { 7 }, byteArrayOf(1)) }
    }

    @Test
    fun storedCiphertextIsEligibleButNeverExposedAsKeyMaterial() {
        val wrapped = generate()
        val row = Pubkey(
            nickname = "work", type = PASSKEY_WRAPPED_TYPE, privateKey = wrapped.backup.toByteArray(), publicKey = wrapped.publicKey,
            encrypted = true, startup = false, confirmation = false, createdDate = 0, storageType = KeyStorageType.PASSKEY,
            keystoreAlias = wrapped.credentialId, allowBackup = true,
        )
        assertTrue(row.isWrappedPasskey())
        assertFalse(row.isPasskey())
        assertFalse(row.copy(encrypted = false).isWrappedPasskey())
        assertFalse(row.copy(privateKey = byteArrayOf(1)).isWrappedPasskey())
        assertFalse(row.copy(storageType = KeyStorageType.EXPORTABLE).isWrappedPasskey())
        assertFalse(row.copy(keystoreAlias = "BAUG").isWrappedPasskey())
        assertFalse(row.copy(publicKey = generate().publicKey).isWrappedPasskey())
        val wire = row.storageWire()
        assertEquals(true, wire["eligible"])
        assertEquals(true, wire["passkeyWrapped"])
        assertEquals(false, wire["passkey"])
        assertEquals(true, wire["allowBackup"])
        assertFalse(wire.containsKey("privateKey"))
        assertFalse(wire.containsKey("ciphertext"))
    }

    @Test
    fun rejectsOtherFormatsAndAlgorithmsBeforeUnlocking() {
        val key = generate()
        for ((field, value) in listOf("format" to "tilde-prf-probe", "version" to 2, "rpId" to "example.com", "algorithm" to "ssh-rsa", "credentialId" to "", "salt" to "AQID", "nonce" to "AQID", "publicKey" to "AQID", "ciphertext" to "AQID")) {
            assertThrows(IllegalArgumentException::class.java) { PasskeyCredential.parse(JSONObject(key.backup).put(field, value).toString()) }
        }
        assertThrows(IllegalArgumentException::class.java) { PasskeyCredential.parse(" ".repeat(65537)) }
    }

    @Test
    fun passwordIsEncryptedAndBoundToItsServerAndAccount() {
        val input = "test-password-only".toByteArray()
        val secret = ByteArray(32) { 7 }
        val password = PasskeyCredential.protectPassword("work", "AQID", ByteArray(32) { 4 }, secret, input, "server.example", 22, "alice")
        assertArrayEquals(ByteArray(input.size), input)
        assertArrayEquals(ByteArray(32), secret)
        assertFalse(password.backup.contains("test-password-only"))
        val restored = PasskeyCredential.parse(password.backup)
        assertTrue(restored.isPassword)
        assertArrayEquals("test-password-only".toByteArray(), restored.password(ByteArray(32) { 7 }, "SERVER.EXAMPLE.", 22, "alice"))
        for ((host, port, user) in listOf(Triple("other.example", 22, "alice"), Triple("server.example", 23, "alice"), Triple("server.example", 22, "bob"))) {
            val denied = ByteArray(32) { 7 }
            assertThrows(IllegalArgumentException::class.java) { restored.password(denied, host, port, user) }
            assertArrayEquals(ByteArray(32), denied)
        }
        assertThrows(IllegalArgumentException::class.java) { restored.sign(ByteArray(32) { 7 }, byteArrayOf(1)) }
        assertThrows(IllegalArgumentException::class.java) { generate().password(ByteArray(32) { 7 }, "server.example", 22, "alice") }
    }
}
