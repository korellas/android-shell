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

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import org.connectbot.R
import org.connectbot.data.entity.Identity
import org.connectbot.ui.screens.hosteditor.PubkeySelector

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IdentityListScreen(onNavigateBack: () -> Unit, modifier: Modifier = Modifier, viewModel: IdentityListViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsState()
    var deleting by remember { mutableStateOf<Identity?>(null) }
    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text(stringResource(R.string.identities_title)) }, navigationIcon = {
                IconButton(onClick = onNavigateBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.button_back)) }
            })
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { viewModel.edit() }) { Icon(Icons.Default.Add, stringResource(R.string.identity_add)) }
        },
    ) { padding ->
        LazyColumn(Modifier.padding(padding)) {
            item { Text(stringResource(R.string.identities_summary), Modifier.padding(16.dp)) }
            items(state.identities, key = { it.id }) { identity ->
                ListItem(
                    modifier = Modifier.clickable { viewModel.edit(identity) },
                    headlineContent = { Text(identity.name) },
                    supportingContent = { Text(identity.username) },
                    trailingContent = {
                        IconButton(onClick = { deleting = identity }) { Icon(Icons.Default.Delete, stringResource(R.string.list_host_delete)) }
                    },
                )
            }
        }
    }
    state.editing?.let { identity ->
        AlertDialog(
            onDismissRequest = { if (!state.busy) viewModel.dismissEditor() },
            title = { Text(stringResource(R.string.identities_title)) },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    OutlinedTextField(identity.name, viewModel::updateName, label = { Text(stringResource(R.string.identity_name)) }, singleLine = true)
                    OutlinedTextField(identity.username, viewModel::updateUsername, label = { Text(stringResource(R.string.hostpref_username_title)) }, singleLine = true)
                    PubkeySelector(identity.pubkeyId, state.pubkeys, viewModel::updateKey, Modifier.padding(vertical = 8.dp))
                    OutlinedTextField(
                        state.password,
                        viewModel::updatePassword,
                        label = { Text(stringResource(if (state.hasPassword) R.string.hostpref_password_unchanged else R.string.hostpref_password_title)) },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    )
                    if (state.hasPassword) TextButton(onClick = viewModel::clearPassword) { Text(stringResource(R.string.hostpref_clear_password)) }
                    Text(stringResource(R.string.identity_password_backup_note), Modifier.padding(top = 8.dp))
                    state.error?.let { Text(it) }
                }
            },
            confirmButton = {
                TextButton(onClick = viewModel::save, enabled = !state.busy && identity.name.isNotBlank() && identity.username.isNotBlank()) { Text(stringResource(R.string.button_ok)) }
            },
            dismissButton = { TextButton(onClick = viewModel::dismissEditor, enabled = !state.busy) { Text(stringResource(R.string.button_cancel)) } },
        )
    }
    deleting?.let { identity ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            text = { Text(stringResource(R.string.identity_delete_confirmation, identity.name)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(identity)
                    deleting = null
                }) { Text(stringResource(R.string.button_yes)) }
            },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.button_no)) } },
        )
    }
}
