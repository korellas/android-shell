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

import android.content.ContentResolver
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.createBitmap
import kotlinx.coroutines.withContext
import org.connectbot.terminal.ImeShortcutInputMode
import org.connectbot.terminal.VTermKey
import org.connectbot.ui.screens.settings.SettingsUiState
import org.connectbot.util.IconStyle
import org.connectbot.util.LocalFontProvider
import org.connectbot.util.ShortcutIconGenerator
import org.connectbot.util.TerminalBarKey
import org.connectbot.util.TerminalBarLayout
import org.connectbot.util.TerminalFont
import org.connectbot.util.TerminalFontProvider
import org.connectbot.util.ThemeMode
import java.io.ByteArrayOutputStream

internal fun SettingsUiState.toWire(): Wire = mapOf(
    "authOnLaunch" to authOnLaunch, "canAuthenticate" to canAuthenticate, "memkeys" to memkeys,
    "connectionAlerts" to connectionAlerts, "notificationsAvailable" to notificationsAvailable, "wifilock" to wifilock,
    "backupkeys" to backupkeys, "scrollback" to scrollback, "rotation" to rotation, "titlebarhide" to titlebarhide,
    "fullscreen" to fullscreen, "pgupdngesture" to pgupdngesture, "swipeSessions" to swipeSessions, "swipeTmux" to swipeTmux,
    "tmuxCtrlA" to tmuxCtrlA, "terminalMargin" to terminalMargin, "volumefont" to volumefont, "keepalive" to keepalive,
    "alwaysvisible" to alwaysvisible, "imeTogglekey" to imeTogglekey, "imeShortcutInputMode" to imeShortcutInputMode.name,
    "shiftfkeys" to shiftfkeys, "ctrlfkeys" to ctrlfkeys, "stickymodifiers" to stickymodifiers, "keymode" to keymode,
    "camera" to camera, "bumpyarrows" to bumpyarrows, "bell" to bell, "bellVolume" to bellVolume,
    "bellVibrate" to bellVibrate, "bellNotification" to bellNotification, "connectionLostNotification" to connectionLostNotification,
    "fontFamily" to fontFamily, "customFonts" to customFonts, "customTerminalTypes" to customTerminalTypes,
    "localFonts" to localFonts.map { mapOf("fileName" to it.second, "displayName" to it.first) },
    "fontError" to (fontValidationError ?: fontImportError), "fontBusy" to (fontValidationInProgress || fontImportInProgress || fontDownloadInProgress),
    "themeMode" to themeMode.name, "language" to language, "defaultProfileId" to defaultProfileId,
    "terminalBarHeights" to TerminalBarLayout.heights,
    "terminalBarDefaults" to TerminalBarLayout().let { mapOf("height" to it.keyHeight, "order" to it.order.map { key -> key.name }, "hidden" to it.hidden.map { key -> key.name }, "groupFunctionKeys" to it.groupFunctionKeys) },
    "terminalBarHeight" to terminalBarLayout.keyHeight, "terminalBarOrder" to terminalBarLayout.order.map { it.name },
    "terminalBarHidden" to terminalBarLayout.hidden.map { it.name }, "terminalBarFn" to terminalBarLayout.groupFunctionKeys,
    "fonts" to TerminalFont.entries.map { mapOf("value" to it.name, "label" to it.displayName) },
    "terminalKeys" to terminalBarLayout.visibleKeys.flatMap { key ->
        when (key) {
            TerminalBarKey.ALT -> listOf(mapOf("name" to key.name, "label" to key.label, "modifier" to org.connectbot.service.TerminalKeyListener.ALT_ON))

            TerminalBarKey.FUNCTION_KEYS -> {
                val functions = (1..12).map { mapOf("name" to "F$it", "label" to "F$it", "key" to VTermKey.FUNCTION_0 + it) }
                if (terminalBarLayout.groupFunctionKeys) listOf(mapOf("name" to key.name, "label" to "Fn", "functions" to functions)) else functions
            }

            else -> listOf(
                mapOf(
                    "name" to key.name,
                    "label" to key.label,
                    "key" to when (key) {
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
                        else -> error("Invalid terminal key")
                    },
                ),
            )
        }
    },
    "barKeys" to TerminalBarKey.entries.map { mapOf("name" to it.name, "label" to it.label) },
    "enterKey" to VTermKey.ENTER,
    "keyModifiers" to mapOf("Ctrl" to org.connectbot.util.TerminalKeyModifiers.CTRL, "Alt" to org.connectbot.util.TerminalKeyModifiers.ALT, "Shift" to org.connectbot.util.TerminalKeyModifiers.SHIFT),
    "automationKeys" to (listOf("Enter" to VTermKey.ENTER, "Tab" to VTermKey.TAB, "Escape" to VTermKey.ESCAPE, "Backspace" to VTermKey.BACKSPACE, "Delete" to VTermKey.DEL, "Up" to VTermKey.UP, "Down" to VTermKey.DOWN, "Left" to VTermKey.LEFT, "Right" to VTermKey.RIGHT, "Home" to VTermKey.HOME, "End" to VTermKey.END, "Insert" to VTermKey.INS, "Page Up" to VTermKey.PAGEUP, "Page Down" to VTermKey.PAGEDOWN) + org.connectbot.service.automation.AutomationKeySupport.functionNumbers.map { "F$it" to VTermKey.FUNCTION_0 + it } + org.connectbot.service.automation.AutomationKeySupport.characterKeys.map { "${(-it).toChar()}" to it }).map { mapOf("label" to it.first, "key" to it.second) },
    "ctrlModifier" to org.connectbot.service.TerminalKeyListener.CTRL_ON,
    "altModifier" to org.connectbot.service.TerminalKeyListener.ALT_ON,
    "escapeKey" to VTermKey.ESCAPE, "tabKey" to VTermKey.TAB,
)

internal suspend fun AndroidShellEngine.platformOperation(method: String, args: Wire): Any? {
    val settings = activity.settings
    return when (method) {
        "settings.update" -> {
            val value = args["value"]
            when (args.text("key")) {
                "authOnLaunch" -> settings.updateAuthOnLaunch(value as Boolean)

                "memkeys" -> settings.updateMemkeys(value as Boolean)

                "connectionAlerts" -> settings.updateConnectionAlerts(value as Boolean)

                "wifilock" -> settings.updateWifilock(value as Boolean)

                "backupkeys" -> settings.updateBackupkeys(value as Boolean)

                "scrollback" -> {
                    require((value as String).toInt() in 0..100000)
                    settings.updateScrollback(value)
                }

                "rotation" -> settings.updateRotation(value as String)

                "titlebarhide" -> settings.updateTitleBarHide(value as Boolean)

                "fullscreen" -> settings.updateFullscreen(value as Boolean)

                "pgupdngesture" -> settings.updatePgUpDnGesture(value as Boolean)

                "swipeSessions" -> settings.updateSwipeSessions(value as Boolean)

                "swipeTmux" -> settings.updateSwipeTmux(value as Boolean)

                "tmuxCtrlA" -> settings.updateTmuxCtrlA(value as Boolean)

                "terminalMargin" -> settings.updateTerminalMargin((value as Number).toInt())

                "volumefont" -> settings.updateVolumeFont(value as Boolean)

                "keepalive" -> settings.updateKeepAlive(value as Boolean)

                "alwaysvisible" -> settings.updateAlwaysVisible(value as Boolean)

                "imeTogglekey" -> settings.updateImeToggleKey(value as Boolean)

                "imeShortcutInputMode" -> settings.updateImeShortcutInputMode(ImeShortcutInputMode.valueOf(value as String))

                "shiftfkeys" -> settings.updateShiftFkeys(value as Boolean)

                "ctrlfkeys" -> settings.updateCtrlFkeys(value as Boolean)

                "stickymodifiers" -> settings.updateStickyModifiers(value as String)

                "keymode" -> settings.updateKeyMode(value as String)

                "camera" -> settings.updateCamera(value as String)

                "bumpyarrows" -> settings.updateBumpyArrows(value as Boolean)

                "bell" -> settings.updateBell(value as Boolean)

                "bellVolume" -> settings.updateBellVolume((value as Number).toFloat().coerceIn(0f, 1f))

                "bellVibrate" -> settings.updateBellVibrate(value as Boolean)

                "bellNotification" -> settings.updateBellNotification(value as Boolean)

                "connectionLostNotification" -> settings.updateConnectionLostNotification(value as Boolean)

                "fontFamily" -> settings.updateFontFamily(value as String)

                "themeMode" -> settings.updateThemeMode(ThemeMode.valueOf(value as String))

                "language" -> settings.requestLanguage(value as String)

                "colorScheme" -> {
                    val id = (value as Number).toLong()
                    require(colors.getAllSchemes().any { it.id == id })
                    settings.updateColorScheme(id)
                }

                "defaultProfileId" -> settings.updateDefaultProfile((value as Number).toLong())

                "terminalBar" -> {
                    val data = value as Map<*, *>
                    val order = (data["order"] as List<*>).map { TerminalBarKey.valueOf(it as String) }
                    require(order.distinct().size == TerminalBarKey.entries.size && order.toSet() == TerminalBarKey.entries.toSet())
                    val hidden = (data["hidden"] as List<*>).map { TerminalBarKey.valueOf(it as String) }.toSet()
                    val height = (data["height"] as Number).toInt()
                    require(height in TerminalBarLayout.heights)
                    settings.updateTerminalBarLayout(TerminalBarLayout(height, order, hidden, data["groupFunctionKeys"] as Boolean))
                }

                else -> error("지원하지 않는 설정입니다.")
            }
            changed()
            null
        }

        "settings.preview" -> terminalPreview(args)

        "settings.notifications" -> {
            settings.openNotificationSettings()
            null
        }

        "font.import" -> {
            val uri = args.optionalText("uri")?.let { Uri.parse(it) } ?: activity.pickDocument(arrayOf("*/*"))
            if (uri != null) {
                val name = args.optionalText("name") ?: withContext(activity.dispatchers.io) {
                    activity.contentResolver.selectedFontFileName(uri)
                }
                settings.importLocalFont(uri, name)
            }
            null
        }

        "font.delete" -> {
            settings.deleteLocalFont(args.text("fileName"))
            null
        }

        "font.custom" -> {
            settings.addCustomFont(args.text("name"))
            null
        }

        "font.customDelete" -> {
            settings.removeCustomFont(args.text("name"))
            null
        }

        "terminalType.add" -> {
            settings.addCustomTerminalType(args.text("name"))
            null
        }

        "terminalType.delete" -> {
            settings.removeCustomTerminalType(args.text("name"))
            null
        }

        "document.pick" -> activity.pickDocument(arrayOf(args.text("mime", "*/*")))?.toString()

        "document.create" -> activity.createDocument(args.text("name"))?.toString()

        "document.read" -> withContext(activity.dispatchers.io) {
            activity.contentResolver.openInputStream(Uri.parse(args.text("uri")))?.bufferedReader()?.use { it.readText() } ?: error("파일을 읽을 수 없습니다.")
        }

        "document.write" -> withContext(activity.dispatchers.io) {
            activity.contentResolver.openOutputStream(Uri.parse(args.text("uri")), "wt")?.bufferedWriter()?.use { it.write(args.text("text")) } ?: error("파일을 저장할 수 없습니다.")
        }

        "help.document" -> when (args.text("section")) {
            "license" -> withContext(activity.dispatchers.io) { activity.assets.open("flutter-native-license.txt").bufferedReader().use { it.readText() } }
            "contact" -> listOf(org.connectbot.R.string.app_copyright, org.connectbot.R.string.help_website_url, org.connectbot.R.string.help_github_url, org.connectbot.R.string.help_report_bug_url).joinToString("\n\n") { activity.getString(it) }
            "hints" -> "Ctrl+Shift+C: copy selection\nCtrl+Shift+V: paste\nCtrl+Shift++ / Ctrl+Shift+-: font size\nTouch the terminal to open the keyboard. Hold Ctrl or Alt to lock the modifier."
            else -> error("지원하지 않는 문서입니다.")
        }

        "logs" -> {
            activity.logs.loadLogs()
            activity.logs.uiState.value.logs
        }

        "logs.clear" -> error("기존 로그 엔진은 로그 삭제를 지원하지 않습니다.")

        "logs.tombstone" -> {
            val uri = activity.createDocument("android-shell-tombstone.txt")
            if (uri != null) activity.logs.saveTombstone(uri).name else null
        }

        "openUrl" -> {
            val uri = Uri.parse(args.text("url"))
            require(uri.scheme in setOf("https", "http", "mailto"))
            activity.startActivity(Intent(Intent.ACTION_VIEW, uri))
            null
        }

        "share" -> {
            activity.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, args.text("text")), "공유"))
            null
        }

        "shortcut" -> {
            val host = requireNotNull(hosts.findHostById(args.number("id")))
            val shortcut = ShortcutInfoCompat.Builder(activity, "host-${host.id}")
                .setShortLabel(host.nickname.ifBlank { host.hostname })
                .setIcon(ShortcutIconGenerator.generateShortcutIcon(activity, args.optionalText("color"), IconStyle.valueOf(args.text("style", IconStyle.entries.first().name))))
                .setIntent(Intent(activity, FlutterShellActivity::class.java).setAction(Intent.ACTION_VIEW).setData(host.getUri()))
                .build()
            if (activity.intent.action == Intent.ACTION_CREATE_SHORTCUT) {
                activity.setResult(android.app.Activity.RESULT_OK, ShortcutManagerCompat.createShortcutResultIntent(activity, shortcut))
                activity.finish()
                true
            } else {
                ShortcutManagerCompat.requestPinShortcut(activity, shortcut, null)
            }
        }

        else -> error("지원하지 않는 플랫폼 작업입니다.")
    }
}

internal fun androidx.compose.material3.ColorScheme.toWire(): Wire = mapOf(
    "primary" to (primary.toArgb().toLong() and 0xffffffffL),
    "onPrimary" to (onPrimary.toArgb().toLong() and 0xffffffffL),
    "primaryContainer" to (primaryContainer.toArgb().toLong() and 0xffffffffL),
    "onPrimaryContainer" to (onPrimaryContainer.toArgb().toLong() and 0xffffffffL),
    "secondary" to (secondary.toArgb().toLong() and 0xffffffffL),
    "onSecondary" to (onSecondary.toArgb().toLong() and 0xffffffffL),
    "secondaryContainer" to (secondaryContainer.toArgb().toLong() and 0xffffffffL),
    "onSecondaryContainer" to (onSecondaryContainer.toArgb().toLong() and 0xffffffffL),
    "tertiary" to (tertiary.toArgb().toLong() and 0xffffffffL),
    "onTertiary" to (onTertiary.toArgb().toLong() and 0xffffffffL),
    "tertiaryContainer" to (tertiaryContainer.toArgb().toLong() and 0xffffffffL),
    "onTertiaryContainer" to (onTertiaryContainer.toArgb().toLong() and 0xffffffffL),
    "error" to (error.toArgb().toLong() and 0xffffffffL),
    "onError" to (onError.toArgb().toLong() and 0xffffffffL),
    "errorContainer" to (errorContainer.toArgb().toLong() and 0xffffffffL),
    "onErrorContainer" to (onErrorContainer.toArgb().toLong() and 0xffffffffL),
    "surface" to (surface.toArgb().toLong() and 0xffffffffL),
    "onSurface" to (onSurface.toArgb().toLong() and 0xffffffffL),
    "onSurfaceVariant" to (onSurfaceVariant.toArgb().toLong() and 0xffffffffL),
    "outline" to (outline.toArgb().toLong() and 0xffffffffL),
    "outlineVariant" to (outlineVariant.toArgb().toLong() and 0xffffffffL),
    "inverseSurface" to (inverseSurface.toArgb().toLong() and 0xffffffffL),
    "inverseOnSurface" to (inverseOnSurface.toArgb().toLong() and 0xffffffffL),
    "inversePrimary" to (inversePrimary.toArgb().toLong() and 0xffffffffL),
    "surfaceTint" to (surfaceTint.toArgb().toLong() and 0xffffffffL),
    "surfaceContainerLowest" to (surfaceContainerLowest.toArgb().toLong() and 0xffffffffL),
    "surfaceContainerLow" to (surfaceContainerLow.toArgb().toLong() and 0xffffffffL),
    "surfaceContainer" to (surfaceContainer.toArgb().toLong() and 0xffffffffL),
    "surfaceContainerHigh" to (surfaceContainerHigh.toArgb().toLong() and 0xffffffffL),
    "surfaceContainerHighest" to (surfaceContainerHighest.toArgb().toLong() and 0xffffffffL),
)

private suspend fun AndroidShellEngine.terminalPreview(args: Wire): Wire {
    val state = activity.settings.uiState.value
    val profile = state.defaultProfileId.takeIf { it > 0 }?.let { profiles.getById(it) } ?: profiles.getDefault()
    val palette = colors.getSchemeColors(profile.colorSchemeId)
    val (foreground, background) = colors.getSchemeDefaults(profile.colorSchemeId)
    val storedFont = state.fontFamily
    return withContext(activity.dispatchers.io) {
        val typeface = if (LocalFontProvider.isLocalFont(storedFont)) {
            LocalFontProvider.getLocalFontFileName(storedFont)?.let { LocalFontProvider(activity).getTypeface(it) } ?: Typeface.MONOSPACE
        } else {
            TerminalFontProvider(activity, activity.dispatchers.io).loadFontByNameSuspend(TerminalFont.getGoogleFontName(storedFont))
        }
        val density = (args["scale"] as? Number)?.toFloat()?.coerceIn(1f, 3f) ?: 1f
        val widthDp = (args["width"] as? Number)?.toFloat()?.coerceIn(200f, 1000f) ?: 360f
        val textScale = (args["textScale"] as? Number)?.toFloat()?.coerceIn(1f, 3f) ?: 1f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface
            textSize = 14f * textScale * density
        }
        val lineHeight = paint.fontSpacing
        val margin = state.terminalMargin * density
        val inset = 12f * density
        val bitmap = createBitmap((widthDp * density).toInt(), (lineHeight * 3 + (margin + inset) * 2).toInt(), Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(palette[background])
            val lines = listOf("user@shell:~$ ls", "src  build  한글.md", "$ ssh server")
            lines.forEachIndexed { index, line ->
                paint.color = palette[if (index == 1) 2 else foreground]
                canvas.drawText(line, margin + inset, margin + inset - paint.fontMetrics.top + index * lineHeight, paint)
            }
            ByteArrayOutputStream().use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                mapOf("png" to output.toByteArray(), "width" to bitmap.width / density, "height" to bitmap.height / density)
            }
        } finally {
            bitmap.recycle()
        }
    }
}

internal fun ContentResolver.selectedFontFileName(uri: Uri): String = query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
    val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
    if (column >= 0 && cursor.moveToFirst()) cursor.getString(column)?.takeIf { it.isNotBlank() } else null
} ?: "Imported font.ttf"
