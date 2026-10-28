/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2025-2026 Kenny Root
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

package org.connectbot.ui

import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import androidx.core.content.edit
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import org.connectbot.data.migration.DatabaseMigrator
import org.connectbot.data.migration.MigrationResult
import org.connectbot.data.migration.MigrationState
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.NotificationPermissionHelper
import org.connectbot.util.PreferenceConstants
import org.connectbot.util.ThemeMode
import timber.log.Timber
import javax.inject.Inject

/**
 * App state that exposes database migration readiness.
 */
sealed class AppUiState {
    data object Loading : AppUiState()
    data class MigrationInProgress(val state: MigrationState) : AppUiState()
    data class MigrationFailed(val error: String, val debugLog: List<String>) : AppUiState()
    data object Ready : AppUiState()
}

/**
 * Coordinates migration readiness and app authentication.
 */
@HiltViewModel
class AppViewModel @Inject constructor(
    private val migrator: DatabaseMigrator,
    private val prefs: SharedPreferences,
    private val dispatchers: CoroutineDispatchers,
    private val notificationPermissionHelper: NotificationPermissionHelper,
) : ViewModel() {

    private val _migrationUiState = MutableStateFlow<MigrationUiState>(MigrationUiState.Checking)
    private var latestMigrationState: MigrationState? = null

    private val _uiState = MutableStateFlow<AppUiState>(AppUiState.Loading)
    val uiState: StateFlow<AppUiState> = _uiState.asStateFlow()

    private val _showPermissionRationale = Channel<Unit>(Channel.CONFLATED)
    val showPermissionRationale = _showPermissionRationale.receiveAsFlow()

    private val _requestPermission = Channel<Unit>(Channel.CONFLATED)
    val requestPermission = _requestPermission.receiveAsFlow()

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    val authOnLaunchEnabled: Boolean
        get() = prefs.getBoolean(PreferenceConstants.AUTH_ON_LAUNCH, false)

    private fun currentThemeMode() = ThemeMode.fromString(prefs.getString(PreferenceConstants.THEME_MODE, null))

    private val _themeMode = MutableStateFlow(currentThemeMode())
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val themePrefListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == PreferenceConstants.THEME_MODE) {
            _themeMode.value = currentThemeMode()
        }
    }

    private val _pendingConnectionUri = MutableStateFlow<Uri?>(null)
    val pendingConnectionUri: StateFlow<Uri?> = _pendingConnectionUri.asStateFlow()

    init {
        prefs.registerOnSharedPreferenceChangeListener(themePrefListener)
        checkAndMigrate()

        viewModelScope.launch {
            _migrationUiState.collect { migrationState ->
                _uiState.value = when (migrationState) {
                    is MigrationUiState.Checking -> AppUiState.Loading

                    is MigrationUiState.InProgress -> AppUiState.MigrationInProgress(migrationState.state)

                    is MigrationUiState.Failed -> AppUiState.MigrationFailed(
                        migrationState.error,
                        migrationState.debugLog,
                    )

                    is MigrationUiState.Completed -> AppUiState.Ready
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        prefs.unregisterOnSharedPreferenceChangeListener(themePrefListener)
    }

    private fun checkAndMigrate() {
        viewModelScope.launch {
            try {
                Timber.d("Checking if migration is needed")
                val needsMigration = migrator.isMigrationNeeded()

                if (!needsMigration) {
                    Timber.d("No migration needed")
                    _migrationUiState.value = MigrationUiState.Completed
                    return@launch
                }

                Timber.i("Migration needed, starting migration")
                _migrationUiState.value = MigrationUiState.InProgress(MigrationState())

                launch {
                    migrator.migrationState.collect { state ->
                        latestMigrationState = state
                        _migrationUiState.value = MigrationUiState.InProgress(state)
                    }
                }

                when (val result = migrator.migrate()) {
                    is MigrationResult.Success -> {
                        Timber.i("Migration completed successfully: $result")
                        _migrationUiState.value = MigrationUiState.Completed
                    }

                    is MigrationResult.Failure -> {
                        Timber.e(result.error, "Migration failed")
                        _migrationUiState.value = MigrationUiState.Failed(
                            error = result.error.message ?: "Unknown error",
                            debugLog = latestMigrationState?.debugLog ?: emptyList(),
                        )
                    }
                }
            } catch (e: Exception) {
                Timber.e(e, "Error during migration check/execution")
                _migrationUiState.value = MigrationUiState.Failed(
                    error = e.message ?: "Unknown error",
                    debugLog = latestMigrationState?.debugLog ?: emptyList(),
                )
            }
        }
    }

    /**
     * Retry migration after a failure.
     */
    fun retryMigration() {
        migrator.resetMigrationState()
        _migrationUiState.value = MigrationUiState.Checking
        checkAndMigrate()
    }

    /**
     * Called when user successfully authenticates via biometric/device credential.
     */
    fun onAuthenticationSuccess() {
        _isAuthenticated.value = true
    }

    fun onAuthenticationRequired() {
        _isAuthenticated.value = false
    }

    /**
     * Set the pending connection URI that should be opened after permission dialog is dismissed.
     */
    fun setPendingConnectionUri(uri: Uri?) {
        _pendingConnectionUri.value = uri
    }

    /**
     * Clear the pending connection URI.
     */
    fun clearPendingConnectionUri() {
        _pendingConnectionUri.value = null
    }

    /**
     * Check if notification permission is needed and handle accordingly.
     * Returns true if the connection can proceed, false if permission needs to be requested.
     */
    fun checkAndRequestNotificationPermission(
        uri: Uri,
        shouldShowRationale: Boolean,
    ): Boolean {
        if (!shouldRequestNotificationPermission()) return true
        _pendingConnectionUri.value = uri
        requestNotificationPermission(shouldShowRationale)
        return false
    }

    fun shouldRequestNotificationPermission(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        prefs.getBoolean(PreferenceConstants.CONNECTION_ALERTS, true) &&
        !notificationPermissionHelper.isGranted() &&
        !prefs.getBoolean(
            PreferenceConstants.NOTIFICATION_PERMISSION_REQUESTED,
            prefs.contains(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED),
        )

    /** Request once automatically; Settings can explicitly request again. */
    fun requestNotificationPermission(shouldShowRationale: Boolean) {
        prefs.edit { putBoolean(PreferenceConstants.NOTIFICATION_PERMISSION_REQUESTED, true) }
        viewModelScope.launch {
            if (shouldShowRationale) {
                _showPermissionRationale.send(Unit)
            } else {
                _requestPermission.send(Unit)
            }
        }
    }

    /**
     * Handle the result of a notification permission request.
     * Returns the pending URI regardless of permission result, so navigation can proceed.
     * The app works fine without notification permission - connections just won't show notifications.
     */
    fun onNotificationPermissionResult(isGranted: Boolean): Uri? {
        // POST_NOTIFICATIONS controls visibility, not foreground service eligibility.
        // https://developer.android.com/develop/ui/compose/notifications/notification-permission
        prefs.edit {
            putBoolean(PreferenceConstants.NOTIFICATION_PERMISSION_REQUESTED, true)
            putBoolean(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED, !isGranted)
        }

        // Return and clear pending URI so navigation can proceed
        val uri = _pendingConnectionUri.value
        _pendingConnectionUri.value = null
        return uri
    }
}

/**
 * UI state for the migration process.
 */
sealed class MigrationUiState {
    data object Checking : MigrationUiState()
    data class InProgress(val state: MigrationState) : MigrationUiState()
    data object Completed : MigrationUiState()
    data class Failed(val error: String, val debugLog: List<String>) : MigrationUiState()
}
