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

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.connectbot.data.entity.Host
import org.connectbot.ui.screens.login.LoginScreenContent
import org.connectbot.ui.theme.ConnectBotTheme
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class LoginScreenTest {
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val compose = createAndroidComposeRule<HiltComponentActivity>()

    @Before fun setup() {
        hiltRule.inject()
    }

    @Test fun setupSelectsSavedServerWithoutRegisteringAnything() {
        var chosen: Long? = null
        compose.setContent {
            ConnectBotTheme {
                LoginScreenContent(listOf(Host(id = 7, nickname = "my server", hostname = "example", username = "alice")), {}, { chosen = it }, {}, {})
            }
        }
        compose.onNodeWithText(compose.activity.getString(R.string.login_setup)).performClick()
        compose.onNodeWithText("my server").performClick()
        assertEquals(7L, chosen)
    }

    @Test fun keyAndAccountManagementRemainDiscoverable() {
        compose.setContent { ConnectBotTheme { LoginScreenContent(emptyList(), {}, {}, {}, {}) } }
        compose.onNodeWithText(compose.activity.getString(R.string.login_keys)).assertIsDisplayed()
        compose.onNodeWithText(compose.activity.getString(R.string.identities_title)).assertIsDisplayed()
    }
}
