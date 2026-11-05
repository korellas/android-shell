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

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.BiometricKeyManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executors

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class EngineKeyStorageThreadTest {
    @Test
    fun passkeySaveAndKeyEditsNotifyOnMainWhileStorageRunsOnIo() = runTest {
        val owner = Thread.currentThread()
        Executors.newSingleThreadExecutor().asCoroutineDispatcher().use { io ->
            val dispatchers = CoroutineDispatchers(default = io, io = io, main = StandardTestDispatcher(testScheduler))
            val activity = Mockito.mock(FlutterShellActivity::class.java)
            val keys = Mockito.mock(PubkeyRepository::class.java)
            val engine = Mockito.mock(AndroidShellEngine::class.java)
            val manager = Mockito.mock(BiometricKeyManager::class.java)
            Mockito.`when`(engine.activity).thenReturn(activity)
            Mockito.`when`(engine.keys).thenReturn(keys)
            Mockito.`when`(engine.authenticated).thenReturn(true)
            Mockito.`when`(activity.dispatchers).thenReturn(dispatchers)
            Mockito.`when`(activity.biometricKeys).thenReturn(manager)
            val public = KeyPairGenerator.getInstance("EC").apply {
                initialize(ECGenParameterSpec("secp256r1"))
            }.generateKeyPair().public.encoded
            val key = Pubkey(
                id = 7, nickname = "work", type = PASSKEY_TYPE, privateKey = null,
                publicKey = public, encrypted = false, startup = false, confirmation = false,
                createdDate = 0, storageType = KeyStorageType.PASSKEY, allowBackup = true, keystoreAlias = "AQID",
            )
            Mockito.`when`(keys.getAll()).thenAnswer {
                assertNotSame(owner, Thread.currentThread())
                emptyList<Pubkey>()
            }
            Mockito.`when`(keys.getById(7)).thenAnswer {
                assertNotSame(owner, Thread.currentThread())
                key
            }
            Mockito.`when`(keys.save(Mockito.any(Pubkey::class.java) ?: key)).thenAnswer {
                assertNotSame(owner, Thread.currentThread())
                (it.arguments[0] as Pubkey).copy(id = 7)
            }
            var changes = 0
            Mockito.doAnswer {
                assertSame("UI refresh must use the main dispatcher", owner, Thread.currentThread())
                changes++
                null
            }.`when`(engine).changed()
            engine.keyStorageOperation("key.storageSavePasskey", mapOf("rpId" to PASSKEY_RP_ID, "credentialId" to "AQID", "publicKey" to public, "nickname" to "work"))
            engine.keyStorageOperation("key.storageSave", mapOf("id" to 7))
            engine.keyStorageOperation("key.storageDelete", mapOf("id" to 7))
            assertEquals(3, changes)
        }
    }
}
