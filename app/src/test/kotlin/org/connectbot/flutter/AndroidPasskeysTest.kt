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
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec

@RunWith(RobolectricTestRunner::class)
class AndroidPasskeysTest {
    private fun key(): Pubkey {
        val public = KeyPairGenerator.getInstance("EC").apply {
            initialize(ECGenParameterSpec("secp256r1"))
        }.generateKeyPair().public
        return Pubkey(
            nickname = "work", type = PASSKEY_TYPE, privateKey = null,
            publicKey = public.encoded, encrypted = false, startup = false,
            confirmation = false, createdDate = 0, storageType = KeyStorageType.PASSKEY,
            keystoreAlias = "AQID", allowBackup = true,
        )
    }

    @Test
    fun onlyPublicP256PasskeyReferencesAreEligible() {
        val key = key()
        assertTrue(key.isPasskey())
        assertFalse(key.copy(privateKey = byteArrayOf(1)).isPasskey())
        assertFalse(key.copy(storageType = KeyStorageType.ANDROID_KEYSTORE).isPasskey())
        assertFalse(key.copy(publicKey = byteArrayOf(1)).isPasskey())
        assertFalse(key.copy(keystoreAlias = "").isPasskey())
        assertFalse(key.copy(keystoreAlias = "AQID=").isPasskey())
        assertFalse(key.copy(keystoreAlias = null).isPasskey())
    }

    @Test
    fun metadataCanBeBackedUpWithoutPrivateMaterial() {
        val wire = key().storageWire()
        assertEquals(true, wire["passkey"])
        assertEquals(true, wire["eligible"])
        assertEquals(true, wire["allowBackup"])
        assertEquals(false, wire["biometric"])
        assertEquals(PASSKEY_RP_ID, wire["rpId"])
        assertEquals("AQID", wire["credentialId"])
        assertFalse(wire.containsKey("privateKey"))
    }
}
