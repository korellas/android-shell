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

package org.connectbot.ui.screens.pubkeylist

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.BiometricKeyManager
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

@OptIn(ExperimentalCoroutinesApi::class)
class PubkeyBiometricLoadingTest {
    @Test fun missingDeviceKeyShowsErrorInsteadOfCrashingKeyList() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)
        try {
            val repository = mock(PubkeyRepository::class.java)
            `when`(repository.observeAll()).thenReturn(MutableStateFlow(emptyList()))
            val biometrics = mock(BiometricKeyManager::class.java)
            `when`(biometrics.isAuthPerUse("removed")).thenThrow(IllegalStateException("Device key no longer exists"))
            val model = PubkeyListViewModel(mock(Context::class.java), repository, CoroutineDispatchers(dispatcher, dispatcher, dispatcher), biometrics)
            val key = Pubkey(
                nickname = "missing", type = "EC", privateKey = null, publicKey = byteArrayOf(1), encrypted = false,
                startup = false, confirmation = false, createdDate = 0, storageType = KeyStorageType.ANDROID_KEYSTORE, keystoreAlias = "removed",
            )
            model.toggleKeyLoaded(key) { _, _ -> error("Must not request a password for a device key") }
            advanceUntilIdle()
            assertEquals("Device key no longer exists", model.uiState.value.error)
        } finally {
            Dispatchers.resetMain()
        }
    }
}
