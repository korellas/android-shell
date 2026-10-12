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

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.connectbot.data.HostRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.KeyStorageType
import org.connectbot.data.entity.Pubkey
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.service.TerminalBridge
import org.connectbot.transport.KeyLoginVerification
import org.connectbot.transport.KeyRegistration
import org.connectbot.transport.SSH
import org.connectbot.util.BiometricAvailability
import org.connectbot.util.BiometricKeyManager
import javax.inject.Inject

internal enum class EnrollmentStage { IDLE, REGISTERING, VERIFYING, APPLYING, SUCCESS, FAILED }

internal data class KeyEnrollmentUiState(
    val keys: List<Pubkey> = emptyList(),
    val biometricAvailable: Boolean = false,
    val selectedKeyId: Long? = null,
    val newKeyName: String = "",
    val stage: EnrollmentStage = EnrollmentStage.IDLE,
    val hostId: Long? = null,
    val registration: KeyRegistration? = null,
    val verification: KeyLoginVerification? = null,
    val error: String? = null,
) {
    val busy: Boolean get() = stage in setOf(EnrollmentStage.REGISTERING, EnrollmentStage.VERIFYING, EnrollmentStage.APPLYING)
    val canSubmit: Boolean get() = !busy && stage != EnrollmentStage.SUCCESS &&
        if (selectedKeyId == null) {
            biometricAvailable && newKeyName.isNotBlank() && keys.none { it.nickname == newKeyName.trim() }
        } else {
            keys.any { it.id == selectedKeyId }
        }
}

@HiltViewModel
internal class KeyEnrollmentViewModel @Inject constructor(
    private val keys: PubkeyRepository,
    private val hosts: HostRepository,
    private val biometricKeys: BiometricKeyManager,
    private val dispatchers: CoroutineDispatchers,
) : ViewModel() {
    private val _uiState = MutableStateFlow(KeyEnrollmentUiState(biometricAvailable = biometricKeys.isBiometricAvailable() == BiometricAvailability.AVAILABLE))
    val uiState = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            keys.observeAll().collect { available ->
                _uiState.update { it.copy(keys = available, selectedKeyId = if (!it.biometricAvailable && it.selectedKeyId == null) available.firstOrNull()?.id else it.selectedKeyId) }
            }
        }
    }

    fun selectKey(id: Long?) {
        if (!_uiState.value.busy && _uiState.value.stage != EnrollmentStage.SUCCESS) {
            _uiState.update { it.copy(selectedKeyId = id, stage = EnrollmentStage.IDLE, registration = null, verification = null, error = null) }
        }
    }

    fun updateName(name: String) {
        if (!_uiState.value.busy) _uiState.update { it.copy(newKeyName = name) }
    }

    fun begin(defaultName: String) {
        if (!_uiState.value.busy) {
            _uiState.update {
                it.copy(
                    newKeyName = defaultName,
                    stage = EnrollmentStage.IDLE,
                    hostId = null,
                    registration = null,
                    verification = null,
                    error = null,
                    selectedKeyId = if (it.biometricAvailable) null else it.keys.firstOrNull()?.id,
                )
            }
        }
    }

    fun enroll(bridge: TerminalBridge) {
        val state = _uiState.value
        val transport = bridge.transport as? SSH ?: return
        if (!state.canSubmit || !transport.canEnrollKey || bridge.host.id <= 0) return
        val originalHost = bridge.host
        _uiState.update { it.copy(stage = EnrollmentStage.REGISTERING, hostId = originalHost.id, registration = null, verification = null, error = null) }
        viewModelScope.launch {
            try {
                withContext(dispatchers.io) {
                    val key = state.selectedKeyId?.let { keys.getById(it) ?: error("The selected SSH key no longer exists.") }
                        ?: createBiometricKey(state.newKeyName.trim())
                    _uiState.update { it.copy(selectedKeyId = key.id) }
                    val registration = transport.registerPublicKey(key)
                    _uiState.update { it.copy(stage = EnrollmentStage.VERIFYING, registration = registration) }
                    val verification = transport.verifyPublicKey(key)
                    _uiState.update { it.copy(verification = verification) }
                    if (verification != KeyLoginVerification.VERIFIED) {
                        _uiState.update { it.copy(stage = EnrollmentStage.FAILED) }
                        return@withContext
                    }
                    _uiState.update { it.copy(stage = EnrollmentStage.APPLYING) }
                    val fresh = hosts.findHostById(originalHost.id) ?: error("The saved host no longer exists.")
                    check(fresh.hostname == originalHost.hostname && fresh.port == originalHost.port && fresh.jumpHostId == originalHost.jumpHostId) {
                        "The host address changed during registration. Its login settings were not changed."
                    }
                    val updated = hosts.saveHost(fresh.copy(pubkeyId = key.id, identityId = null, username = transport.keyEnrollmentUsername))
                    withContext(dispatchers.main) { bridge.manager.updateHostConfiguration(bridge, updated) }
                    _uiState.update { it.copy(stage = EnrollmentStage.SUCCESS) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _uiState.update { it.copy(stage = EnrollmentStage.FAILED, error = e.message) }
            }
        }
    }

    private suspend fun createBiometricKey(name: String): Pubkey {
        check(keys.getByNickname(name) == null) { "A key with this name already exists." }
        val alias = biometricKeys.generateKeyAlias()
        var saved = false
        try {
            val publicKey = biometricKeys.generateEcKey(alias, 256)
            val key = keys.save(
                Pubkey(
                    nickname = name, type = "EC", privateKey = null, publicKey = publicKey.encoded,
                    encrypted = false, startup = false, confirmation = false, createdDate = System.currentTimeMillis(),
                    storageType = KeyStorageType.ANDROID_KEYSTORE, allowBackup = false, keystoreAlias = alias,
                ),
            )
            saved = true
            return key
        } finally {
            if (!saved) runCatching { biometricKeys.deleteKey(alias) }
        }
    }
}
