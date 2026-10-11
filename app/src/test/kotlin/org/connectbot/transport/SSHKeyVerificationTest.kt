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

import com.trilead.ssh2.Connection
import com.trilead.ssh2.ConnectionInfo
import com.trilead.ssh2.ServerHostKeyVerifier
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Pubkey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockConstruction
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import java.security.KeyPair
import java.security.KeyPairGenerator

class SSHKeyVerificationTest {
    private val pair = KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair()
    private val pubkey = Pubkey(1, "test", "EC", pair.private.encoded, pair.public.encoded, false, false, false, 0)
    private val active = mock(Connection::class.java)
    private val hostKey = byteArrayOf(1, 2, 3)
    private fun transport() = SSH(Host(id = 1, hostname = "server.example", username = "alice"), null, null).apply {
        `when`(active.isAuthenticationComplete).thenReturn(true)
        `when`(active.connectionInfo).thenReturn(
            ConnectionInfo().apply {
                serverHostKey = hostKey
                serverHostKeyAlgorithm = "ssh-ed25519"
            },
        )
        setConnectionForTesting(active)
    }

    @Test fun verificationPinsActiveServerAndNeverStartsShellOrFallsBackToPassword() {
        val ssh = transport()
        mockConstruction(Connection::class.java) { connection, _ ->
            `when`(connection.connect(any(), anyInt(), anyInt(), any())).thenAnswer {
                val verifier = it.getArgument<ServerHostKeyVerifier>(0)
                assertTrue(verifier.verifyServerHostKey("server.example", 22, "ssh-ed25519", hostKey))
                assertFalse(verifier.verifyServerHostKey("server.example", 22, "ssh-ed25519", byteArrayOf(9)))
                assertFalse(verifier.verifyServerHostKey("server.example", 22, "ssh-rsa", hostKey))
                ConnectionInfo()
            }
            `when`(connection.probePublicKey("alice", pair.public)).thenReturn(true)
            `when`(connection.authenticateWithPublicKey(anyString(), any(KeyPair::class.java))).thenAnswer {
                assertEquals(pair.public, it.getArgument<KeyPair>(1).public)
                true
            }
        }.use { connections ->
            assertEquals(KeyLoginVerification.VERIFIED, ssh.verifyPublicKey(pubkey))
            val connection = connections.constructed().single()
            verify(connection).close()
            verify(connection, never()).openSession()
            verify(connection, never()).authenticateWithPassword(anyString(), anyString())
            verify(active, never()).close()
        }
    }

    @Test fun partialAuthenticationDoesNotReportKeyOnlyLoginSuccess() {
        val ssh = transport()
        mockConstruction(Connection::class.java) { connection, _ ->
            `when`(connection.connect(any(), anyInt(), anyInt(), any())).thenReturn(ConnectionInfo())
            `when`(connection.probePublicKey("alice", pair.public)).thenReturn(true)
            `when`(connection.isAuthenticationPartialSuccess).thenReturn(true)
        }.use { connections ->
            assertEquals(KeyLoginVerification.ADDITIONAL_AUTH_REQUIRED, ssh.verifyPublicKey(pubkey))
            verify(connections.constructed().single()).close()
        }
    }
}
