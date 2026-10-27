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
import androidx.core.net.toUri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.connectbot.data.migration.DatabaseMigrator
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.PreferenceConstants
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for AppViewModel notification permission logic.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class AppViewModelPermissionTest {

    private val testDispatcher = StandardTestDispatcher()
    private val dispatchers = CoroutineDispatchers(
        default = testDispatcher,
        io = testDispatcher,
        main = testDispatcher,
    )
    private lateinit var migrator: DatabaseMigrator
    private lateinit var prefs: SharedPreferences
    private lateinit var prefsEditor: SharedPreferences.Editor
    private lateinit var notificationPermissionHelper: org.connectbot.util.NotificationPermissionHelper
    private lateinit var viewModel: AppViewModel

    @Before
    fun setUp() = runTest {
        Dispatchers.setMain(testDispatcher)

        migrator = mock()
        prefs = mock()
        prefsEditor = mock()
        notificationPermissionHelper = mock()

        whenever(migrator.isMigrationNeeded()).thenReturn(false)
        whenever(prefs.edit()).thenReturn(prefsEditor)
        whenever(prefsEditor.putBoolean(any(), any())).thenReturn(prefsEditor)
        whenever(notificationPermissionHelper.isGranted()).thenReturn(true)

        viewModel = AppViewModel(migrator, prefs, dispatchers, notificationPermissionHelper)
        advanceUntilIdle()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // region onNotificationPermissionResult tests

    @Test
    fun onNotificationPermissionResult_Granted_WithPendingUri_ReturnsPendingUriAndClearsIt() = runTest {
        val uri = "ssh://user@host".toUri()
        viewModel.setPendingConnectionUri(uri)

        val result = viewModel.onNotificationPermissionResult(isGranted = true)

        assertEquals("Should return the pending URI", uri, result)
        assertNull("Should clear pending URI", viewModel.pendingConnectionUri.value)
    }

    @Test
    fun onNotificationPermissionResult_Granted_NoPendingUri_ReturnsNull() = runTest {
        val result = viewModel.onNotificationPermissionResult(isGranted = true)

        assertNull("Should return null when no pending URI", result)
    }

    @Test
    fun onNotificationPermissionResult_Denied_WithPendingUri_ReturnsPendingUriAndClearsIt() = runTest {
        val uri = "ssh://user@host".toUri()
        viewModel.setPendingConnectionUri(uri)

        val result = viewModel.onNotificationPermissionResult(isGranted = false)

        assertEquals("Should return pending URI even when denied", uri, result)
        assertNull("Should clear pending URI", viewModel.pendingConnectionUri.value)
        verify(prefsEditor, never()).putBoolean(eq(PreferenceConstants.CONNECTION_ALERTS), any())
        verify(prefsEditor).putBoolean(eq(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED), eq(true))
        verify(prefsEditor).apply()
    }

    @Test
    fun onNotificationPermissionResult_Denied_NoPendingUri_ReturnsNull() = runTest {
        val result = viewModel.onNotificationPermissionResult(isGranted = false)

        assertNull("Should return null when no pending URI", result)
        verify(prefsEditor, never()).putBoolean(eq(PreferenceConstants.CONNECTION_ALERTS), any())
        verify(prefsEditor).putBoolean(eq(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED), eq(true))
        verify(prefsEditor).apply()
    }

    @Test
    fun onNotificationPermissionResult_Denied_SetsNotificationPermissionDeniedFlag() = runTest {
        viewModel.onNotificationPermissionResult(isGranted = false)

        verify(prefsEditor).putBoolean(eq(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED), eq(true))
    }

    @Test
    fun onNotificationPermissionResult_Granted_ClearsNotificationPermissionDeniedFlag() = runTest {
        viewModel.onNotificationPermissionResult(isGranted = true)

        verify(prefsEditor).putBoolean(eq(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED), eq(false))
    }

    // endregion

    // region Pending state management tests

    @Test
    fun setPendingConnectionUri_UpdatesStateFlow() = runTest {
        val uri = "ssh://test@example.com".toUri()

        viewModel.setPendingConnectionUri(uri)

        assertEquals("Should update pending URI", uri, viewModel.pendingConnectionUri.value)
    }

    @Test
    fun clearPendingConnectionUri_ClearsStateFlow() = runTest {
        val uri = "ssh://test@example.com".toUri()
        viewModel.setPendingConnectionUri(uri)

        viewModel.clearPendingConnectionUri()

        assertNull("Should clear pending URI", viewModel.pendingConnectionUri.value)
    }

    // endregion
}
