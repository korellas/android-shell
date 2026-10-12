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

package org.connectbot.ui.screens.login

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.connectbot.data.HostRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.service.TerminalBridge
import org.connectbot.service.TerminalManager
import org.connectbot.transport.KeyLoginVerification
import org.connectbot.transport.KeyRegistration
import org.connectbot.transport.SSH
import org.connectbot.util.BiometricAvailability
import org.connectbot.util.BiometricKeyManager
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class KeyEnrollmentViewModelTest {
    private val dispatcher = UnconfinedTestDispatcher()
    private val keys = mock(PubkeyRepository::class.java)
    private val hosts = mock(HostRepository::class.java)
    private val biometrics = mock(BiometricKeyManager::class.java)
    private val bridge = mock(TerminalBridge::class.java)
    private val manager = mock(TerminalManager::class.java)
    private val ssh = mock(SSH::class.java)
    private val host = Host(id = 7, nickname = "server", hostname = "server.example", username = "alice", identityId = 3)
    private val key = Pubkey(9, "existing", "EC", byteArrayOf(1), byteArrayOf(2), false, false, false, 0)

    @Before fun setup() {
        Dispatchers.setMain(dispatcher)
        `when`(keys.observeAll()).thenReturn(MutableStateFlow(listOf(key)))
        runTest { `when`(keys.getById(key.id)).thenReturn(key) }
        `when`(biometrics.isBiometricAvailable()).thenReturn(BiometricAvailability.AVAILABLE)
        `when`(bridge.host).thenReturn(host)
        `when`(bridge.manager).thenReturn(manager)
        `when`(bridge.transport).thenReturn(ssh)
        `when`(ssh.canEnrollKey).thenReturn(true)
        `when`(ssh.keyEnrollmentUsername).thenReturn("verified-user")
        `when`(ssh.registerPublicKey(key)).thenReturn(KeyRegistration.ADDED)
    }

    @After fun cleanup() {
        Dispatchers.resetMain()
    }

    private fun viewModel() = KeyEnrollmentViewModel(keys, hosts, biometrics, CoroutineDispatchers(dispatcher, dispatcher, dispatcher)).apply { selectKey(key.id) }

    @Test fun failedKeyVerificationKeepsOriginalHostLogin() = runTest {
        `when`(ssh.verifyPublicKey(key)).thenReturn(KeyLoginVerification.REJECTED)
        viewModel().enroll(bridge)
        advanceUntilIdle()
        verify(ssh).verifyPublicKey(key)
        verify(hosts, never()).saveHost(any(Host::class.java) ?: host)
    }

    @Test fun verifiedKeyChangesOnlySelectedHostAndDoesNotRewriteSharedIdentity() = runTest {
        `when`(ssh.verifyPublicKey(key)).thenReturn(KeyLoginVerification.VERIFIED)
        `when`(hosts.findHostById(host.id)).thenReturn(host.copy(compression = true))
        `when`(hosts.saveHost(any(Host::class.java) ?: host)).thenAnswer { it.getArgument<Host>(0) }
        val model = viewModel()
        model.enroll(bridge)
        advanceUntilIdle()
        assertEquals(host.id, model.uiState.value.hostId)
        val saved = ArgumentCaptor.forClass(Host::class.java)
        verify(hosts).saveHost(saved.capture() ?: host)
        assertEquals(host.copy(compression = true, identityId = null, pubkeyId = key.id, username = "verified-user"), saved.value)
        verify(hosts, never()).saveIdentity(any(org.connectbot.data.entity.Identity::class.java) ?: org.connectbot.data.entity.Identity(name = "placeholder", username = ""))
    }

    @Test fun failedRegistrationNeverAppliesKeyOrTriesVerification() = runTest {
        `when`(ssh.registerPublicKey(key)).thenAnswer { throw IOException("Permission denied") }
        viewModel().enroll(bridge)
        advanceUntilIdle()
        verify(ssh).registerPublicKey(key)
        verify(ssh, never()).verifyPublicKey(any(Pubkey::class.java) ?: key)
        verify(hosts, never()).saveHost(any(Host::class.java) ?: host)
    }

    @Test fun newlyCreatedKeyIsDeviceOnlyAndRetainedAfterServerRejectsLogin() = runTest {
        val publicKey = java.security.KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair().public
        `when`(biometrics.generateKeyAlias()).thenReturn("new-alias")
        `when`(biometrics.generateEcKey("new-alias", 256)).thenReturn(publicKey)
        `when`(keys.save(any(Pubkey::class.java) ?: key)).thenAnswer { it.getArgument<Pubkey>(0).copy(id = 99) }
        `when`(ssh.registerPublicKey(any(Pubkey::class.java) ?: key)).thenReturn(KeyRegistration.ADDED)
        `when`(ssh.verifyPublicKey(any(Pubkey::class.java) ?: key)).thenReturn(KeyLoginVerification.REJECTED)
        val model = viewModel().apply {
            selectKey(null)
            updateName("phone key")
        }
        model.enroll(bridge)
        advanceUntilIdle()
        val saved = ArgumentCaptor.forClass(Pubkey::class.java)
        verify(keys).save(saved.capture() ?: key)
        org.junit.Assert.assertNull(saved.value.privateKey)
        org.junit.Assert.assertFalse(saved.value.allowBackup)
        org.junit.Assert.assertFalse(saved.value.startup)
        assertEquals(org.connectbot.data.entity.KeyStorageType.ANDROID_KEYSTORE, saved.value.storageType)
        verify(biometrics, never()).deleteKey("new-alias")
        verify(hosts, never()).saveHost(any(Host::class.java) ?: host)
        assertEquals(KeyRegistration.ADDED, model.uiState.value.registration)
    }
}
