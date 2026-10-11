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

package org.connectbot

import android.graphics.Bitmap
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextReplacement
import androidx.test.ext.junit.runners.AndroidJUnit4
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.connectbot.ui.screens.hosteditor.HostEditorScreenContent
import org.connectbot.ui.screens.hosteditor.HostEditorUiState
import org.connectbot.ui.theme.ConnectBotTheme
import org.connectbot.util.ThemeMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w412dp-h900dp-xhdpi")
class HostEditorLayoutTest {
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<HiltComponentActivity>()

    private val existingHost = HostEditorUiState(hostId = 42L, nickname = "Work server", username = "user", hostname = "example.com")

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @Test
    @Config(qualifiers = "ko-rKR-w412dp-h900dp-xhdpi")
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun coverShowsCategoriesAndOnlyTheSelectedFields() {
        show(existingHost)
        composeTestRule.onNodeWithTag("host_category_connection").assertIsDisplayed()
        composeTestRule.onNodeWithTag("host_category_authentication").assertIsDisplayed()
        composeTestRule.onNodeWithText(text(R.string.hostpref_nickname_title)).assertDoesNotExist()
        saveScreenshot("fold8-host-categories.png")

        composeTestRule.onNodeWithTag("host_category_connection").performClick()
        composeTestRule.onNodeWithText(text(R.string.hostpref_hostname_title)).assertIsDisplayed()
        composeTestRule.onNodeWithText(text(R.string.hostpref_password_title)).assertDoesNotExist()
        saveScreenshot("fold8-host-connection.png")
        back()
        composeTestRule.onNodeWithTag("host_category_authentication").performClick()
        composeTestRule.onNodeWithText(text(R.string.hostpref_hostname_title)).assertDoesNotExist()
        composeTestRule.onNodeWithText(text(R.string.hostpref_password_title)).assertIsDisplayed()
        saveScreenshot("fold8-host-authentication.png")
    }

    @Test
    fun categoryBackKeepsEditsAndOnlyLeavingEditorPromptsToDiscard() {
        var exited = false
        show(existingHost.copy(hasUnsavedChanges = true), onNavigateBack = { exited = true })
        composeTestRule.onNodeWithTag("host_category_authentication").performClick()
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread { composeTestRule.activity.onBackPressedDispatcher.onBackPressed() }
        composeTestRule.onNodeWithTag("host_category_connection").assertIsDisplayed()
        composeTestRule.onNodeWithText(text(R.string.editor_discard_changes_title)).assertDoesNotExist()
        assertFalse(exited)

        back()
        composeTestRule.onNodeWithText(text(R.string.editor_discard_changes_title)).assertIsDisplayed()
        composeTestRule.onNodeWithText(text(R.string.button_cancel)).performClick()
        assertFalse(exited)
        composeTestRule.onNodeWithTag("host_category_connection").performClick()
        composeTestRule.onNodeWithText("Work server").assertIsDisplayed()
    }

    @Test
    @Config(qualifiers = "ko-rKR-w750dp-h900dp-xhdpi")
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun unfoldedEditorKeepsCategoriesBesideDetails() {
        show(existingHost)
        val category = composeTestRule.onNodeWithTag("host_category_connection")
        category.assertIsDisplayed().assertIsSelected()
        val field = composeTestRule.onNodeWithText(text(R.string.hostpref_hostname_title))
        field.assertIsDisplayed()
        assertTrue(category.fetchSemanticsNode().boundsInRoot.right < field.fetchSemanticsNode().boundsInRoot.left)

        composeTestRule.onNodeWithTag("host_category_session").performClick()
        category.assertIsDisplayed()
        composeTestRule.onNodeWithText(text(R.string.hostpref_stayconnected_title)).assertIsDisplayed()
        saveScreenshot("fold8-host-wide.png")
    }

    @Test
    @Config(qualifiers = "w1000dp-h1200dp-xhdpi")
    fun editsSurviveCategoryChangesAndSaveFromAnotherCategory() {
        var saved: HostEditorUiState? = null
        var exited = false
        show(existingHost, onNavigateBack = { exited = true }, onSave = { saved = it })
        composeTestRule.onNodeWithText(text(R.string.hostpref_nickname_title)).performTextReplacement("Personal label")
        composeTestRule.onNodeWithTag("host_category_authentication").performClick()
        composeTestRule.onNodeWithTag("host_category_connection").performClick()
        composeTestRule.onNodeWithText(text(R.string.hostpref_nickname_title)).assert(hasText("Personal label"))
        composeTestRule.onNodeWithTag("host_category_session").performClick()
        composeTestRule.onNodeWithTag("add_host_button").performClick()
        composeTestRule.waitForIdle()

        assertEquals("Personal label", saved?.nickname)
        assertEquals(existingHost.hostname, saved?.hostname)
        assertTrue(exited)
    }

    private fun show(initial: HostEditorUiState, onNavigateBack: () -> Unit = {}, onSave: (HostEditorUiState) -> Unit = {}) {
        composeTestRule.setContent {
            var state by remember { mutableStateOf(initial) }
            ConnectBotTheme(themeMode = ThemeMode.DARK) {
                HostEditorScreenContent(
                    hostId = state.hostId,
                    uiState = state,
                    onNavigateBack = onNavigateBack,
                    onNicknameChange = { state = state.copy(nickname = it, hasUnsavedChanges = true) },
                    onNicknameFocusChange = {},
                    onProtocolChange = {},
                    onUsernameChange = {},
                    onHostnameChange = {},
                    onPortChange = {},
                    onColorChange = {},
                    onPubkeyChange = {},
                    onProfileChange = {},
                    onNavigateToProfile = {},
                    onUseAuthAgentChange = {},
                    onCompressionChange = {},
                    onWantSessionChange = {},
                    onStayConnectedChange = {},
                    onQuickDisconnectChange = {},
                    onEditAutomation = {},
                    onJumpHostChange = {},
                    onIpVersionChange = {},
                    onPasswordChange = {},
                    onClearPassword = {},
                    onSaveHost = {
                        onSave(state)
                        true
                    },
                )
            }
        }
    }

    private fun text(id: Int) = composeTestRule.activity.getString(id)

    private fun back() = composeTestRule.onNodeWithContentDescription(text(R.string.button_navigate_up)).performClick()

    private fun saveScreenshot(name: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val file = File("build/reports/" + name)
            file.parentFile!!.mkdirs()
            file.outputStream().use { output ->
                composeTestRule.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, output)
            }
        }
    }
}
