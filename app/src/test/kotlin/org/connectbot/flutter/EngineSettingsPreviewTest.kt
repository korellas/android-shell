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

import android.graphics.BitmapFactory
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.connectbot.data.ColorSchemePresets
import org.connectbot.data.ColorSchemeRepository
import org.connectbot.data.ProfileRepository
import org.connectbot.data.entity.Profile
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.ui.screens.settings.SettingsUiState
import org.connectbot.ui.screens.settings.SettingsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class EngineSettingsPreviewTest {
    @Test
    fun previewUsesRgbBackgroundAndDraftFontSizeWithoutSaving() = runTest {
        val dispatcher = UnconfinedTestDispatcher(testScheduler)
        val dispatchers = CoroutineDispatchers(default = dispatcher, io = dispatcher, main = dispatcher)
        val activity = Mockito.mock(FlutterShellActivity::class.java)
        val settings = Mockito.mock(SettingsViewModel::class.java)
        val profiles = Mockito.mock(ProfileRepository::class.java)
        val colors = Mockito.mock(ColorSchemeRepository::class.java)
        val engine = Mockito.mock(AndroidShellEngine::class.java)
        Mockito.`when`(engine.activity).thenReturn(activity)
        Mockito.`when`(engine.profiles).thenReturn(profiles)
        Mockito.`when`(engine.colors).thenReturn(colors)
        Mockito.`when`(activity.settings).thenReturn(settings)
        Mockito.`when`(activity.dispatchers).thenReturn(dispatchers)
        Mockito.`when`(activity.assets).thenReturn(ApplicationProvider.getApplicationContext<android.content.Context>().assets)
        Mockito.`when`(settings.uiState).thenReturn(MutableStateFlow(SettingsUiState(defaultProfileId = 1, fontFamily = "JETBRAINS_MONO")))
        Mockito.`when`(profiles.getById(1)).thenReturn(Profile(id = 1, name = "Default", colorSchemeId = -1, fontSize = 14))
        Mockito.`when`(colors.getSchemeColors(-1)).thenReturn(ColorSchemePresets.default.colors)
        Mockito.`when`(colors.getSchemeAppearance(-1)).thenReturn(Triple(0xffe4e8eb.toInt(), 0xff0e1216.toInt(), 0xff6fd8c4.toInt()))
        @Suppress("UNCHECKED_CAST")
        val result = engine.platformOperation("settings.preview", mapOf("width" to 320, "backgroundColor" to 0xff112233, "profile" to mapOf("fontSize" to 24), "sampleText" to "Font sample")) as Wire
        val png = result["png"] as ByteArray
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size)
        assertNotNull(bitmap)
        assertEquals(320, bitmap.width)
        assertEquals(0xff112233.toInt(), bitmap.getPixel(0, 0))
        assertTrue(Mockito.mockingDetails(profiles).invocations.none { it.method.name == "save" })
        @Suppress("UNCHECKED_CAST")
        val compact = engine.platformOperation("settings.preview", mapOf("width" to 80, "backgroundColor" to 0, "compact" to true, "profile" to mapOf("fontSize" to 14), "sampleText" to "Mono")) as Wire
        val compactPng = compact["png"] as ByteArray
        val sample = BitmapFactory.decodeByteArray(compactPng, 0, compactPng.size)
        assertEquals(80, sample.width)
        assertEquals(0, sample.getPixel(79, 0))
        assertTrue(sample.height < bitmap.height)
        sample.recycle()
        bitmap.recycle()
    }
}
