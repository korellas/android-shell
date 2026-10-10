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

package org.connectbot.ui.screens.console

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.connectbot.terminal.SelectionController
import org.connectbot.terminal.SelectionMode
import org.connectbot.ui.theme.ConnectBotTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

@RunWith(AndroidJUnit4::class)
class TerminalSelectionActionsTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun selectionActionsOfferPaste() {
        val controller = mock(SelectionController::class.java)
        var pastes = 0
        compose.setContent { ConnectBotTheme { TerminalSelectionActions(controller, onEdit = {}, onPaste = { pastes++ }) } }
        compose.onNodeWithText("Paste").assertExists().performClick()
        compose.runOnIdle {
            verify(controller).clearSelection()
            assertEquals(1, pastes)
        }
    }

    @Test
    fun editCopiesSelectionIntoEditorWithoutSending() {
        val controller = mock(SelectionController::class.java)
        `when`(controller.copySelection()).thenReturn("경로 /tmp/한글\n로그")
        var edited: String? = null
        compose.setContent {
            ConnectBotTheme { TerminalSelectionActions(controller, onEdit = { edited = it }, onPaste = {}) }
        }
        compose.onNodeWithText("Edit").performClick()
        compose.runOnIdle { assertEquals("경로 /tmp/한글\n로그", edited) }
    }

    @Test
    fun lineExpandsSelectionAndCopyUsesTerminalClipboard() {
        val controller = mock(SelectionController::class.java)
        compose.setContent { ConnectBotTheme { TerminalSelectionActions(controller, onEdit = {}, onPaste = {}) } }
        compose.onNodeWithText("Line").performClick()
        compose.runOnIdle { verify(controller).setSelectionMode(SelectionMode.LINE) }
        compose.onNodeWithText("Copy").performClick()
        compose.runOnIdle { verify(controller).copySelection() }
    }
}
