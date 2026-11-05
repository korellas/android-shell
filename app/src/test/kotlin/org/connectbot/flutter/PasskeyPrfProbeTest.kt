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

import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class PasskeyPrfProbeTest {
    // Generated independently with Node's HKDF-SHA256 and AES-256-GCM.
    private fun fixture() = JSONObject()
        .put("format", "tilde-prf-probe").put("version", 1).put("rpId", PASSKEY_RP_ID)
        .put("credentialId", "AQID")
        .put("salt", passkeyText(ByteArray(32) { it.toByte() }))
        .put("nonce", passkeyText(ByteArray(12) { it.toByte() }))
        .put("ciphertext", "NYl9YwCp5qgqMNGfAkWswgLuRjdYol2NnjvXl0LvaNHZEp9HB1JjJNtA")

    @Test
    fun decryptsIndependentFixtureAndClearsSuppliedSecret() {
        val secret = ByteArray(32) { 1 }
        verifyPrfProbe(parsePrfProbe(fixture().toString()), secret)
        assertArrayEquals(ByteArray(32), secret)
    }

    @Test
    fun incorrectSecretAndTamperedMetadataFailAuthentication() {
        val wrong = ByteArray(32) { 2 }
        assertThrows(Exception::class.java) { verifyPrfProbe(fixture(), wrong) }
        assertArrayEquals(ByteArray(32), wrong)
        for (field in listOf("credentialId", "salt", "nonce", "ciphertext")) {
            val probe = fixture()
            val bytes = passkeyBytes(probe.getString(field))
            bytes[0] = (bytes[0].toInt() xor 1).toByte()
            probe.put(field, passkeyText(bytes))
            val secret = ByteArray(32) { 1 }
            assertThrows(Exception::class.java) { verifyPrfProbe(parsePrfProbe(probe.toString()), secret) }
            assertArrayEquals(ByteArray(32), secret)
        }
    }

    @Test
    fun encryptedProbeIsPortableWithoutExportingPrfOutput() {
        val secret = ByteArray(32) { 7 }
        val encoded = createPrfProbe("AQID", ByteArray(32) { 5 }, secret)
        assertArrayEquals(ByteArray(32), secret)
        assertFalse(encoded.contains(passkeyText(ByteArray(32) { 7 })))
        verifyPrfProbe(parsePrfProbe(encoded), ByteArray(32) { 7 })
    }

    @Test
    fun rejectsUnsupportedFormatsAndUnboundedOrMalformedFieldsBeforeAuthentication() {
        for ((field, value) in listOf("format" to "tilde-passkey", "version" to 2, "rpId" to "example.com", "credentialId" to "", "salt" to "AQID", "nonce" to "AQID", "ciphertext" to "AQID")) {
            assertThrows(IllegalArgumentException::class.java) { parsePrfProbe(fixture().put(field, value).toString()) }
        }
        assertThrows(IllegalArgumentException::class.java) { parsePrfProbe(" ".repeat(65537)) }
    }

    @Test
    fun missingOrInvalidPrfResultsCannotBeReportedAsSuccess() {
        assertThrows(UnsupportedOperationException::class.java) { prfProbeSecret("{}", "AQID") }
        val credential = JSONObject().put("type", "public-key").put("rawId", "AQID")
            .put("clientExtensionResults", JSONObject().put("prf", JSONObject().put("results", JSONObject().put("first", "AQID"))))
        assertThrows(IllegalArgumentException::class.java) { prfProbeSecret(credential.toString(), "AQID") }
        credential.getJSONObject("clientExtensionResults").getJSONObject("prf").getJSONObject("results").put("first", passkeyText(ByteArray(32) { 1 }))
        assertThrows(IllegalArgumentException::class.java) { prfProbeSecret(credential.toString(), "BAUG") }
        assertTrue(prfProbeSecret(credential.toString(), "AQID").contentEquals(ByteArray(32) { 1 }))
    }

    @Test
    fun malformedResponsesDoNotExposeSecretMaterialInErrors() {
        val error = assertThrows(IllegalArgumentException::class.java) { prfProbeSecret("{secret-provider-output", "AQID") }
        assertFalse(error.message.orEmpty().contains("secret-provider-output"))
    }
}
