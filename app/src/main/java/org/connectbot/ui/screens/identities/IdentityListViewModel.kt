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

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.connectbot.data.HostRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.Identity
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.SecurePasswordStorage
import javax.inject.Inject

data class IdentityListUiState(
    val identities: List<Identity> = emptyList(),
    val pubkeys: List<Pubkey> = emptyList(),
    val editing: Identity? = null,
    val password: String = "",
    val hasPassword: Boolean = false,
    val busy: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class IdentityListViewModel @Inject constructor(
    private val repository: HostRepository,
    private val pubkeys: PubkeyRepository,
    private val passwords: SecurePasswordStorage,
    private val dispatchers: CoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(IdentityListUiState())
    val uiState = state.asStateFlow()

    init {
        viewModelScope.launch { repository.observeIdentities().collect { list -> state.update { it.copy(identities = list) } } }
        viewModelScope.launch { pubkeys.observeAll().collect { list -> state.update { it.copy(pubkeys = list) } } }
    }

    fun edit(identity: Identity = Identity(name = "", username = "")) {
        viewModelScope.launch(dispatchers.io) {
            state.update { it.copy(editing = identity, password = "", hasPassword = passwords.hasIdentityPassword(identity.id), error = null) }
        }
    }

    fun dismissEditor() {
        state.update { it.copy(editing = null, password = "", error = null) }
    }
    fun updateName(name: String) {
        state.update { it.copy(editing = it.editing?.copy(name = name)) }
    }
    fun updateUsername(username: String) {
        state.update { it.copy(editing = it.editing?.copy(username = username)) }
    }
    fun updateKey(id: Long) {
        state.update { it.copy(editing = it.editing?.copy(pubkeyId = id)) }
    }
    fun updatePassword(password: String) {
        state.update { it.copy(password = password) }
    }
    fun clearPassword() {
        state.update { it.copy(password = "", hasPassword = false) }
    }

    fun save() {
        val current = state.value
        val identity = current.editing ?: return
        if (current.busy || identity.name.isBlank() || identity.username.isBlank()) return
        state.update { it.copy(busy = true) }
        viewModelScope.launch(dispatchers.io) {
            try {
                val saved = repository.saveIdentity(identity.copy(name = identity.name.trim(), username = identity.username.trim()))
                if (current.password.isNotEmpty() || !current.hasPassword) passwords.saveIdentityPassword(saved.id, current.password)
                dismissEditor()
            } catch (e: Exception) {
                state.update { it.copy(error = e.localizedMessage) }
            } finally {
                state.update { it.copy(busy = false) }
            }
        }
    }

    fun delete(identity: Identity) {
        viewModelScope.launch(dispatchers.io) {
            try {
                repository.deleteIdentity(identity.id)
            } catch (e: Exception) {
                state.update { it.copy(error = e.localizedMessage) }
            }
        }
    }
}
