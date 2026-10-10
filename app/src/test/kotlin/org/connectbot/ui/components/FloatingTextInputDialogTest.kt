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

package org.connectbot.ui.components

import android.annotation.TargetApi
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.inspector.WindowInspector
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextInputSelection
import androidx.compose.ui.text.TextRange
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.connectbot.service.TerminalBridge
import org.connectbot.ui.theme.ConnectBotTheme
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [35])
@TargetApi(29)
class FloatingTextInputDialogTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun editorWindowSupportsAndroidFloatingSelectionMenu() {
        val bridge = mock(TerminalBridge::class.java)
        compose.setContent {
            ConnectBotTheme { FloatingTextInputDialog(bridge, initialText = "hello world", onDismiss = {}) }
        }
        compose.runOnIdle {
            val editor = WindowInspector.getGlobalWindowViews().last().findFocus()
            assertNotNull("Editor must have window focus", editor)
            val mode = editor!!.startActionMode(
                object : ActionMode.Callback {
                    override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
                        menu.add("Copy")
                        return true
                    }
                    override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean = true
                    override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean = false
                    override fun onDestroyActionMode(mode: ActionMode) {}
                },
                ActionMode.TYPE_FLOATING,
            )
            assertNotNull("Text selection needs an Android action mode host", mode)
            mode?.finish()
        }
    }

    @Test
    fun editingSelectionDoesNotSendUntilSendIsPressed() {
        val bridge = mock(TerminalBridge::class.java)
        compose.setContent {
            ConnectBotTheme { FloatingTextInputDialog(bridge, initialText = "hello\nworld", onDismiss = {}) }
        }
        compose.onNode(hasSetTextAction()).performTextInputSelection(TextRange(0, 5))
        compose.onNode(hasSetTextAction()).performTextInput("한글")
        compose.runOnIdle { verify(bridge, never()).injectString("한글\nworld") }
        compose.onNodeWithContentDescription("Send").performClick()
        compose.runOnIdle { verify(bridge).injectString("한글\nworld") }
    }
}
