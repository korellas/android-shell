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

import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performImeAction
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.connectbot.service.PromptRequest
import org.connectbot.service.PromptResponse
import org.connectbot.ui.theme.ConnectBotTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InlinePromptTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun passwordPromptFitsOneRowAndImeDoneSubmitsWithoutLargeConfirmationButton() {
        var response: PromptResponse? = null
        compose.setContent {
            ConnectBotTheme {
                InlinePrompt(
                    promptRequest = PromptRequest.StringPrompt(null, "Password:", true),
                    onResponse = { response = it },
                    onCancel = {},
                    modifier = Modifier.testTag("prompt"),
                )
            }
        }
        val bounds = compose.onNodeWithTag("prompt").getUnclippedBoundsInRoot()
        assertTrue(bounds.bottom - bounds.top <= 64.dp)
        compose.onNodeWithText("OK").assertDoesNotExist()
        compose.onNode(hasSetTextAction()).performTextInput("test-password")
        compose.runOnIdle { assertNull(response) }
        compose.onNode(hasSetTextAction()).performImeAction()
        compose.runOnIdle { assertEquals(PromptResponse.StringResponse("test-password"), response) }
    }

    @Test
    fun compactSubmitAndCancelRemainAccessible() {
        var response: PromptResponse? = null
        var cancelled = false
        compose.setContent {
            ConnectBotTheme {
                InlinePrompt(
                    promptRequest = PromptRequest.StringPrompt("Enter the server challenge", "OTP:", false),
                    onResponse = { response = it },
                    onCancel = { cancelled = true },
                )
            }
        }
        compose.onNodeWithText("Enter the server challenge").assertExists()
        compose.onNode(hasSetTextAction()).performTextInput("123456")
        compose.onNodeWithContentDescription("OK").performClick()
        compose.runOnIdle { assertEquals(PromptResponse.StringResponse("123456"), response) }
        compose.onNodeWithContentDescription("Cancel").performClick()
        compose.runOnIdle { assertEquals(true, cancelled) }
    }
}
