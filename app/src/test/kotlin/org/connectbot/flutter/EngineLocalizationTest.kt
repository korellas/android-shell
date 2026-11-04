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

import android.content.Context
import android.content.res.Configuration
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.connectbot.ui.screens.settings.SettingsUiState
import org.connectbot.ui.screens.settings.SettingsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
class EngineLocalizationTest {
    @Test
    fun hostValidationUsesTheResourceLocale() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        for ((language, expected) in listOf("en" to "Enter a host name.", "ko" to "호스트 이름을 입력하세요.")) {
            val configuration = Configuration(context.resources.configuration).apply {
                setLocale(Locale.forLanguageTag(language))
            }
            val resources = context.createConfigurationContext(configuration).resources
            val failure = assertThrows(IllegalArgumentException::class.java) {
                mapOf<String, Any?>("hostname" to "example.test").toHost(resources)
            }
            assertEquals(expected, failure.message)
        }
    }

    @Test
    fun helpAndQuickConnectValidationUseKoreanResources() = runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(Locale.KOREAN)
        }
        val localized = context.createConfigurationContext(configuration)
        val engine = Mockito.mock(AndroidShellEngine::class.java)
        val activity = Mockito.mock(FlutterShellActivity::class.java)
        val settings = Mockito.mock(SettingsViewModel::class.java)
        Mockito.`when`(engine.activity).thenReturn(activity)
        Mockito.`when`(activity.settings).thenReturn(settings)
        Mockito.`when`(settings.uiState).thenReturn(MutableStateFlow(SettingsUiState()))
        Mockito.`when`(activity.getString(Mockito.anyInt())).thenAnswer {
            localized.getString(it.getArgument(0))
        }
        val hints = engine.platformOperation("help.document", mapOf("section" to "hints")) as String
        assertTrue(hints.contains("선택 영역 복사"))
        assertTrue(hints.contains("Ctrl+Shift+C"))
        val contact = engine.platformOperation("help.document", mapOf("section" to "contact")) as String
        assertTrue(contact.contains("문제 신고"))
        assertTrue(contact.contains("https://github.com/korellas/android-shell/issues"))
        try {
            engine.resolveSshUri("ssh://user:password@example.test")
            throw AssertionError("Expected the password-in-address validation")
        } catch (failure: IllegalArgumentException) {
            assertEquals("SSH 주소에 비밀번호를 포함할 수 없습니다.", failure.message)
        }
    }
}
