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

package org.connectbot.ui.components

import android.view.HapticFeedbackConstants
import android.view.ViewConfiguration
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.KeyboardHide
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.preference.PreferenceManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.connectbot.R
import org.connectbot.service.ModifierLevel
import org.connectbot.service.ModifierState
import org.connectbot.service.TerminalBridge
import org.connectbot.service.TerminalKeyListener
import org.connectbot.terminal.VTermKey
import org.connectbot.util.PreferenceConstants
import org.connectbot.util.TerminalBarKey
import org.connectbot.util.TerminalBarLayout

private const val UI_OPACITY = 1f

/**
 * Height of the virtual keyboard keys in dp.
 */
const val TERMINAL_KEYBOARD_HEIGHT_DP = 36

/**
 * Width of the virtual keyboard keys in dp.
 */
private const val TERMINAL_KEYBOARD_WIDTH_DP = 40

/**
 * Size of the content (icons and text) for the virtual keyboard keys in dp.
 */
private const val TERMINAL_KEYBOARD_CONTENT_SIZE_DP = 18

/**
 * Virtual keyboard with terminal special keys (Ctrl, Esc, arrows, function keys, etc.)
 * Positioned at bottom of console screen, horizontally scrollable
 * Auto-hide timer is managed by parent ConsoleScreen
 */
@Composable
fun TerminalKeyboard(
    bridge: TerminalBridge,
    onInteraction: () -> Unit,
    modifier: Modifier = Modifier,
    onHideIme: () -> Unit = {},
    onShowIme: () -> Unit = {},
    onScrollInProgressChange: (Boolean) -> Unit = {},
    imeVisible: Boolean = false,
    playAnimation: Boolean = false,
    showImeToggleKey: Boolean = true,
    isComposeModeActive: Boolean = false,
    onToggleComposeMode: () -> Unit = {},
    onShortcutModifierChange: () -> Unit = {},
) {
    val context = LocalContext.current
    val prefs = remember { PreferenceManager.getDefaultSharedPreferences(context) }
    val keyHandler = bridge.keyHandler
    val modifierState by keyHandler.modifierState.collectAsState()
    val bumpyArrows by remember {
        mutableStateOf(prefs.getBoolean(PreferenceConstants.BUMPY_ARROWS, false))
    }

    TerminalKeyboardContent(
        modifierState = modifierState,
        onCtrlPress = {
            keyHandler.metaPress(TerminalKeyListener.CTRL_ON, true)
            onShortcutModifierChange()
            onInteraction()
        },
        onAltPress = {
            keyHandler.metaPress(TerminalKeyListener.ALT_ON, true)
            onShortcutModifierChange()
            onInteraction()
        },
        onEscPress = {
            keyHandler.sendEscape()
            onInteraction()
        },
        onTabPress = {
            keyHandler.sendTab()
            onInteraction()
        },
        onKeyPress = { key ->
            keyHandler.sendPressedKey(key)
            onInteraction()
        },
        onInteraction = onInteraction,
        onHideIme = onHideIme,
        onShowIme = onShowIme,
        onScrollInProgressChange = onScrollInProgressChange,
        imeVisible = imeVisible,
        playAnimation = playAnimation,
        bumpyArrows = bumpyArrows,
        showImeToggleKey = showImeToggleKey,
        isComposeModeActive = isComposeModeActive,
        onToggleComposeMode = onToggleComposeMode,
        layout = TerminalBarLayout.load(prefs),
        modifier = modifier,
    )
}

/**
 * Stateless UI component for the terminal keyboard.
 * Separated from [TerminalKeyboard] to enable preview without TerminalBridge dependency.
 */
@Composable
internal fun TerminalKeyboardContent(
    modifierState: ModifierState,
    onCtrlPress: () -> Unit,
    onAltPress: () -> Unit,
    onEscPress: () -> Unit,
    onTabPress: () -> Unit,
    onKeyPress: (Int) -> Unit,
    onInteraction: () -> Unit,
    onHideIme: () -> Unit,
    onShowIme: () -> Unit,
    onScrollInProgressChange: (Boolean) -> Unit,
    imeVisible: Boolean,
    playAnimation: Boolean,
    bumpyArrows: Boolean,
    modifier: Modifier = Modifier,
    showImeToggleKey: Boolean = true,
    isComposeModeActive: Boolean = false,
    onToggleComposeMode: () -> Unit = {},
    layout: TerminalBarLayout = TerminalBarLayout(),
) {
    var functionMode by rememberSaveable { mutableStateOf(false) }
    val hasFn = layout.groupFunctionKeys && TerminalBarKey.FUNCTION_KEYS in layout.visibleKeys
    val scrollState = rememberScrollState()
    val currentOnScrollInProgressChange by rememberUpdatedState(onScrollInProgressChange)
    val view = LocalView.current

    if (bumpyArrows) {
        view.isHapticFeedbackEnabled = true
    }

    // Notify parent when scroll state changes
    LaunchedEffect(scrollState.isScrollInProgress) {
        currentOnScrollInProgressChange(scrollState.isScrollInProgress)
    }

    LaunchedEffect(functionMode) { scrollState.scrollTo(0) }

    // Auto-scroll animation on first appearance (only if playAnimation is true)
    LaunchedEffect(playAnimation) {
        if (playAnimation) {
            // Wait a moment for layout to complete
            delay(100)

            // Scroll all the way to the right to show all keys
            scrollState.animateScrollTo(
                value = scrollState.maxValue,
                animationSpec = tween(durationMillis = 500),
            )

            // Then scroll back to the left
            delay(300)
            scrollState.animateScrollTo(
                value = 0,
                animationSpec = tween(durationMillis = 500),
            )
        }
    }

    Surface(
        modifier = modifier
            .pointerInput(Unit) {
                // Reset timer on any touch interaction
                detectTapGestures(
                    onPress = {
                        onInteraction()
                        tryAwaitRelease()
                    },
                )
            },
        color = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().height(layout.height.dp).padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            androidx.compose.runtime.CompositionLocalProvider(LocalKeyHeight provides layout.keyHeight) {
                KeyButton(
                    text = stringResource(R.string.button_key_esc),
                    contentDescription = stringResource(R.string.image_description_send_escape_character),
                    onClick = onEscPress,
                )
                KeyButton(
                    text = "⇥",
                    width = 34,
                    contentDescription = stringResource(R.string.image_description_send_tab_character),
                    onClick = onTabPress,
                )
                ModifierKeyButton(
                    text = stringResource(R.string.button_key_ctrl),
                    contentDescription = stringResource(R.string.image_description_toggle_control_character),
                    modifierLevel = modifierState.ctrlState,
                    onClick = onCtrlPress,
                )
                Spacer(Modifier.width(1.dp).height(18.dp).background(MaterialTheme.colorScheme.outlineVariant))
                Row(
                    modifier = Modifier.weight(1f).horizontalScroll(scrollState).testTag("terminal_bar_scroll"),
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    if (hasFn && functionMode) {
                        FunctionKeys(onKeyPress)
                    } else {
                        layout.visibleKeys.forEach { key ->
                            when (key) {
                                TerminalBarKey.ALT -> ModifierKeyButton(
                                    text = stringResource(R.string.button_key_alt),
                                    contentDescription = stringResource(R.string.image_description_toggle_alt_key),
                                    modifierLevel = modifierState.altState,
                                    onClick = onAltPress,
                                )

                                TerminalBarKey.UP, TerminalBarKey.DOWN, TerminalBarKey.LEFT, TerminalBarKey.RIGHT -> {
                                    val icon = when (key) {
                                        TerminalBarKey.UP -> Icons.Default.KeyboardArrowUp
                                        TerminalBarKey.DOWN -> Icons.Default.KeyboardArrowDown
                                        TerminalBarKey.LEFT -> Icons.Default.KeyboardArrowLeft
                                        else -> Icons.Default.KeyboardArrowRight
                                    }
                                    val description = when (key) {
                                        TerminalBarKey.UP -> R.string.image_description_up
                                        TerminalBarKey.DOWN -> R.string.image_description_down
                                        TerminalBarKey.LEFT -> R.string.image_description_left
                                        else -> R.string.image_description_right
                                    }
                                    RepeatableKeyButton(
                                        icon = icon,
                                        contentDescription = stringResource(description),
                                        onPress = {
                                            onKeyPress(key.terminalCode())
                                            if (bumpyArrows) view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                                        },
                                    )
                                }

                                TerminalBarKey.FUNCTION_KEYS -> if (!hasFn) FunctionKeys(onKeyPress)

                                else -> KeyButton(
                                    text = key.label,
                                    contentDescription = null,
                                    width = if (key == TerminalBarKey.HOME || key == TerminalBarKey.PAGE_UP || key == TerminalBarKey.PAGE_DOWN) 44 else 40,
                                    onClick = { onKeyPress(key.terminalCode()) },
                                )
                            }
                        }
                    }
                }
                KeyButton(
                    icon = if (imeVisible) Icons.Default.KeyboardHide else Icons.Default.Keyboard,
                    contentDescription = stringResource(
                        if (imeVisible) R.string.image_description_hide_keyboard else R.string.image_description_show_keyboard,
                    ),
                    width = 36,
                    onClick = {
                        if (imeVisible) onHideIme() else onShowIme()
                        onInteraction()
                    },
                )
                if (hasFn) {
                    KeyButton(
                        text = "Fn",
                        contentDescription = stringResource(R.string.terminal_bar_function_keys),
                        width = 36,
                        modifier = Modifier.semantics { selected = functionMode },
                        backgroundColor = if (functionMode) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondaryContainer,
                        tint = if (functionMode) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSecondaryContainer,
                        onClick = {
                            functionMode = !functionMode
                            onInteraction()
                        },
                    )
                }
            }
        }
    }
}

private val LocalKeyHeight = androidx.compose.runtime.compositionLocalOf { 28 }

@Composable
private fun FunctionKeys(onKeyPress: (Int) -> Unit) {
    for (number in 1..12) {
        KeyButton(text = "F$number", width = 34, contentDescription = null, onClick = { onKeyPress(VTermKey.FUNCTION_0 + number) })
    }
}

private fun TerminalBarKey.terminalCode(): Int = when (this) {
    TerminalBarKey.UP -> VTermKey.UP
    TerminalBarKey.DOWN -> VTermKey.DOWN
    TerminalBarKey.LEFT -> VTermKey.LEFT
    TerminalBarKey.RIGHT -> VTermKey.RIGHT
    TerminalBarKey.HOME -> VTermKey.HOME
    TerminalBarKey.END -> VTermKey.END
    TerminalBarKey.PAGE_UP -> VTermKey.PAGEUP
    TerminalBarKey.PAGE_DOWN -> VTermKey.PAGEDOWN
    TerminalBarKey.INSERT -> VTermKey.INS
    TerminalBarKey.DELETE -> VTermKey.DEL
    else -> error("Modifier and function groups are not individual terminal keys")
}

/**
 * A button for single-press keys (Ctrl, Esc, Tab, Home, End, PgUp, PgDn, F1-F12)
 */
@Composable
private fun KeyButton(
    contentDescription: String?,
    modifier: Modifier = Modifier,
    text: String? = null,
    icon: ImageVector? = null,
    onClick: (() -> Unit)? = null,
    backgroundColor: Color = MaterialTheme.colorScheme.surfaceContainerHigh,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    width: Int = TERMINAL_KEYBOARD_WIDTH_DP,
) {
    val surfaceModifier = modifier
        .size(width = width.dp, height = LocalKeyHeight.current.dp)
        .semantics { if (contentDescription != null) this.contentDescription = contentDescription }

    val content: @Composable () -> Unit = {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.fillMaxSize(),
        ) {
            if (text != null) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 12.sp),
                    color = tint,
                )
            } else if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.height(TERMINAL_KEYBOARD_CONTENT_SIZE_DP.dp),
                )
            }
        }
    }

    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = surfaceModifier,
            shape = RoundedCornerShape(6.dp),
            color = backgroundColor,
            content = content,
        )
    } else {
        Surface(
            modifier = surfaceModifier,
            shape = RoundedCornerShape(6.dp),
            color = backgroundColor,
            content = content,
        )
    }
}

/**
 * A button for repeatable keys (arrow keys)
 * Starts repeating after initial delay when held down
 */
@Composable
private fun RepeatableKeyButton(
    icon: ImageVector,
    contentDescription: String?,
    onPress: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val coroutineScope = rememberCoroutineScope()
    var isPressed by remember { mutableStateOf(false) }
    var repeatJob by remember { mutableStateOf<Job?>(null) }

    // Cleanup on unmount
    DisposableEffect(Unit) {
        onDispose {
            repeatJob?.cancel()
        }
    }

    val backgroundColor =
        if (isPressed) {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = UI_OPACITY)
        } else {
            MaterialTheme.colorScheme.surfaceContainerHigh
        }

    KeyButton(
        icon = icon,
        width = 32,
        contentDescription = contentDescription,
        onClick = null,
        modifier = modifier.pointerInput(Unit) {
            detectTapGestures(
                onPress = {
                    isPressed = true
                    var sentPress = false

                    // Start a job that handles initial delay, first press, and repeat
                    val tapTimeout = ViewConfiguration.getTapTimeout().toLong()
                    repeatJob = coroutineScope.launch {
                        // Delay before first press to allow scroll gestures to steal touch
                        delay(tapTimeout)
                        if (!isPressed) return@launch

                        // First press after initial tap delay
                        sentPress = true
                        onPress()

                        // Wait before starting repeat
                        delay(500 - tapTimeout)
                        while (isPressed) {
                            sentPress = true
                            onPress()
                            delay(50) // Repeat interval
                        }
                    }

                    // Wait for release - returns true if normal release, false if gesture stolen
                    val released = tryAwaitRelease()
                    isPressed = false

                    if (released && !sentPress) {
                        // User released but key hasn't been sent yet (quick tap) - send it now
                        repeatJob?.cancel()
                        onPress()
                    } else {
                        repeatJob?.cancel()
                    }
                },
            )
        },
        backgroundColor = backgroundColor,
    )
}

@Composable
private fun ModifierKeyButton(
    text: String,
    contentDescription: String?,
    modifierLevel: ModifierLevel,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val backgroundColor = when (modifierLevel) {
        ModifierLevel.OFF -> MaterialTheme.colorScheme.surfaceContainerHigh
        ModifierLevel.TRANSIENT -> MaterialTheme.colorScheme.secondaryContainer
        ModifierLevel.LOCKED -> MaterialTheme.colorScheme.primary
    }

    val textColor = when (modifierLevel) {
        ModifierLevel.OFF -> MaterialTheme.colorScheme.onSurface
        ModifierLevel.TRANSIENT -> MaterialTheme.colorScheme.onSecondaryContainer
        ModifierLevel.LOCKED -> MaterialTheme.colorScheme.onPrimary
    }

    KeyButton(
        text = text,
        contentDescription = contentDescription,
        onClick = onClick,
        modifier = modifier,
        backgroundColor = backgroundColor,
        tint = textColor,
    )
}

@Preview(name = "Terminal Keyboard - Default State", showBackground = true)
@Composable
private fun TerminalKeyboardPreview() {
    MaterialTheme {
        TerminalKeyboardContent(
            modifierState = ModifierState(
                ctrlState = ModifierLevel.OFF,
                altState = ModifierLevel.OFF,
                shiftState = ModifierLevel.OFF,
            ),
            onCtrlPress = {},
            onAltPress = {},
            onEscPress = {},
            onTabPress = {},
            onKeyPress = {},
            onInteraction = {},
            onHideIme = {},
            onShowIme = {},
            onScrollInProgressChange = {},
            imeVisible = false,
            playAnimation = false,
            bumpyArrows = false,
        )
    }
}

@Preview(name = "Terminal Keyboard - Ctrl Pressed", showBackground = true)
@Composable
private fun TerminalKeyboardCtrlPressedPreview() {
    MaterialTheme {
        TerminalKeyboardContent(
            modifierState = ModifierState(
                ctrlState = ModifierLevel.TRANSIENT,
                altState = ModifierLevel.OFF,
                shiftState = ModifierLevel.OFF,
            ),
            onCtrlPress = {},
            onAltPress = {},
            onEscPress = {},
            onTabPress = {},
            onKeyPress = {},
            onInteraction = {},
            onHideIme = {},
            onShowIme = {},
            onScrollInProgressChange = {},
            imeVisible = false,
            playAnimation = false,
            bumpyArrows = false,
        )
    }
}

@Preview(name = "Terminal Keyboard - Ctrl Locked", showBackground = true)
@Composable
private fun TerminalKeyboardCtrlLockedPreview() {
    MaterialTheme {
        TerminalKeyboardContent(
            modifierState = ModifierState(
                ctrlState = ModifierLevel.LOCKED,
                altState = ModifierLevel.OFF,
                shiftState = ModifierLevel.OFF,
            ),
            onCtrlPress = {},
            onAltPress = {},
            onEscPress = {},
            onTabPress = {},
            onKeyPress = {},
            onInteraction = {},
            onHideIme = {},
            onShowIme = {},
            onScrollInProgressChange = {},
            imeVisible = false,
            playAnimation = false,
            bumpyArrows = false,
        )
    }
}

@Preview(name = "Terminal Keyboard - IME Visible", showBackground = true)
@Composable
private fun TerminalKeyboardImeVisiblePreview() {
    MaterialTheme {
        TerminalKeyboardContent(
            modifierState = ModifierState(
                ctrlState = ModifierLevel.OFF,
                altState = ModifierLevel.OFF,
                shiftState = ModifierLevel.OFF,
            ),
            onCtrlPress = {},
            onAltPress = {},
            onEscPress = {},
            onTabPress = {},
            onKeyPress = {},
            onInteraction = {},
            onHideIme = {},
            onShowIme = {},
            onScrollInProgressChange = {},
            imeVisible = true,
            playAnimation = false,
            bumpyArrows = false,
        )
    }
}
