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

import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Profile
import org.connectbot.data.entity.Pubkey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class EngineWireTest {
    @Test fun hostEditingPreservesAdvancedConnectionOptions() {
        val host = Host(
            id = 9, nickname = "server", hostname = "example.test", compression = true, wantSession = false,
            jumpHostId = 4, identityId = 3, pubkeyId = 2, moshPort = 60001, moshNetworkTimeout = 30, useAuthAgent = "confirm",
        )
        val edited = (host.toWire() + mapOf("nickname" to "renamed")).toHost()
        assertEquals(host.copy(nickname = "renamed"), edited)
    }

    @Test fun hostEditingRejectsInvalidPorts() {
        for (port in listOf(-1L, 0L, 65536L)) {
            assertThrows(IllegalArgumentException::class.java) {
                mapOf("nickname" to "server", "hostname" to "example.test", "port" to port).toHost()
            }
        }
    }

    @Test fun keySnapshotsContainNoPrivateKeyMaterialOrKeystoreAlias() {
        val secret = byteArrayOf(1, 3, 5, 7)
        val key = Pubkey(
            nickname = "private", type = "RSA", privateKey = secret, publicKey = byteArrayOf(2),
            encrypted = true, startup = false, confirmation = true, createdDate = 0, keystoreAlias = "secret-alias",
        )
        val wire = key.toWire(false)
        assertFalse(wire.values.any { it is ByteArray })
        assertFalse(wire.values.contains("secret-alias"))
        assertEquals(true, wire["encrypted"])
    }

    @Test fun profileEditingPreservesImageConsentAndFixedSize() {
        val profile = Profile(name = "work", inlineImages = "ask", forceSizeRows = 30, forceSizeColumns = 120, fontFamily = "local:work.ttf")
        assertEquals(profile, profile.toWire().toProfile())
        assertThrows(IllegalArgumentException::class.java) { (profile.toWire() + mapOf("inlineImages" to "anything")).toProfile() }
    }
}
