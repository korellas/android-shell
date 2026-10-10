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

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import org.connectbot.R
import org.connectbot.service.TerminalBridge
import org.connectbot.transport.KeyLoginVerification
import org.connectbot.transport.KeyRegistration
import org.connectbot.transport.SSH
import org.connectbot.ui.components.InlinePrompt

@Composable
internal fun KeyEnrollmentDialog(bridge: TerminalBridge, onDismiss: () -> Unit, viewModel: KeyEnrollmentViewModel = hiltViewModel(key = "key-enrollment:${bridge.host.id}")) {
    val state by viewModel.uiState.collectAsState()
    val prompt by bridge.promptManager.promptState.collectAsState()
    val defaultName = stringResource(R.string.login_default_key_name)
    var started by rememberSaveable(bridge.host.id) { mutableStateOf(false) }
    LaunchedEffect(bridge) {
        if (!started) {
            viewModel.begin("${bridge.host.nickname} · $defaultName")
            started = true
        }
    }
    val account = (bridge.transport as? SSH)?.keyEnrollmentUsername.orEmpty()
    AlertDialog(
        onDismissRequest = { if (!state.busy) onDismiss() },
        title = { Text(stringResource(R.string.login_register_key)) },
        text = {
            Column(Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("$account@${bridge.host.hostname}:${bridge.host.port}", style = MaterialTheme.typography.titleSmall)
                Text(stringResource(R.string.login_registration_note), style = MaterialTheme.typography.bodySmall)
                if (state.stage != EnrollmentStage.SUCCESS) {
                    KeyChoice(stringResource(R.string.login_new_key), state.selectedKeyId == null, !state.busy && state.biometricAvailable) { viewModel.selectKey(null) }
                    if (state.selectedKeyId == null) {
                        val nameExists = state.keys.any { it.nickname == state.newKeyName.trim() }
                        OutlinedTextField(
                            state.newKeyName,
                            viewModel::updateName,
                            label = { Text(stringResource(R.string.login_key_name)) },
                            enabled = !state.busy,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            isError = nameExists,
                            supportingText = if (nameExists) ({ Text(stringResource(R.string.pubkey_nickname_exists)) }) else null,
                        )
                        Text(stringResource(R.string.login_recovery_note), style = MaterialTheme.typography.bodySmall)
                    }
                    if (!state.biometricAvailable) Text(stringResource(R.string.login_no_biometric), style = MaterialTheme.typography.bodySmall)
                    if (state.keys.isNotEmpty()) Text(stringResource(R.string.login_existing_key), style = MaterialTheme.typography.titleSmall)
                    state.keys.forEach { key ->
                        KeyChoice(key.nickname, state.selectedKeyId == key.id, !state.busy) { viewModel.selectKey(key.id) }
                        Text(stringResource(if (key.isBiometric) R.string.login_key_protected else R.string.login_key_exportable), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(start = 48.dp))
                    }
                }
                state.registration?.let { Text(stringResource(if (it == KeyRegistration.ADDED) R.string.login_registration_added else R.string.login_registration_existing)) }
                when (state.stage) {
                    EnrollmentStage.REGISTERING, EnrollmentStage.VERIFYING, EnrollmentStage.APPLYING -> {
                        LinearProgressIndicator(Modifier.fillMaxWidth())
                        Text(
                            stringResource(
                                when (state.stage) {
                                    EnrollmentStage.REGISTERING -> R.string.login_registering
                                    EnrollmentStage.VERIFYING -> R.string.login_verifying
                                    else -> R.string.login_applying
                                },
                            ),
                        )
                    }

                    EnrollmentStage.SUCCESS -> Text(stringResource(R.string.login_setup_success))

                    EnrollmentStage.FAILED -> {
                        Text(
                            stringResource(
                                when (state.verification) {
                                    KeyLoginVerification.ADDITIONAL_AUTH_REQUIRED -> R.string.login_setup_additional_auth
                                    KeyLoginVerification.REJECTED -> R.string.login_setup_rejected
                                    else -> R.string.login_setup_failed
                                },
                            ),
                            color = MaterialTheme.colorScheme.error,
                        )
                        state.error?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                    }

                    else -> Unit
                }
                InlinePrompt(promptRequest = prompt, onResponse = bridge.promptManager::respond, onCancel = bridge.promptManager::cancelPrompt)
            }
        },
        confirmButton = {
            if (state.stage == EnrollmentStage.SUCCESS) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.login_done)) }
            } else {
                TextButton(onClick = { viewModel.enroll(bridge) }, enabled = state.canSubmit) { Text(stringResource(if (state.stage == EnrollmentStage.FAILED) R.string.login_retry else R.string.login_register_confirm)) }
            }
        },
        dismissButton = {
            if (state.stage != EnrollmentStage.SUCCESS) {
                TextButton(onClick = {
                    if (state.busy) bridge.promptManager.cancelPrompt() else onDismiss()
                }, enabled = !state.busy || prompt != null) { Text(stringResource(R.string.button_cancel)) }
            }
        },
    )
}

@Composable
private fun KeyChoice(label: String, selected: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().selectable(selected, enabled = enabled, role = Role.RadioButton, onClick = onClick), verticalAlignment = Alignment.CenterVertically) {
        RadioButton(selected, onClick = null, enabled = enabled)
        Text(label, Modifier.padding(start = 8.dp))
    }
}
