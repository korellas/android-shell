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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.connectbot.data.ProfileRepository
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Profile
import org.connectbot.ui.screens.settings.SettingsUiState
import org.connectbot.ui.screens.settings.SettingsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class EngineSettingsDefaultsTest {
    private val engine = Mockito.mock(AndroidShellEngine::class.java)
    private val activity = Mockito.mock(FlutterShellActivity::class.java)
    private val settings = Mockito.mock(SettingsViewModel::class.java)
    private val profiles = Mockito.mock(ProfileRepository::class.java)
    private val state = MutableStateFlow(SettingsUiState(defaultProfileId = 7, scrollback = "1234"))

    @Before
    fun setUp() {
        Mockito.`when`(engine.activity).thenReturn(activity)
        Mockito.`when`(activity.settings).thenReturn(settings)
        Mockito.`when`(settings.uiState).thenReturn(state)
        Mockito.`when`(engine.profiles).thenReturn(profiles)
    }

    @Test
    fun appDefaultIsUsedForInheritedOrMissingHostProfiles() = runTest {
        val appDefault = Profile(id = 7, name = "Chosen")
        Mockito.`when`(profiles.getById(7)).thenReturn(appDefault)
        assertEquals(appDefault, engine.resolveTerminalProfile())
        assertEquals(appDefault, engine.resolveTerminalProfile(99))
    }

    @Test
    fun explicitHostProfileOverridesAppDefault() = runTest {
        val explicit = Profile(id = 3, name = "Host")
        Mockito.`when`(profiles.getById(3)).thenReturn(explicit)
        assertEquals(explicit, engine.resolveTerminalProfile(3))
    }

    @Test
    fun missingAppDefaultFallsBackToRepositoryDefault() = runTest {
        val fallback = Profile(id = 1, name = "Default")
        Mockito.`when`(profiles.getDefault()).thenReturn(fallback)
        assertEquals(fallback, engine.resolveTerminalProfile())
    }

    @Test
    fun newHostsInheritAppProfileAndCurrentScrollbackWithoutChangingExistingHosts() {
        val defaults = state.value.newHostDefaults()
        assertNull(defaults.profileId)
        assertEquals(1234, defaults.scrollbackLines)
        val existing = Host(nickname = "Host", hostname = "example.test", profileId = 3, scrollbackLines = 567)
        assertEquals(existing, (defaults.toWire() + existing.toWire()).toHost())
    }

    @Test
    fun localQuickConnectionUsesAppDefaults() = runTest {
        val host = engine.resolveSshUri("local:///#Local")
        assertEquals("local", host.protocol)
        assertEquals(0, host.port)
        assertNull(host.profileId)
        assertEquals(1234, host.scrollbackLines)
    }

    @Test
    fun timedAutomationRequiresPositiveDurationAndUntimedActionsAllowZero() {
        for (type in listOf("WAIT_FOR_TEXT", "DELAY")) {
            for (duration in listOf(-1L, 0L)) {
                assertThrows(IllegalArgumentException::class.java) {
                    mapOf("type" to type, "durationMs" to duration).toAutomation(1, 0)
                }
            }
            assertEquals(1L, mapOf("type" to type, "durationMs" to 1L).toAutomation(1, 0).durationMs)
        }
        assertEquals(0L, mapOf("type" to "SEND_TEXT", "durationMs" to 0L).toAutomation(1, 0).durationMs)
    }
}
