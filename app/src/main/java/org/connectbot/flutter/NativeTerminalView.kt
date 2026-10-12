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

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.view.View
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.exclude
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imeAnimationTarget
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.connectbot.service.DisconnectReason
import org.connectbot.terminal.ComposeController
import org.connectbot.terminal.ImeShortcutInputMode
import org.connectbot.terminal.SelectionController
import org.connectbot.terminal.Terminal
import org.connectbot.ui.components.InlinePrompt
import org.connectbot.ui.components.TerminalKeyboard
import org.connectbot.ui.screens.console.AUTO_HIDE_DELAY_MS
import org.connectbot.ui.screens.console.TerminalSelectionActions
import org.connectbot.ui.screens.console.handleConsoleShortcut
import org.connectbot.ui.screens.console.horizontalSwipeNavigation
import org.connectbot.ui.screens.console.tmuxWindowCommand
import org.connectbot.ui.theme.ConnectBotTheme
import org.connectbot.ui.theme.connectBotColorScheme
import org.connectbot.util.rememberTerminalTypefaceFromStoredValue

internal class NativeTerminalFactory(private val engine: AndroidShellEngine) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        check(engine.ready) { "앱 잠금을 먼저 해제하세요." }
        val id = ((args as Map<*, *>)["sessionId"] as Number).toLong()
        return NativeTerminalView(engine, id, viewId, (args["owner"] as String))
    }
}

@OptIn(ExperimentalLayoutApi::class)
internal class NativeTerminalView(private val engine: AndroidShellEngine, private val id: Long, private val viewId: Int, val routeOwner: String) :
    PlatformView,
    DefaultLifecycleObserver {
    val sessionId: Long get() = id
    private var active by mutableStateOf(engine.activeOwner == routeOwner && engine.activeSessionId == id)
    private val activity = engine.activity
    private val bridge = engine.bridge(id)
    private var selection by mutableStateOf<SelectionController?>(null)
    private var compose by mutableStateOf<ComposeController?>(null)
    val composeMode: Boolean get() = compose?.isComposeModeActive == true
    private var sizeOverride by mutableStateOf<Pair<Int, Int>?>(null)
    private var overrideSize by mutableStateOf(false)
    private var showKeyboard by mutableStateOf(activity.resources.configuration.keyboard == Configuration.KEYBOARD_NOKEYS)
    private var imeVisible by mutableStateOf(false)
    private var showExtraKeyboard by mutableStateOf(true)
    private var hasPlayedKeyboardAnimation by mutableStateOf(false)
    private var keyboardHideJob: Job? = null
    private var locked by mutableStateOf(!engine.ready)
    private var disposed = false
    private val textInputRequest: () -> Unit = {
        activity.runOnUiThread { if (!disposed && active && !locked) engine.requestTextInput(routeOwner, selection?.takeIf { it.isSelectionActive }?.copySelection().orEmpty()) }
    }
    private val view = ComposeView(activity).apply {
        setViewTreeLifecycleOwner(activity)
        setViewTreeViewModelStoreOwner(activity)
        setViewTreeSavedStateRegistryOwner(activity)
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindowOrReleasedFromPool)
        setContent {
            val focus = remember { FocusRequester() }
            val keyboard = LocalSoftwareKeyboardController.current
            val prompt by bridge.promptManager.promptState.collectAsState()
            val fontSize by bridge.fontSizeFlow.collectAsState()
            val delKey by bridge.delKeyModeFlow.collectAsState()
            val cursorColor by bridge.cursorColor.collectAsState()
            val settings by activity.settings.uiState.collectAsState()
            val profileFont by bridge.fontFamilyFlow.collectAsState()
            val appearance by bridge.colorAppearance.collectAsState()
            val typeface = rememberTerminalTypefaceFromStoredValue(profileFont ?: settings.fontFamily)
            val customColors = remember(appearance) {
                val (fg, bg, cursor) = appearance
                if ((bg == 0xff0e1216.toInt() && cursor == 0xff6fd8c4.toInt()) || (bg == 0xfff6f5f0.toInt() && cursor == 0xff0b7566.toInt())) {
                    null
                } else {
                    val background = Color(bg)
                    val foreground = Color(fg)
                    connectBotColorScheme(activity, background.red + background.green + background.blue < 1.5f, false).copy(
                        primary = Color(cursor), onPrimary = background, primaryContainer = lerp(background, Color(cursor), .18f), onPrimaryContainer = Color(cursor),
                        background = background, surface = background, onSurface = foreground, onBackground = foreground,
                        surfaceContainerLow = lerp(background, foreground, .04f), surfaceContainer = lerp(background, foreground, .04f),
                        surfaceContainerHigh = lerp(background, foreground, .08f), surfaceContainerHighest = lerp(background, foreground, .13f), outlineVariant = lerp(background, foreground, .15f),
                    )
                }
            }
            ConnectBotTheme(themeMode = settings.themeMode, dynamicColor = false, overrideColorScheme = customColors) {
                val imeInsets = if (settings.fullscreen) {
                    WindowInsets.imeAnimationTarget
                } else {
                    WindowInsets.imeAnimationTarget.exclude(WindowInsets.navigationBars)
                }
                Box(Modifier.fillMaxSize().windowInsetsPadding(imeInsets)) {
                    Terminal(
                        terminalEmulator = bridge.terminalEmulator,
                        cursorColor = cursorColor,
                        modifier = Modifier.fillMaxSize().padding(horizontal = settings.terminalMargin.dp).padding(bottom = if (settings.alwaysvisible) settings.terminalBarLayout.height.dp else 0.dp).then(
                            if (settings.swipeSessions || settings.swipeTmux) {
                                Modifier.horizontalSwipeNavigation(
                                    bridgeId = this@NativeTerminalView.id,
                                    selectionActive = selection?.isSelectionActive == true,
                                    onSwipe = { direction ->
                                        if (settings.swipeSessions) {
                                            engine.switchSession(routeOwner, this@NativeTerminalView.id, direction)
                                        } else if (bridge.isSessionOpen) {
                                            bridge.injectString(tmuxWindowCommand(direction, settings.tmuxCtrlA))
                                        }
                                    },
                                    onInteraction = {},
                                )
                            } else {
                                Modifier
                            },
                        ),
                        typeface = typeface,
                        initialFontSize = fontSize.sp,
                        keyboardEnabled = !locked && active,
                        showSoftKeyboard = showKeyboard && !locked && active,
                        focusRequester = focus,
                        forcedSize = if (overrideSize) {
                            sizeOverride
                        } else if (bridge.profileForceSizeRows != null && bridge.profileForceSizeColumns != null) {
                            Pair(bridge.profileForceSizeRows!!, bridge.profileForceSizeColumns!!)
                        } else {
                            null
                        },
                        modifierManager = bridge.keyHandler,
                        delKeyMode = delKey,
                        onSelectionControllerAvailable = { selection = it },
                        onComposeControllerAvailable = {
                            compose = it
                            it.syncImeShortcutInputMode(settings.imeShortcutInputMode)
                        },
                        onTerminalTap = {
                            showKeyboard = true
                            keyboardInteraction()
                            focus.requestFocus()
                        },
                        onImeVisibilityChanged = { imeVisible = it },
                        onHyperlinkClick = { url -> openUrl(url) },
                        onPasteRequest = { paste() },
                        onInterceptKey = { event ->
                            handleConsoleShortcut(
                                event,
                                settings.volumefont,
                                copySelection = { selection?.copySelection() },
                                pasteClipboardContents = { paste() },
                                increaseFontSize = { bridge.increaseFontSize() },
                                decreaseFontSize = { bridge.decreaseFontSize() },
                            )
                        },
                        onPageGesture = if (settings.pgupdngesture) { key -> bridge.keyHandler.sendPressedKey(key) } else null,
                    )

                    if (composeMode && active && !locked && prompt == null) {
                        Surface(
                            modifier = Modifier.align(Alignment.BottomStart).padding(start = 10.dp, bottom = (if (showExtraKeyboard) settings.terminalBarLayout.height else 0).dp + 12.dp),
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.secondaryContainer,
                        ) {
                            Text("조합 모드 · Enter로 보내기", modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp), style = MaterialTheme.typography.labelMedium)
                        }
                    }
                    if (active && !locked) {
                        AnimatedVisibility(
                            visible = showExtraKeyboard,
                            enter = fadeIn(animationSpec = tween(durationMillis = 100)),
                            exit = fadeOut(animationSpec = tween(durationMillis = 100)),
                            modifier = Modifier.align(Alignment.BottomCenter),
                        ) {
                            TerminalKeyboard(
                                bridge = bridge,
                                onInteraction = { keyboardInteraction() },
                                onHideIme = {
                                    showKeyboard = false
                                    keyboard?.hide()
                                },
                                onShowIme = {
                                    showKeyboard = true
                                    focus.requestFocus()
                                },
                                onScrollInProgressChange = { keyboardInteraction(it) },
                                imeVisible = imeVisible,
                                playAnimation = !hasPlayedKeyboardAnimation,
                                showImeToggleKey = settings.imeTogglekey,
                                isComposeModeActive = compose?.isComposeModeActive == true,
                                onToggleComposeMode = { compose?.toggleComposeMode() },
                                onShortcutModifierChange = { compose?.syncImeShortcutInputMode(settings.imeShortcutInputMode) },
                            )
                        }
                        InlinePrompt(
                            promptRequest = prompt,
                            onResponse = bridge.promptManager::respond,
                            onCancel = { bridge.dispatchDisconnect(DisconnectReason.USER_REQUESTED) },
                            onDismiss = { focus.requestFocus() },
                            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = if (showExtraKeyboard) settings.terminalBarLayout.height.dp else 0.dp),
                        )
                    }

                    selection?.takeIf { it.isSelectionActive && active && !locked }?.let { controller ->
                        TerminalSelectionActions(
                            controller,
                            onEdit = { engine.requestTextInput(routeOwner, it) },
                            onPaste = { paste() },
                            modifier = Modifier.align(Alignment.TopCenter).padding(top = 12.dp),
                        )
                    }
                }
            }
            LaunchedEffect(composeMode) { engine.changed() }
            LaunchedEffect(settings.alwaysvisible) { keyboardInteraction() }
            LaunchedEffect(settings.imeShortcutInputMode) { compose?.syncImeShortcutInputMode(settings.imeShortcutInputMode) }
            LaunchedEffect(showKeyboard) { if (showKeyboard) focus.requestFocus() }
        }
        addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                markVisible()
            }
            override fun onViewDetachedFromWindow(v: View) {
                engine.manager?.clearVisibleConsole(this@NativeTerminalView)
            }
        })
    }

    init {
        engine.terminalViews[viewId] = this
        activity.lifecycle.addObserver(this)
    }

    private fun keyboardInteraction(scrolling: Boolean = false) {
        keyboardHideJob?.cancel()
        showExtraKeyboard = true
        if (!activity.settings.uiState.value.alwaysvisible && !scrolling) {
            keyboardHideJob = activity.lifecycleScope.launch {
                delay(AUTO_HIDE_DELAY_MS)
                showExtraKeyboard = false
                hasPlayedKeyboardAnimation = true
            }
        }
    }

    fun updateLock(value: Boolean) {
        locked = value
        view.visibility = if (value || !active) View.INVISIBLE else View.VISIBLE
        if (value) {
            showKeyboard = false
            view.clearFocus()
            engine.manager?.clearVisibleConsole(this)
        }
    }
    fun updateVisibility() {
        val wasActive = active
        active = engine.ready && engine.activeOwner == routeOwner && engine.activeSessionId == id
        view.visibility = if (locked || !active) View.INVISIBLE else View.VISIBLE
        if (active && !wasActive) {
            markVisible()
        } else if (!active && wasActive) {
            showKeyboard = false
            engine.manager?.clearVisibleConsole(this)
        }
    }
    private fun markVisible() {
        if (!disposed && active && !locked && view.isAttachedToWindow && activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
            bridge.onTextInputRequest = textInputRequest
            engine.manager?.setVisibleConsole(this, bridge)
        }
    }
    override fun onResume(owner: LifecycleOwner) = markVisible()
    override fun onPause(owner: LifecycleOwner) {
        engine.manager?.clearVisibleConsole(this)
        showKeyboard = false
    }
    override fun getView(): View = view
    override fun dispose() {
        if (disposed) return
        disposed = true
        keyboardHideJob?.cancel()
        activity.lifecycle.removeObserver(this)
        engine.manager?.onConsoleClosed(this, bridge)
        if (engine.terminalViews[viewId] === this) {
            engine.terminalViews.remove(viewId)
            if (bridge.onTextInputRequest === textInputRequest) bridge.onTextInputRequest = null
        }
        view.disposeComposition()
    }
    fun command(action: String, args: Wire = emptyMap()): Any? = when (action) {
        "resize" -> {
            val rows = args.optionalId("rows")?.toInt()
            val columns = args.optionalId("columns")?.toInt()
            require((rows == null && columns == null) || (rows != null && columns != null && rows > 0 && columns > 0))
            overrideSize = true
            sizeOverride = if (rows != null && columns != null) rows to columns else null
            null
        }

        "keyboard" -> {
            showKeyboard = !showKeyboard
            null
        }

        "compose" -> {
            compose?.toggleComposeMode()
            null
        }

        "select" -> {
            selection?.toggleSelection()
            null
        }

        "selectAll" -> {
            selection?.selectAll()
            null
        }

        "selectVisible" -> {
            selection?.selectAllVisible()
            null
        }

        "copy" -> selection?.copySelection()

        "clearSelection" -> {
            selection?.clearSelection()
            null
        }

        "selectionUp" -> {
            selection?.moveSelectionUp()
            null
        }

        "selectionDown" -> {
            selection?.moveSelectionDown()
            null
        }

        "selectionLeft" -> {
            selection?.moveSelectionLeft()
            null
        }

        "selectionRight" -> {
            selection?.moveSelectionRight()
            null
        }

        "selectionMode" -> {
            selection?.toggleSelectionMode()
            null
        }

        "paste" -> {
            paste()
            null
        }

        else -> error("지원하지 않는 터미널 동작입니다.")
    }
    fun dispatchKey(key: Int) {
        val controller = selection
        if (controller?.isSelectionActive == true) {
            when (key) {
                org.connectbot.terminal.VTermKey.UP -> {
                    controller.moveSelectionUp()
                    return
                }

                org.connectbot.terminal.VTermKey.DOWN -> {
                    controller.moveSelectionDown()
                    return
                }

                org.connectbot.terminal.VTermKey.LEFT -> {
                    controller.moveSelectionLeft()
                    return
                }

                org.connectbot.terminal.VTermKey.RIGHT -> {
                    controller.moveSelectionRight()
                    return
                }
            }
        }
        bridge.keyHandler.sendPressedKey(key)
    }
    private fun paste() {
        val clipboard = activity.getSystemService(ClipboardManager::class.java)
        val text = clipboard?.primaryClip?.getItemAt(0)?.coerceToText(activity)?.toString()
        if (text != null) bridge.injectString(text)
    }
    private fun openUrl(url: String) {
        val uri = Uri.parse(url)
        if (uri.scheme in setOf("https", "http", "mailto")) activity.startActivity(Intent(Intent.ACTION_VIEW, uri))
    }
}
