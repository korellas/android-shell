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

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo.SCREEN_ORIENTATION_BEHIND
import android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
import android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
import android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR
import android.view.View
import android.view.ViewGroup
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.SoftwareKeyboardController
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.NavType
import androidx.navigation.compose.ComposeNavigator
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.testing.TestNavHostController
import androidx.preference.PreferenceManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import org.connectbot.data.entity.Host
import org.connectbot.service.ModifierLevel
import org.connectbot.service.ModifierState
import org.connectbot.service.PromptManager
import org.connectbot.service.TerminalBridge
import org.connectbot.service.TerminalKeyListener
import org.connectbot.service.TerminalManager
import org.connectbot.terminal.DelKeyMode
import org.connectbot.terminal.ProgressState
import org.connectbot.terminal.TerminalDimensions
import org.connectbot.terminal.TerminalEmulator
import org.connectbot.terminal.TerminalEmulatorFactory
import org.connectbot.ui.LocalTerminalManager
import org.connectbot.ui.navigation.navigateToConsole
import org.connectbot.ui.navigation.safePopBackStack
import org.connectbot.ui.screens.console.ConsoleScreen
import org.connectbot.ui.screens.console.ConsoleUiState
import org.connectbot.ui.screens.console.ConsoleViewModel
import org.connectbot.ui.theme.ConnectBotTheme
import org.connectbot.util.PreferenceConstants
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Ignore
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class ConsoleScreenTest {
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<HiltComponentActivity>()

    private lateinit var navController: TestNavHostController

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @After
    fun tearDown() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit().clear().commit()
    }

    private fun setContent(
        mockTerminalManager: TerminalManager? = null,
        mockConsoleViewModel: ConsoleViewModel? = null,
        lifecycleOwner: LifecycleOwner = composeTestRule.activity,
        onAutomaticBack: () -> Unit = {},
        keyboardController: SoftwareKeyboardController? = null,
    ) {
        composeTestRule.setContent {
            val context = LocalContext.current
            navController = remember {
                TestNavHostController(context).apply {
                    navigatorProvider.addNavigator(ComposeNavigator())
                }
            }
            ConnectBotTheme {
                CompositionLocalProvider(
                    LocalTerminalManager provides mockTerminalManager,
                    LocalLifecycleOwner provides lifecycleOwner,
                    LocalSoftwareKeyboardController provides (keyboardController ?: LocalSoftwareKeyboardController.current),
                ) {
                    NavHost(navController = navController, startDestination = "start") {
                        composable("start") { Text("Host list") }
                        composable(
                            route = "console/{hostId}",
                            arguments = listOf(navArgument("hostId") { type = NavType.LongType }),
                        ) {
                            if (mockConsoleViewModel != null) {
                                ConsoleScreen(
                                    onNavigateBack = {
                                        onAutomaticBack()
                                        navController.safePopBackStack()
                                    },
                                    onNavigateToPortForwards = {},
                                    viewModel = mockConsoleViewModel,
                                )
                            } else {
                                ConsoleScreen(
                                    onNavigateBack = {
                                        onAutomaticBack()
                                        navController.safePopBackStack()
                                    },
                                    onNavigateToPortForwards = {},
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private fun navigateToConsoleScreen(hostId: Long = -1L) {
        composeTestRule.runOnUiThread {
            navController.navigate("console/$hostId")
        }
    }

    @Test
    fun notificationNavigation_switchesSessionsWithoutReusingTheirViewModelEntry() {
        composeTestRule.setContent {
            val context = LocalContext.current
            navController = remember {
                TestNavHostController(context).apply {
                    navigatorProvider.addNavigator(ComposeNavigator())
                }
            }
            NavHost(navController, startDestination = "start") {
                composable("start") {}
                composable(
                    "console/{hostId}?keySetup={keySetup}",
                    arguments = listOf(
                        navArgument("hostId") { type = NavType.LongType },
                        navArgument("keySetup") {
                            type = NavType.BoolType
                            defaultValue = false
                        },
                    ),
                ) {}
            }
        }
        composeTestRule.runOnIdle {
            navController.navigateToConsole(-1L)
            val firstEntry = navController.currentBackStackEntry!!.id
            navController.navigateToConsole(-2L)
            val secondEntry = navController.currentBackStackEntry!!.id
            assertFalse(firstEntry == secondEntry)
            assertEquals(-2L, navController.currentBackStackEntry!!.arguments!!.getLong("hostId"))
            navController.navigateToConsole(-2L)
            assertEquals(secondEntry, navController.currentBackStackEntry!!.id)
            navController.popBackStack()
            assertEquals(firstEntry, navController.currentBackStackEntry!!.id)
        }
    }

    @Test
    fun consoleScreen_emptyOnEntry_returnsToHostList() {
        val viewModel = mock(ConsoleViewModel::class.java)
        `when`(viewModel.uiState).thenReturn(MutableStateFlow(ConsoleUiState(isLoading = false)))
        `when`(viewModel.networkStatusMessages).thenReturn(MutableSharedFlow())
        setContent(mockConsoleViewModel = viewModel)
        navigateToConsoleScreen()

        composeTestRule.onNodeWithText("Host list").assertIsDisplayed()
        composeTestRule.runOnIdle {
            assertEquals("start", navController.currentDestination?.route)
        }
    }

    @Test
    fun consoleScreen_disconnectInBackground_navigatesAfterResumeDispatch() {
        val owner = object : LifecycleOwner {
            override val lifecycle = LifecycleRegistry(this)
        }
        val states = MutableStateFlow(ConsoleUiState())
        val viewModel = mock(ConsoleViewModel::class.java)
        `when`(viewModel.uiState).thenReturn(states)
        `when`(viewModel.networkStatusMessages).thenReturn(MutableSharedFlow())
        var dispatchingResume = false
        var backCount = 0
        composeTestRule.runOnUiThread {
            owner.lifecycle.currentState = Lifecycle.State.RESUMED
        }
        setContent(
            mockConsoleViewModel = viewModel,
            lifecycleOwner = owner,
            onAutomaticBack = {
                assertFalse("Navigation must run after lifecycle dispatch", dispatchingResume)
                backCount++
            },
        )
        navigateToConsoleScreen()
        composeTestRule.waitForIdle()
        composeTestRule.runOnUiThread {
            owner.lifecycle.currentState = Lifecycle.State.CREATED
            states.value = ConsoleUiState(isLoading = false)
        }
        composeTestRule.runOnIdle {
            assertEquals(0, backCount)
            assertEquals("console/{hostId}", navController.currentDestination?.route)
        }
        composeTestRule.runOnUiThread {
            dispatchingResume = true
            owner.lifecycle.currentState = Lifecycle.State.RESUMED
            dispatchingResume = false
        }
        composeTestRule.onNodeWithText("Host list").assertIsDisplayed()
        composeTestRule.runOnIdle {
            assertEquals(1, backCount)
            assertEquals("start", navController.currentDestination?.route)
        }
    }

    @Test
    fun consoleScreen_doesNotWarnAboutConnectionsWhenAlertsAreOff() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.CONNECTION_ALERTS, false)
            .putBoolean(PreferenceConstants.NOTIFICATION_PERMISSION_DENIED, true)
            .commit()
        setContent()
        navigateToConsoleScreen()
        composeTestRule.onNodeWithText("Connection may drop in background").assertDoesNotExist()
    }

    @Test
    fun consoleScreen_hidesTopAppBar_whenPreferenceSet() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.TITLEBARHIDE, true)
            .commit()

        setContent()
        navigateToConsoleScreen()

        composeTestRule.onNodeWithTag("top_app_bar").assertIsNotDisplayed()
    }

    @Test
    fun consoleScreen_displaysTopAppBarByDefault() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule
            .onNodeWithTag("top_app_bar")
            .assertIsDisplayed()
    }

    @Test
    fun consoleScreen_titleBarIsCompactWithOptionsAtRightEdge() {
        setContent()
        navigateToConsoleScreen()

        val bar = composeTestRule.onNodeWithTag("top_app_bar")
        bar.assertHeightIsEqualTo(36.dp)
        val options = composeTestRule.onNodeWithContentDescription("More options")
        val back = composeTestRule.onNodeWithContentDescription("Back")
        val barBounds = bar.fetchSemanticsNode().boundsInRoot
        val optionsBounds = options.fetchSemanticsNode().boundsInRoot
        assertEquals(barBounds.right, optionsBounds.right, 1f)
        assertTrue(back.fetchSemanticsNode().boundsInRoot.right <= optionsBounds.left)
    }

    @Test
    fun consoleScreen_fullscreenIsEnabledByDefault() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val prefs = PreferenceManager.getDefaultSharedPreferences(context)
        setContent()
        navigateToConsoleScreen()

        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Full screen").performClick()
        composeTestRule.runOnIdle {
            assertFalse(prefs.getBoolean(PreferenceConstants.FULLSCREEN, true))
        }
    }

    @Test
    fun consoleScreen_respectsSavedFullscreenOptOut() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.FULLSCREEN, false).commit()
        setContent()
        navigateToConsoleScreen()

        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Full screen").performClick()
        composeTestRule.runOnIdle {
            assertTrue(PreferenceManager.getDefaultSharedPreferences(context).getBoolean(PreferenceConstants.FULLSCREEN, false))
        }
    }

    @Test
    fun consoleScreen_displaysBackButton() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule
            .onNodeWithContentDescription("Back")
            .assertIsDisplayed()
    }

    @Test
    fun consoleScreen_backButtonNavigatesUp() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule
            .onNodeWithContentDescription("Back")
            .performClick()

        composeTestRule.runOnIdle {
            assertTrue(navController.currentBackStackEntry?.destination?.route == "start")
        }
    }

    private class RecordingKeyboardController : SoftwareKeyboardController {
        var visible = false
        override fun show() {
            visible = true
        }
        override fun hide() {
            visible = false
        }
    }

    @Test
    fun consoleScreen_backButtonHidesKeyboardBeforeNavigating() {
        val keyboard = RecordingKeyboardController()
        val viewModel = mock(ConsoleViewModel::class.java)
        `when`(viewModel.uiState).thenReturn(MutableStateFlow(ConsoleUiState()))
        `when`(viewModel.networkStatusMessages).thenReturn(MutableSharedFlow())
        var navigationCount = 0
        setContent(
            mockConsoleViewModel = viewModel,
            keyboardController = keyboard,
            onAutomaticBack = {
                assertFalse("Hide the keyboard before leaving the console", keyboard.visible)
                navigationCount++
            },
        )
        navigateToConsoleScreen()
        composeTestRule.runOnIdle { keyboard.show() }
        composeTestRule.onNodeWithContentDescription("Back").performClick()
        composeTestRule.onNodeWithText("Host list").assertIsDisplayed()
        composeTestRule.runOnIdle { assertEquals(1, navigationCount) }
    }

    @Test
    fun consoleScreen_lastSessionClosedHidesKeyboardBeforeNavigating() {
        val keyboard = RecordingKeyboardController()
        val states = MutableStateFlow(ConsoleUiState())
        val viewModel = mock(ConsoleViewModel::class.java)
        `when`(viewModel.uiState).thenReturn(states)
        `when`(viewModel.networkStatusMessages).thenReturn(MutableSharedFlow())
        var navigationCount = 0
        setContent(
            mockConsoleViewModel = viewModel,
            keyboardController = keyboard,
            onAutomaticBack = {
                assertFalse("Hide the keyboard before leaving the console", keyboard.visible)
                navigationCount++
            },
        )
        navigateToConsoleScreen()
        composeTestRule.runOnIdle {
            keyboard.show()
            states.value = ConsoleUiState(isLoading = false)
        }
        composeTestRule.onNodeWithText("Host list").assertIsDisplayed()
        composeTestRule.runOnIdle { assertEquals(1, navigationCount) }
    }

    @Test
    fun consoleScreen_textInputIsAvailableInOptionsMenu() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule.onNodeWithText("Text input").assertDoesNotExist()
        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Text input").assertIsDisplayed()
    }

    @Test
    fun consoleScreen_pasteIsAvailableInOptionsMenu() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule.onNodeWithContentDescription("Paste").assertDoesNotExist()
        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Paste").assertIsDisplayed()
    }

    private fun showInteractiveConsole(disconnected: Boolean = false): TerminalBridge {
        val bridge = mock(TerminalBridge::class.java)
        `when`(bridge.host).thenReturn(Host(id = 23, nickname = "my-server", hostname = "example.org"))
        `when`(bridge.isDisconnected).thenReturn(disconnected)
        val viewModel = mock(ConsoleViewModel::class.java)
        // Leave terminal rendering to the library; exercise the app's chrome and actions.
        `when`(viewModel.uiState).thenReturn(MutableStateFlow(ConsoleUiState(bridges = listOf(bridge), isLoading = true)))
        `when`(viewModel.networkStatusMessages).thenReturn(MutableSharedFlow())
        setContent(mockConsoleViewModel = viewModel)
        navigateToConsoleScreen()
        return bridge
    }

    @Test
    fun multilinePasteSendsDirectlyWithoutOpeningEditor() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("commands", "echo 한글\npwd\n"))
        val bridge = showInteractiveConsole()
        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Paste").performClick()
        composeTestRule.onNodeWithText("echo 한글\npwd\n").assertDoesNotExist()
        composeTestRule.runOnIdle { verify(bridge).injectString("echo 한글\npwd\n") }
    }

    @Test
    fun editAndPasteOpensClipboardInEditorWithoutSending() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("commands", "echo 한글\npwd\n"))
        val bridge = showInteractiveConsole()
        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Edit and paste").performClick()
        composeTestRule.onNodeWithText("echo 한글\npwd\n").assertIsDisplayed()
        verify(bridge, never()).injectString("echo 한글\npwd\n")
    }

    @Test
    fun singleLinePasteSendsDirectly() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("path", "/tmp/한글"))
        val bridge = showInteractiveConsole()
        composeTestRule.onNodeWithContentDescription("More options").performClick()
        composeTestRule.onNodeWithText("Paste").performClick()
        composeTestRule.runOnIdle { verify(bridge).injectString("/tmp/한글") }
    }

    @Test
    fun sessionTitleOpensDrawerAndConnectedCloseNeedsConfirmation() {
        val bridge = showInteractiveConsole()
        composeTestRule.onNodeWithTag("session_title").performClick()
        composeTestRule.onNodeWithText("example.org:22").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Close my-server").performClick()
        verify(bridge, never()).dispatchDisconnect(org.connectbot.service.DisconnectReason.USER_REQUESTED)
        composeTestRule.onNodeWithText("Yes").performClick()
        composeTestRule.runOnIdle { verify(bridge).dispatchDisconnect(org.connectbot.service.DisconnectReason.USER_REQUESTED) }
    }

    @Test
    fun disconnectedSessionClosesWithoutConfirmation() {
        val bridge = showInteractiveConsole(disconnected = true)
        composeTestRule.onNodeWithTag("session_title").performClick()
        composeTestRule.onNodeWithContentDescription("Close my-server").performClick()
        composeTestRule.runOnIdle { verify(bridge).dispatchDisconnect(org.connectbot.service.DisconnectReason.USER_REQUESTED) }
        composeTestRule.onNodeWithText("Yes").assertDoesNotExist()
    }

    @Test
    @Ignore("rotation is disabled until stability is addressed")
    fun consoleScreen_setsLandscapeOrientation_whenPreferenceSet() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit().putString(
            PreferenceConstants.ROTATION,
            PreferenceConstants.ROTATION_LANDSCAPE,
        ).commit()

        setContent()
        navigateToConsoleScreen()

        composeTestRule.runOnIdle {
            assertEquals(SCREEN_ORIENTATION_LANDSCAPE, composeTestRule.activity.requestedOrientation)
        }
    }

    @Test
    @Ignore("rotation is disabled until stability is addressed")
    fun consoleScreen_setsPortraitOrientation_whenPreferenceSet() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit().putString(
            PreferenceConstants.ROTATION,
            PreferenceConstants.ROTATION_PORTRAIT,
        ).commit()

        setContent()
        navigateToConsoleScreen()

        composeTestRule.runOnIdle {
            assertEquals(SCREEN_ORIENTATION_PORTRAIT, composeTestRule.activity.requestedOrientation)
        }
    }

    @Test
    @Ignore("rotation is disabled until stability is addressed")
    fun consoleScreen_setsSensorOrientation_whenAutoPreferenceSet() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit().putString(
            PreferenceConstants.ROTATION,
            PreferenceConstants.ROTATION_AUTO,
        ).commit()

        setContent()
        navigateToConsoleScreen()

        composeTestRule.runOnIdle {
            assertEquals(SCREEN_ORIENTATION_SENSOR, composeTestRule.activity.requestedOrientation)
        }
    }

    @Test
    @Ignore("rotation is disabled until stability is addressed")
    fun consoleScreen_setsPortraitOrientation_whenDefaultPreferenceAndNoHardwareKeyboard() {
        setContent()
        navigateToConsoleScreen()

        composeTestRule.runOnIdle {
            assertEquals(SCREEN_ORIENTATION_PORTRAIT, composeTestRule.activity.requestedOrientation)
        }
    }

    @Test
    @Ignore("rotation is disabled until stability is addressed")
    fun consoleScreen_restoresOriginalOrientation_onNavigateBack() {
        // Set an initial orientation that's different from what ConsoleScreen might set
        composeTestRule.runOnUiThread {
            composeTestRule.activity.requestedOrientation = SCREEN_ORIENTATION_BEHIND
        }

        setContent()
        navigateToConsoleScreen()

        // Verify orientation changed
        composeTestRule.runOnIdle {
            // Default rotation is portrait (without keyboard in tests)
            assertEquals(SCREEN_ORIENTATION_PORTRAIT, composeTestRule.activity.requestedOrientation)
        }

        // Navigate back
        composeTestRule
            .onNodeWithContentDescription("Back")
            .performClick()

        // Verify orientation restored
        composeTestRule.runOnIdle {
            assertEquals(SCREEN_ORIENTATION_BEHIND, composeTestRule.activity.requestedOrientation)
        }
    }

    @Test
    fun consoleScreen_keepsScreenAwake_whenPreferenceEnabledAndConnectionActive() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.KEEP_ALIVE, true)
            .commit()

        val mockViewModel = mock(ConsoleViewModel::class.java)
        val mockBridge = mock(TerminalBridge::class.java)
        `when`(mockBridge.isDisconnected).thenReturn(false)

        val uiStateFlow = MutableStateFlow(
            ConsoleUiState(
                bridges = listOf(mockBridge),
                currentBridgeIndex = 0,
                isLoading = true,
            ),
        )
        val networkStatusMessages = MutableSharedFlow<String>()

        `when`(mockViewModel.uiState).thenReturn(uiStateFlow)
        `when`(mockViewModel.networkStatusMessages).thenReturn(networkStatusMessages)

        setContent(mockConsoleViewModel = mockViewModel)
        navigateToConsoleScreen(hostId = 1L)

        composeTestRule.runOnIdle {
            val rootLayout = composeTestRule.activity.findViewById<View>(android.R.id.content)
            assertTrue("Screen should be kept awake", hasKeepScreenOn(rootLayout))
        }
    }

    @Test
    fun consoleScreen_doesNotKeepScreenAwake_whenPreferenceDisabled() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.KEEP_ALIVE, false)
            .commit()

        val mockViewModel = mock(ConsoleViewModel::class.java)
        val mockBridge = mock(TerminalBridge::class.java)
        `when`(mockBridge.isDisconnected).thenReturn(false)

        val uiStateFlow = MutableStateFlow(
            ConsoleUiState(
                bridges = listOf(mockBridge),
                currentBridgeIndex = 0,
                isLoading = true,
            ),
        )
        val networkStatusMessages = MutableSharedFlow<String>()

        `when`(mockViewModel.uiState).thenReturn(uiStateFlow)
        `when`(mockViewModel.networkStatusMessages).thenReturn(networkStatusMessages)

        setContent(mockConsoleViewModel = mockViewModel)
        navigateToConsoleScreen(hostId = 1L)

        composeTestRule.runOnIdle {
            val rootLayout = composeTestRule.activity.findViewById<View>(android.R.id.content)
            assertFalse("Screen should not be kept awake when preference is disabled", hasKeepScreenOn(rootLayout))
        }
    }

    @Test
    fun consoleScreen_doesNotKeepScreenAwake_whenDisconnected() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        PreferenceManager.getDefaultSharedPreferences(context).edit()
            .putBoolean(PreferenceConstants.KEEP_ALIVE, true)
            .commit()

        val mockViewModel = mock(ConsoleViewModel::class.java)
        val mockBridge = mock(TerminalBridge::class.java)
        `when`(mockBridge.isDisconnected).thenReturn(true)

        val uiStateFlow = MutableStateFlow(
            ConsoleUiState(
                bridges = listOf(mockBridge),
                currentBridgeIndex = 0,
                isLoading = true,
            ),
        )
        val networkStatusMessages = MutableSharedFlow<String>()

        `when`(mockViewModel.uiState).thenReturn(uiStateFlow)
        `when`(mockViewModel.networkStatusMessages).thenReturn(networkStatusMessages)

        setContent(mockConsoleViewModel = mockViewModel)
        navigateToConsoleScreen(hostId = 1L)

        composeTestRule.runOnIdle {
            val rootLayout = composeTestRule.activity.findViewById<View>(android.R.id.content)
            assertFalse("Screen should not be kept awake when disconnected", hasKeepScreenOn(rootLayout))
        }
    }

    private fun hasKeepScreenOn(view: View): Boolean {
        if (view.keepScreenOn) return true
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                if (hasKeepScreenOn(view.getChildAt(i))) return true
            }
        }
        return false
    }
}
