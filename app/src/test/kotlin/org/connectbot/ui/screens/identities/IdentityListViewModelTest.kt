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

package org.connectbot.ui.screens.identities

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.connectbot.data.HostRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.Identity
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.SecurePasswordStorage
import org.junit.After
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

@OptIn(ExperimentalCoroutinesApi::class)
class IdentityListViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repository = mock(HostRepository::class.java)
    private val pubkeys = mock(PubkeyRepository::class.java)
    private val passwords = mock(SecurePasswordStorage::class.java)

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        `when`(repository.observeIdentities()).thenReturn(flowOf(emptyList()))
        `when`(pubkeys.observeAll()).thenReturn(flowOf(emptyList()))
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel() = IdentityListViewModel(repository, pubkeys, passwords, CoroutineDispatchers(dispatcher, dispatcher, dispatcher))

    @Test
    fun newIdentitySavesPasswordUnderItsReturnedId() = runTest {
        val model = viewModel()
        model.edit()
        advanceUntilIdle()
        model.updateName(" Work ")
        model.updateUsername(" alice ")
        model.updateKey(4)
        model.updatePassword("test-password")
        val identity = Identity(name = "Work", username = "alice", pubkeyId = 4)
        `when`(repository.saveIdentity(identity)).thenReturn(identity.copy(id = 7))

        model.save()
        advanceUntilIdle()

        verify(repository).saveIdentity(identity)
        verify(passwords).saveIdentityPassword(7, "test-password")
        assertNull(model.uiState.value.editing)
    }

    @Test
    fun editingPreservesExistingPasswordUntilClearIsSaved() = runTest {
        val identity = Identity(id = 7, name = "Work", username = "alice")
        `when`(passwords.hasIdentityPassword(7)).thenReturn(true)
        `when`(repository.saveIdentity(identity)).thenReturn(identity)
        val model = viewModel()
        model.edit(identity)
        advanceUntilIdle()

        model.save()
        advanceUntilIdle()
        verify(passwords, never()).saveIdentityPassword(7, "")

        model.edit(identity)
        advanceUntilIdle()
        model.clearPassword()
        verify(passwords, never()).saveIdentityPassword(7, "")
        model.save()
        advanceUntilIdle()
        verify(passwords).saveIdentityPassword(7, "")
    }
}
