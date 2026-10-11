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

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.outlined.Fingerprint
import androidx.compose.material.icons.outlined.Key
import androidx.compose.material.icons.outlined.People
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import org.connectbot.R
import org.connectbot.data.HostRepository
import org.connectbot.data.entity.Host
import javax.inject.Inject

@Composable
fun LoginScreen(
    onNavigateBack: () -> Unit,
    onSetupHost: (Long) -> Unit,
    onManageKeys: () -> Unit,
    onManageAccounts: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: LoginViewModel = hiltViewModel(),
) {
    val hosts by viewModel.hosts.collectAsState()
    LoginScreenContent(hosts, onNavigateBack, onSetupHost, onManageKeys, onManageAccounts, modifier)
}

@HiltViewModel
class LoginViewModel @Inject constructor(repository: HostRepository) : ViewModel() {
    val hosts = repository.observeHosts().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreenContent(hosts: List<Host>, onNavigateBack: () -> Unit, onSetupHost: (Long) -> Unit, onManageKeys: () -> Unit, onManageAccounts: () -> Unit, modifier: Modifier = Modifier) {
    var chooseServer by rememberSaveable { mutableStateOf(false) }
    Scaffold(modifier = modifier, topBar = {
        TopAppBar(title = { Text(stringResource(R.string.login_title)) }, navigationIcon = {
            IconButton(onClick = onNavigateBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.button_back)) }
        })
    }) { padding ->
        LazyColumn(Modifier.padding(padding).fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { LoginCard(R.string.login_setup, R.string.login_setup_summary, Icons.Outlined.Fingerprint) { chooseServer = true } }
            item { LoginCard(R.string.login_keys, R.string.login_keys_summary, Icons.Outlined.Key, onManageKeys) }
            item { LoginCard(R.string.identities_title, R.string.login_accounts_summary, Icons.Outlined.People, onManageAccounts) }
            item { Text(stringResource(R.string.login_recovery_note), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 8.dp)) }
        }
    }
    if (chooseServer) {
        val sshHosts = hosts.filter { it.protocol == "ssh" && it.id > 0 }
        AlertDialog(
            onDismissRequest = { chooseServer = false },
            title = { Text(stringResource(R.string.login_choose_server)) },
            text = {
                if (sshHosts.isEmpty()) {
                    Text(stringResource(R.string.login_no_servers))
                } else {
                    LazyColumn(Modifier.heightIn(max = 400.dp)) {
                        items(sshHosts, key = { it.id }) { host ->
                            ListItem(
                                headlineContent = { Text(host.nickname) },
                                supportingContent = { Text("${host.username}@${host.hostname}:${host.port}") },
                                modifier = Modifier.clickable {
                                    chooseServer = false
                                    onSetupHost(host.id)
                                },
                            )
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { chooseServer = false }) { Text(stringResource(R.string.button_cancel)) } },
        )
    }
}

@Composable
private fun LoginCard(title: Int, summary: Int, icon: ImageVector, onClick: () -> Unit) {
    Card(onClick = onClick, shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(title), style = MaterialTheme.typography.titleMedium)
                Text(stringResource(summary), style = MaterialTheme.typography.bodyMedium)
            }
            Icon(Icons.Default.ChevronRight, null)
        }
    }
}
