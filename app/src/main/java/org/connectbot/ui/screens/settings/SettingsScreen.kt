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

package org.connectbot.ui.screens.settings

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.FontDownload
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Swipe
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.connectbot.BuildConfig
import org.connectbot.R
import org.connectbot.data.ColorSchemePresets
import org.connectbot.service.ModifierLevel
import org.connectbot.service.ModifierState
import org.connectbot.terminal.ImeShortcutInputMode
import org.connectbot.ui.ObservePermissionOnResume
import org.connectbot.ui.PreviewScreen
import org.connectbot.ui.common.getLocalizedFontDisplayName
import org.connectbot.ui.components.FontDownloadProgressDialog
import org.connectbot.ui.components.TerminalKeyboardContent
import org.connectbot.ui.components.TextInputAlertDialog
import org.connectbot.ui.theme.ConnectBotTheme
import org.connectbot.util.LanguageDownloadState
import org.connectbot.util.LocalFontProvider
import org.connectbot.util.PreferenceConstants
import org.connectbot.util.TerminalBarKey
import org.connectbot.util.TerminalBarLayout
import org.connectbot.util.TerminalFont
import org.connectbot.util.ThemeMode
import org.connectbot.util.isNotificationPermissionGranted
import org.xmlpull.v1.XmlPullParser
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    highlightItem: String? = null,
    viewModel: SettingsViewModel = hiltViewModel(),
    colorViewModel: org.connectbot.ui.screens.colors.ColorSchemeManagerViewModel = hiltViewModel(),
    onEditPalette: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()
    val schemeState by colorViewModel.uiState.collectAsState()
    var paletteRefresh by remember { mutableIntStateOf(0) }
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
        paletteRefresh++
        viewModel.refreshProfiles()
    }
    var colorOptions by remember { mutableStateOf(builtInColorOptions) }
    LaunchedEffect(schemeState.schemes, paletteRefresh) {
        colorOptions = schemeState.schemes.map { scheme ->
            val defaults = colorViewModel.repository.getSchemeDefaults(scheme.id)
            SettingsColorOption(scheme.id, ColorSchemePresets.PresetScheme(scheme.name, scheme.description, defaults.first, defaults.second, colorViewModel.repository.getSchemeColors(scheme.id)))
        }
    }
    val context = LocalContext.current

    // Permission launcher for notification permission
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { _ ->
        // Check the actual permission status instead of relying on the launcher result.
        // If user went to settings and granted permission, the result will be false but
        // the actual permission may be granted.
        val actuallyGranted = isNotificationPermissionGranted(context)
        viewModel.onNotificationPermissionResult(actuallyGranted)
    }

    // Listen for permission request events
    LaunchedEffect(Unit) {
        viewModel.requestNotificationPermission.collect {
            if (isNotificationPermissionGranted(context)) {
                // Permission already granted
                viewModel.onNotificationPermissionResult(true)
            } else {
                // Request permission
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    // No permission needed on older versions
                    viewModel.onNotificationPermissionResult(true)
                }
            }
        }
    }

    // State for showing permission denied dialog
    var showPermissionDeniedDialog by remember { mutableStateOf(false) }

    // Listen for permission denied dialog events
    LaunchedEffect(Unit) {
        viewModel.showPermissionDeniedDialog.collect {
            showPermissionDeniedDialog = true
        }
    }

    LaunchedEffect(Unit) {
        viewModel.openNotificationChannelSettings.collect { intent ->
            context.startActivity(intent)
        }
    }

    // Re-check permission status when screen resumes (e.g., user grants/revokes in Settings)
    ObservePermissionOnResume { isGranted ->
        viewModel.onNotificationPermissionChanged(isGranted)
    }

    // Show permission denied dialog if needed
    if (showPermissionDeniedDialog) {
        NotificationPermissionDeniedDialog(
            onDismiss = {
                showPermissionDeniedDialog = false
            },
            onOpenSettings = {
                showPermissionDeniedDialog = false
                // Open app settings so user can grant notification permission
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                }
                context.startActivity(intent)
            },
        )
    }

    SettingsScreenContent(
        uiState = uiState,
        onNavigateBack = onNavigateBack,
        highlightItem = highlightItem,
        onAuthOnLaunchChange = viewModel::updateAuthOnLaunch,
        onMemkeysChange = viewModel::updateMemkeys,
        onConnectionAlertsChange = viewModel::updateConnectionAlerts,
        onWifilockChange = viewModel::updateWifilock,
        onBackupkeysChange = viewModel::updateBackupkeys,
        onScrollbackChange = viewModel::updateScrollback,
        onAddCustomTerminalType = viewModel::addCustomTerminalType,
        onRemoveCustomTerminalType = viewModel::removeCustomTerminalType,
        onFontFamilyChange = viewModel::updateFontFamily,
        onAddCustomFont = viewModel::addCustomFont,
        onRemoveCustomFont = viewModel::removeCustomFont,
        onClearFontError = viewModel::clearFontValidationError,
        onImportLocalFont = viewModel::importLocalFont,
        onDeleteLocalFont = viewModel::deleteLocalFont,
        onClearImportError = viewModel::clearFontImportError,
        onDefaultProfileChange = viewModel::updateDefaultProfile,
        onLanguageChange = viewModel::requestLanguage,
        onThemeModeChange = viewModel::updateThemeMode,
        onRotationChange = viewModel::updateRotation,
        onFullscreenChange = viewModel::updateFullscreen,
        onTitleBarHideChange = viewModel::updateTitleBarHide,
        onPgUpDnGestureChange = viewModel::updatePgUpDnGesture,
        onSwipeSessionsChange = viewModel::updateSwipeSessions,
        onSwipeTmuxChange = viewModel::updateSwipeTmux,
        onTmuxCtrlAChange = viewModel::updateTmuxCtrlA,
        onTerminalMarginChange = viewModel::updateTerminalMargin,
        onTerminalBarLayoutChange = viewModel::updateTerminalBarLayout,
        onColorSchemeChange = viewModel::updateColorScheme,
        onEditPalette = onEditPalette,
        colorOptions = colorOptions,
        onVolumeFontChange = viewModel::updateVolumeFont,
        onKeepAliveChange = viewModel::updateKeepAlive,
        onAlwaysVisibleChange = viewModel::updateAlwaysVisible,
        onImeToggleKeyChange = viewModel::updateImeToggleKey,
        onImeShortcutInputModeChange = viewModel::updateImeShortcutInputMode,
        onShiftFkeysChange = viewModel::updateShiftFkeys,
        onCtrlFkeysChange = viewModel::updateCtrlFkeys,
        onStickyModifiersChange = viewModel::updateStickyModifiers,
        onKeyModeChange = viewModel::updateKeyMode,
        onCameraChange = viewModel::updateCamera,
        onBumpyArrowsChange = viewModel::updateBumpyArrows,
        onBellChange = viewModel::updateBell,
        onBellVolumeChange = viewModel::updateBellVolume,
        onBellVibrateChange = viewModel::updateBellVibrate,
        onBellNotificationChange = viewModel::updateBellNotification,
        onConnectionLostNotificationChange = viewModel::updateConnectionLostNotification,
        onNotificationSettingsClick = viewModel::openNotificationSettings,
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreenContent(
    uiState: SettingsUiState,
    onNavigateBack: () -> Unit,
    onAuthOnLaunchChange: (Boolean) -> Unit,
    onMemkeysChange: (Boolean) -> Unit,
    onConnectionAlertsChange: (Boolean) -> Unit,
    onWifilockChange: (Boolean) -> Unit,
    onBackupkeysChange: (Boolean) -> Unit,
    onScrollbackChange: (String) -> Unit,
    onAddCustomTerminalType: (String) -> Unit,
    onRemoveCustomTerminalType: (String) -> Unit,
    onFontFamilyChange: (String) -> Unit,
    onAddCustomFont: (String) -> Unit,
    onRemoveCustomFont: (String) -> Unit,
    onClearFontError: () -> Unit,
    onImportLocalFont: (Uri, String) -> Unit,
    onDeleteLocalFont: (String) -> Unit,
    onClearImportError: () -> Unit,
    onDefaultProfileChange: (Long) -> Unit,
    onLanguageChange: (String) -> Unit,
    onThemeModeChange: (ThemeMode) -> Unit,
    onRotationChange: (String) -> Unit,
    onFullscreenChange: (Boolean) -> Unit,
    onTitleBarHideChange: (Boolean) -> Unit,
    onPgUpDnGestureChange: (Boolean) -> Unit,
    onSwipeSessionsChange: (Boolean) -> Unit,
    onVolumeFontChange: (Boolean) -> Unit,
    onKeepAliveChange: (Boolean) -> Unit,
    onAlwaysVisibleChange: (Boolean) -> Unit,
    onImeToggleKeyChange: (Boolean) -> Unit,
    onImeShortcutInputModeChange: (ImeShortcutInputMode) -> Unit,
    onShiftFkeysChange: (Boolean) -> Unit,
    onCtrlFkeysChange: (Boolean) -> Unit,
    onStickyModifiersChange: (String) -> Unit,
    onKeyModeChange: (String) -> Unit,
    onCameraChange: (String) -> Unit,
    onBumpyArrowsChange: (Boolean) -> Unit,
    onBellChange: (Boolean) -> Unit,
    onBellVolumeChange: (Float) -> Unit,
    onBellVibrateChange: (Boolean) -> Unit,
    onBellNotificationChange: (Boolean) -> Unit,
    onConnectionLostNotificationChange: (Boolean) -> Unit,
    onNotificationSettingsClick: () -> Unit,
    modifier: Modifier = Modifier,
    highlightItem: String? = null,
    onSwipeTmuxChange: (Boolean) -> Unit = {},
    onTmuxCtrlAChange: (Boolean) -> Unit = {},
    onTerminalMarginChange: (Int) -> Unit = {},
    onTerminalBarLayoutChange: (TerminalBarLayout) -> Unit = {},
    colorOptions: List<SettingsColorOption> = builtInColorOptions,
    onColorSchemeChange: (Long) -> Unit = {},
    onEditPalette: () -> Unit = {},
) {
    var category by rememberSaveable { mutableStateOf<String?>(if (highlightItem == "conn_persist" || highlightItem == "connection_alerts") "connection" else null) }
    var subpage by rememberSaveable { mutableStateOf<String?>(null) }
    var advanced by rememberSaveable { mutableStateOf(false) }
    val selectedSchemeId = uiState.availableProfiles.firstOrNull { it.id == (uiState.defaultProfileId.takeIf { id -> id != 0L } ?: 1L) }?.colorSchemeId ?: -1L
    val selectedPalette = colorOptions.firstOrNull { it.id == selectedSchemeId }?.palette ?: ColorSchemePresets.default
    var highlightConnectionAlerts by remember { mutableStateOf(false) }
    val connectionAlertsHighlightColor by animateColorAsState(
        if (highlightConnectionAlerts) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        animationSpec = tween(500),
        label = "connectionAlertsHighlight",
    )
    LaunchedEffect(highlightItem) {
        if (highlightItem == "conn_persist" || highlightItem == "connection_alerts") {
            category = "connection"
            delay(300)
            highlightConnectionAlerts = true
            delay(1500)
            highlightConnectionAlerts = false
        }
    }
    BoxWithConstraints(modifier.fillMaxSize()) {
        val wide = maxWidth >= 600.dp
        val selectedCategory = category ?: if (wide) "display" else null
        val back: () -> Unit = {
            when {
                subpage != null -> subpage = null
                !wide && category != null -> category = null
                else -> onNavigateBack()
            }
        }
        BackHandler(enabled = subpage != null || (!wide && category != null), onBack = back)
        Row(Modifier.fillMaxSize()) {
            if (wide || selectedCategory == null) {
                Scaffold(
                    modifier = if (wide) Modifier.width(280.dp).fillMaxHeight() else Modifier.fillMaxSize(),
                    topBar = { SettingsToolbar(stringResource(R.string.title_settings), onNavigateBack) },
                ) { padding ->
                    LazyColumn(Modifier.padding(padding), contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) {
                        SettingsCategory.entries.forEach { entry ->
                            item(key = entry.id) {
                                val selected = wide && selectedCategory == entry.id
                                Surface(
                                    onClick = {
                                        category = entry.id
                                        subpage = null
                                    },
                                    shape = RoundedCornerShape(28.dp),
                                    color = if (selected) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent,
                                    modifier = Modifier.fillMaxWidth().semantics { this.selected = selected }.testTag("settings_category_" + entry.id),
                                ) {
                                    ListItem(
                                        headlineContent = { Text(stringResource(entry.title)) },
                                        supportingContent = { Text(settingsCategorySummary(entry, uiState, selectedPalette.name), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                        leadingContent = {
                                            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh) {
                                                Icon(entry.icon, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(9.dp).size(22.dp))
                                            }
                                        },
                                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                                    )
                                }
                            }
                        }
                    }
                }
            }
            if (selectedCategory != null) {
                if (wide) VerticalDivider()
                Scaffold(
                    modifier = Modifier.weight(1f).fillMaxHeight(),
                    topBar = {
                        val title = when (subpage) {
                            "colors" -> stringResource(R.string.settings_color_theme)
                            "keybar" -> stringResource(R.string.settings_special_keys)
                            else -> stringResource(SettingsCategory.entries.first { it.id == selectedCategory }.title)
                        }
                        SettingsToolbar(title, if (!wide || subpage != null) back else null)
                    },
                ) { padding ->
                    key(selectedCategory, subpage) {
                        LazyColumn(
                            modifier = Modifier.padding(padding).fillMaxSize().testTag("settings_details"),
                            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp, top = 4.dp),
                        ) {
                            when (subpage ?: selectedCategory) {
                                "display" -> {
                                    item { TerminalPreview(uiState, selectedPalette) }
                                    item { PreferenceCategory(stringResource(R.string.settings_appearance)) }
                                    item {
                                        SettingsGroup {
                                            SegmentedPreference(
                                                title = stringResource(R.string.pref_theme_title),
                                                value = uiState.themeMode.name,
                                                entries = listOf(stringResource(R.string.pref_theme_system) to ThemeMode.SYSTEM.name, stringResource(R.string.pref_theme_light) to ThemeMode.LIGHT.name, stringResource(R.string.pref_theme_dark) to ThemeMode.DARK.name),
                                                onValueChange = { onThemeModeChange(ThemeMode.fromString(it)) },
                                            )
                                            ListItem(
                                                headlineContent = { Text(stringResource(R.string.settings_color_theme)) },
                                                supportingContent = { Text(selectedPalette.name) },
                                                trailingContent = { Icon(Icons.Default.ChevronRight, null) },
                                                modifier = Modifier.clickable { subpage = "colors" },
                                                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                                            )
// Build combined font list: presets + custom fonts + local fonts
// Only show downloadable preset fonts if Google Play Services is available
                                            val presetEntries = if (BuildConfig.HAS_DOWNLOADABLE_FONTS) {
                                                TerminalFont.entries.map { it.displayName to it.name }
                                            } else {
                                                // In OSS builds, only show System Default (which doesn't require download)
                                                listOf(TerminalFont.SYSTEM_DEFAULT.displayName to TerminalFont.SYSTEM_DEFAULT.name)
                                            }
                                            val customEntries = if (BuildConfig.HAS_DOWNLOADABLE_FONTS) {
                                                uiState.customFonts.map { it to TerminalFont.createCustomFontValue(it) }
                                            } else {
                                                emptyList()
                                            }
                                            val localEntries = uiState.localFonts.map { (displayName, fileName) ->
                                                displayName to LocalFontProvider.createLocalFontValue(fileName)
                                            }
                                            val allEntries = presetEntries + customEntries + localEntries

                                            ListPreference(
                                                title = stringResource(R.string.pref_fontfamily_title),
                                                summary = getLocalizedFontDisplayName(uiState.fontFamily),
                                                value = uiState.fontFamily,
                                                entries = allEntries,
                                                onValueChange = onFontFamilyChange,
                                            )
                                            if (BuildConfig.HAS_DOWNLOADABLE_FONTS) {
                                                AddCustomFontPreference(
                                                    customFonts = uiState.customFonts,
                                                    validationInProgress = uiState.fontValidationInProgress,
                                                    validationError = uiState.fontValidationError,
                                                    onAddFont = onAddCustomFont,
                                                    onRemoveFont = onRemoveCustomFont,
                                                    onClearError = onClearFontError,
                                                )
                                            }
                                            LocalFontPreference(
                                                localFonts = uiState.localFonts,
                                                importInProgress = uiState.fontImportInProgress,
                                                importError = uiState.fontImportError,
                                                onImportFont = onImportLocalFont,
                                                onDeleteFont = onDeleteLocalFont,
                                                onClearError = onClearImportError,
                                            )
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.pref_terminal_margin_title)) }
                                    item {
                                        SettingsGroup {
                                            MarginPreference(uiState.terminalMargin, onTerminalMarginChange)
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.settings_console)) }
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_fullscreen_title),
                                                summary = stringResource(R.string.pref_fullscreen_summary),
                                                checked = uiState.fullscreen,
                                                onCheckedChange = onFullscreenChange,
                                            )
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_titlebarhide_title),
                                                summary = stringResource(R.string.pref_titlebarhide_summary),
                                                checked = uiState.titlebarhide,
                                                onCheckedChange = onTitleBarHideChange,
                                            )
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_keepalive_title),
                                                summary = stringResource(R.string.pref_keepalive_summary),
                                                checked = uiState.keepalive,
                                                onCheckedChange = onKeepAliveChange,
                                            )
                                        }
                                    }
                                    item {
                                        SettingsGroup {
                                            val context = LocalContext.current
                                            val systemDefaultLabel = stringResource(R.string.pref_language_system_default)
                                            val languageEntries = remember {
                                                listOf("" to systemDefaultLabel) + buildAvailableLanguageList(context)
                                            }
                                            val currentLabel = if (uiState.language.isEmpty()) {
                                                systemDefaultLabel
                                            } else {
                                                languageEntries.find { it.first == uiState.language }?.second
                                                    ?: uiState.language
                                            }
                                            LanguageListPreference(
                                                title = stringResource(R.string.pref_language_title),
                                                summary = currentLabel,
                                                value = uiState.language,
                                                entries = languageEntries.map { (tag, label) -> label to tag },
                                                downloadStates = uiState.languageDownloadStates,
                                                installedLanguages = uiState.installedLanguages,
                                                onEntryClick = onLanguageChange,
                                            )
                                        }
                                    }
                                }

                                "keyboard" -> {
                                    item {
                                        SettingsGroup {
                                            TerminalKeyboardContent(
                                                modifierState = ModifierState(ModifierLevel.OFF, ModifierLevel.OFF, ModifierLevel.OFF),
                                                onCtrlPress = {}, onAltPress = {}, onEscPress = {}, onTabPress = {}, onKeyPress = {},
                                                onInteraction = {}, onHideIme = {}, onShowIme = {}, onScrollInProgressChange = {},
                                                imeVisible = false, playAnimation = false, bumpyArrows = false, layout = uiState.terminalBarLayout,
                                            )
                                            TextButton(onClick = { subpage = "keybar" }) { Text(stringResource(R.string.settings_edit_keybar)) }
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.settings_special_keys)) }
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_alwaysvisible_title),
                                                summary = stringResource(R.string.pref_alwaysvisible_summary),
                                                checked = uiState.alwaysvisible,
                                                onCheckedChange = onAlwaysVisibleChange,
                                            )
                                            SegmentedPreference(
                                                title = stringResource(R.string.pref_stickymodifiers_title),
                                                value = uiState.stickymodifiers,
                                                entries = listOf(stringResource(R.string.no) to "no", stringResource(R.string.only_alt) to "alt", stringResource(R.string.yes) to "yes"),
                                                onValueChange = onStickyModifiersChange,
                                            )
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.settings_text_input)) }
                                    item {
                                        SettingsGroup {
                                            val shortcutModeLabels = mapOf(
                                                ImeShortcutInputMode.DISABLED to stringResource(R.string.pref_ime_shortcut_mode_disabled),
                                                ImeShortcutInputMode.TYPE_NULL to stringResource(R.string.pref_ime_shortcut_mode_type_null),
                                                ImeShortcutInputMode.FORCE_ASCII to stringResource(R.string.pref_ime_shortcut_mode_force_ascii),
                                            )
                                            ListPreference(
                                                title = stringResource(R.string.pref_ime_shortcut_mode_title),
                                                summary = shortcutModeLabels.getValue(uiState.imeShortcutInputMode),
                                                value = uiState.imeShortcutInputMode.name,
                                                entries = ImeShortcutInputMode.entries.map { mode ->
                                                    shortcutModeLabels.getValue(mode) to mode.name
                                                },
                                                onValueChange = { value ->
                                                    ImeShortcutInputMode.entries
                                                        .firstOrNull { it.name == value }
                                                        ?.let(onImeShortcutInputModeChange)
                                                },
                                            )
                                        }
                                    }
                                    item {
                                        TextButton(onClick = { advanced = !advanced }, modifier = Modifier.fillMaxWidth()) {
                                            Text(stringResource(R.string.settings_keyboard_advanced))
                                            Icon(if (advanced) Icons.Default.ExpandLess else Icons.Default.ExpandMore, null)
                                        }
                                    }
                                    if (advanced) {
                                        item {
                                            SettingsGroup {
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_shiftfkeys_title),
                                                    summary = stringResource(R.string.pref_shiftfkeys_summary),
                                                    checked = uiState.shiftfkeys,
                                                    onCheckedChange = onShiftFkeysChange,
                                                )
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_ctrlfkeys_title),
                                                    summary = stringResource(R.string.pref_ctrlfkeys_summary),
                                                    checked = uiState.ctrlfkeys,
                                                    onCheckedChange = onCtrlFkeysChange,
                                                )
                                                ListPreference(
                                                    title = stringResource(R.string.pref_keymode_title),
                                                    summary = when (uiState.keymode) {
                                                        "Use right-side keys" -> stringResource(R.string.list_keymode_right)
                                                        "Use left-side keys" -> stringResource(R.string.list_keymode_left)
                                                        "none" -> stringResource(R.string.list_keymode_none)
                                                        else -> uiState.keymode
                                                    },
                                                    value = uiState.keymode,
                                                    entries = listOf(
                                                        stringResource(R.string.list_keymode_right) to "Use right-side keys",
                                                        stringResource(R.string.list_keymode_left) to "Use left-side keys",
                                                        stringResource(R.string.list_keymode_none) to "none",
                                                    ),
                                                    onValueChange = onKeyModeChange,
                                                )
                                                val cameraSummary = when (uiState.camera) {
                                                    "Ctrl+A then Space" -> stringResource(R.string.list_camera_ctrlaspace_description)
                                                    "Ctrl+A" -> stringResource(R.string.list_camera_ctrla_description)
                                                    "Esc" -> stringResource(R.string.list_camera_esc_description)
                                                    "Esc+A" -> stringResource(R.string.list_camera_esc_a_description)
                                                    "None" -> stringResource(R.string.list_camera_none_description)
                                                    "text_input" -> stringResource(R.string.list_camera_text_input_description)
                                                    else -> uiState.camera
                                                }
                                                ListPreference(
                                                    title = stringResource(R.string.pref_camera_title),
                                                    summary = cameraSummary,
                                                    value = uiState.camera,
                                                    entries = listOf(
                                                        stringResource(R.string.list_camera_ctrlaspace) to "Ctrl+A then Space",
                                                        stringResource(R.string.list_camera_ctrla) to "Ctrl+A",
                                                        stringResource(R.string.list_camera_esc) to "Esc",
                                                        stringResource(R.string.list_camera_esc_a) to "Esc+A",
                                                        stringResource(R.string.list_camera_none) to "None",
                                                        stringResource(R.string.list_camera_text_input) to "text_input",
                                                    ),
                                                    onValueChange = onCameraChange,
                                                )
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_volumefont_title),
                                                    summary = stringResource(R.string.pref_volumefont_summary),
                                                    checked = uiState.volumefont,
                                                    onCheckedChange = onVolumeFontChange,
                                                )
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_bumpyarrows_title),
                                                    summary = stringResource(R.string.pref_bumpyarrows_summary),
                                                    checked = uiState.bumpyarrows,
                                                    onCheckedChange = onBumpyArrowsChange,
                                                )
                                            }
                                        }
                                    }
                                }

                                "gesture" -> {
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_swipe_sessions_title),
                                                summary = stringResource(R.string.pref_swipe_sessions_summary),
                                                checked = uiState.swipeSessions,
                                                onCheckedChange = onSwipeSessionsChange,
                                            )
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_swipe_tmux_title),
                                                summary = stringResource(R.string.pref_swipe_tmux_summary),
                                                checked = uiState.swipeTmux,
                                                onCheckedChange = onSwipeTmuxChange,
                                            )
                                            if (uiState.swipeTmux) {
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_tmux_ctrl_a_title),
                                                    summary = stringResource(R.string.pref_tmux_ctrl_a_summary),
                                                    checked = uiState.tmuxCtrlA,
                                                    onCheckedChange = onTmuxCtrlAChange,
                                                )
                                            }
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_pg_updn_gesture_title),
                                                summary = stringResource(R.string.pref_pg_updn_gesture_summary),
                                                checked = uiState.pgupdngesture,
                                                onCheckedChange = onPgUpDnGestureChange,
                                            )
                                        }
                                    }
                                }

                                "terminal" -> {
                                    item {
                                        SettingsGroup {
                                            ScrollbackPreference(uiState.scrollback, onScrollbackChange)
                                            AddCustomTerminalTypePreference(
                                                customTerminalTypes = uiState.customTerminalTypes,
                                                onAddTerminalType = onAddCustomTerminalType,
                                                onRemoveTerminalType = onRemoveCustomTerminalType,
                                            )
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.pref_profiles_category)) }
                                    item {
                                        SettingsGroup {
                                            val selectedProfile = if (uiState.defaultProfileId == 0L) {
                                                null
                                            } else {
                                                uiState.availableProfiles.find { it.id == uiState.defaultProfileId }
                                            }
                                            val noneLabel = stringResource(R.string.pref_default_profile_none)
                                            val profileEntries = listOf(noneLabel to "0") +
                                                uiState.availableProfiles.map { it.name to it.id.toString() }
                                            ListPreference(
                                                title = stringResource(R.string.pref_default_profile_title),
                                                summary = selectedProfile?.name ?: noneLabel,
                                                value = uiState.defaultProfileId.toString(),
                                                entries = profileEntries,
                                                onValueChange = { onDefaultProfileChange(it.toLong()) },
                                            )
                                        }
                                    }
                                }

                                "connection" -> {
                                    item { PreferenceCategory(stringResource(R.string.settings_notifications)) }
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_connection_alerts_title),
                                                summary = stringResource(
                                                    if (uiState.connectionAlerts) R.string.pref_connection_alerts_summary else R.string.pref_connection_alerts_disabled_summary,
                                                ),
                                                checked = uiState.connectionAlerts,
                                                onCheckedChange = onConnectionAlertsChange,
                                                highlightColor = connectionAlertsHighlightColor,
                                            )
                                            if (!uiState.notificationsAvailable) {
                                                ListItem(
                                                    headlineContent = { Text(stringResource(R.string.pref_notifications_blocked)) },
                                                    trailingContent = { Icon(Icons.AutoMirrored.Filled.OpenInNew, null) },
                                                    modifier = Modifier.clickable(onClick = onNotificationSettingsClick),
                                                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                                                )
                                            }
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                                NotificationChannelsPreference(onClick = onNotificationSettingsClick)
                                            } else if (uiState.connectionAlerts) {
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_bell_notification_title),
                                                    summary = stringResource(R.string.pref_bell_notification_summary),
                                                    checked = uiState.bellNotification,
                                                    onCheckedChange = onBellNotificationChange,
                                                )
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_connection_lost_notification_title),
                                                    summary = stringResource(R.string.pref_connection_lost_notification_summary),
                                                    checked = uiState.connectionLostNotification,
                                                    onCheckedChange = onConnectionLostNotificationChange,
                                                )
                                            }
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_wifilock_title),
                                                summary = stringResource(R.string.pref_wifilock_summary),
                                                checked = uiState.wifilock,
                                                onCheckedChange = onWifilockChange,
                                            )
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.pref_bell_category)) }
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_bell_title),
                                                summary = stringResource(R.string.pref_bell_summary),
                                                checked = uiState.bell,
                                                onCheckedChange = onBellChange,
                                            )
                                            if (uiState.bell) {
                                                SliderPreference(
                                                    title = stringResource(R.string.pref_bell_volume_title),
                                                    value = uiState.bellVolume,
                                                    onValueChange = onBellVolumeChange,
                                                )
                                            }
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_bell_vibrate_title),
                                                summary = stringResource(R.string.pref_bell_vibrate_summary),
                                                checked = uiState.bellVibrate,
                                                onCheckedChange = onBellVibrateChange,
                                            )
                                        }
                                    }
                                    item { SettingsFootnote(stringResource(R.string.pref_service_notification_visibility)) }
                                }

                                "security" -> {
                                    item {
                                        SettingsGroup {
                                            if (uiState.canAuthenticate) {
                                                SwitchPreference(
                                                    title = stringResource(R.string.pref_auth_on_launch_title),
                                                    summary = stringResource(R.string.pref_auth_on_launch_summary),
                                                    checked = uiState.authOnLaunch,
                                                    onCheckedChange = onAuthOnLaunchChange,
                                                )
                                            }
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_memkeys_title),
                                                summary = stringResource(R.string.pref_memkeys_summary),
                                                checked = uiState.memkeys,
                                                onCheckedChange = onMemkeysChange,
                                            )
                                        }
                                    }
                                    item { PreferenceCategory(stringResource(R.string.settings_backup)) }
                                    item {
                                        SettingsGroup {
                                            SwitchPreference(
                                                title = stringResource(R.string.pref_backupkeys_title),
                                                summary = stringResource(R.string.pref_backupkeys_summary),
                                                checked = uiState.backupkeys,
                                                onCheckedChange = onBackupkeysChange,
                                            )
                                        }
                                    }
                                    item { SettingsFootnote(stringResource(R.string.pref_android_backup_summary)) }
                                }

                                "colors" -> {
                                    item { TerminalPreview(uiState, selectedPalette) }
                                    item { SettingsFootnote(stringResource(R.string.settings_color_profile, uiState.availableProfiles.firstOrNull { it.id == (uiState.defaultProfileId.takeIf { id -> id != 0L } ?: 1L) }?.name ?: "Default")) }
                                    item { ColorPresetGrid(colorOptions, selectedSchemeId, wide, onColorSchemeChange) }
                                    item { TextButton(onClick = onEditPalette) { Text(stringResource(R.string.settings_edit_palette)) } }
                                }

                                "keybar" -> {
                                    item { KeybarEditor(uiState.terminalBarLayout, onTerminalBarLayoutChange) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (uiState.fontDownloadInProgress) {
        FontDownloadProgressDialog()
    }
}

private enum class SettingsCategory(val id: String, val title: Int, val icon: ImageVector) {
    DISPLAY("display", R.string.settings_display, Icons.Default.Palette),
    KEYBOARD("keyboard", R.string.pref_keyboard_category, Icons.Default.Keyboard),
    GESTURE("gesture", R.string.settings_gestures, Icons.Default.Swipe),
    TERMINAL("terminal", R.string.settings_terminal, Icons.Default.Terminal),
    CONNECTION("connection", R.string.settings_connection, Icons.Default.Notifications),
    SECURITY("security", R.string.settings_security_backup, Icons.Default.Lock),
}

data class SettingsColorOption(val id: Long, val palette: ColorSchemePresets.PresetScheme)

private val builtInColorOptions = ColorSchemePresets.builtInSchemes.mapIndexed { index, palette ->
    SettingsColorOption(-(index + 1L), palette)
}

@Composable
private fun settingsCategorySummary(category: SettingsCategory, state: SettingsUiState, schemeName: String): String = when (category) {
    SettingsCategory.DISPLAY -> {
        val theme = when (state.themeMode) {
            ThemeMode.SYSTEM -> R.string.pref_theme_system
            ThemeMode.LIGHT -> R.string.pref_theme_light
            ThemeMode.DARK -> R.string.pref_theme_dark
        }
        stringResource(theme) + " · " + schemeName + " · " + stringResource(R.string.pref_terminal_margin_value, state.terminalMargin)
    }

    SettingsCategory.KEYBOARD -> stringResource(R.string.settings_keybar_summary, state.terminalBarLayout.keyHeight) +
        if (state.terminalBarLayout.groupFunctionKeys && TerminalBarKey.FUNCTION_KEYS in state.terminalBarLayout.visibleKeys) " · Fn" else ""

    SettingsCategory.GESTURE -> when {
        state.swipeTmux -> stringResource(R.string.pref_swipe_tmux_title)
        state.swipeSessions -> stringResource(R.string.pref_swipe_sessions_title)
        state.pgupdngesture -> stringResource(R.string.pref_pg_updn_gesture_title)
        else -> stringResource(R.string.settings_off)
    }

    SettingsCategory.TERMINAL -> stringResource(R.string.settings_scrollback_value, state.scrollback)

    SettingsCategory.CONNECTION -> stringResource(if (state.connectionAlerts) R.string.settings_alerts_on else R.string.settings_alerts_off)

    SettingsCategory.SECURITY -> stringResource(if (state.authOnLaunch) R.string.pref_auth_on_launch_title else R.string.settings_auth_off)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsToolbar(title: String, onBack: (() -> Unit)?) {
    TopAppBar(
        title = { Text(title) },
        navigationIcon = {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.button_navigate_up))
                }
            }
        },
    )
}

@Composable
private fun SettingsGroup(content: @Composable () -> Unit) {
    Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
        Column { content() }
    }
}

@Composable
private fun SettingsFootnote(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SegmentedPreference(title: String, value: String, entries: List<Pair<String, String>>, onValueChange: (String) -> Unit) {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, style = MaterialTheme.typography.bodyLarge)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            entries.forEachIndexed { index, (label, entry) ->
                SegmentedButton(
                    selected = value == entry,
                    onClick = { onValueChange(entry) },
                    shape = SegmentedButtonDefaults.itemShape(index, entries.size),
                ) { Text(label, maxLines = 1) }
            }
        }
    }
}

@Composable
private fun MarginPreference(value: Int, onChange: (Int) -> Unit) {
    FlowRow(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(0, 2, 4, 8, 12, 16, 24).forEach { margin ->
            FilterChip(selected = value == margin, onClick = { onChange(margin) }, label = { Text(stringResource(R.string.pref_terminal_margin_value, margin)) })
        }
    }
}

@Composable
private fun ScrollbackPreference(value: String, onChange: (String) -> Unit) {
    val steps = listOf(140, 500, 1000, 2000, 5000, 10000, 20000)
    val current = value.toIntOrNull() ?: steps.first()
    var editing by remember { mutableStateOf(false) }
    ListItem(
        headlineContent = { Text(stringResource(R.string.pref_scrollback_title)) },
        supportingContent = { Text(stringResource(R.string.pref_scrollback_summary)) },
        trailingContent = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { steps.lastOrNull { it < current }?.let { onChange(it.toString()) } }, enabled = current > steps.first()) {
                    Icon(Icons.Default.Remove, stringResource(R.string.settings_decrease_scrollback))
                }
                TextButton(onClick = { editing = true }) { Text(value) }
                IconButton(onClick = { steps.firstOrNull { it > current }?.let { onChange(it.toString()) } }, enabled = current < steps.last()) {
                    Icon(Icons.Default.Add, stringResource(R.string.settings_increase_scrollback))
                }
            }
        },
        modifier = Modifier.clickable { editing = true },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    )
    if (editing) {
        TextPreferenceDialog(
            title = stringResource(R.string.pref_scrollback_title),
            value = value,
            onDismiss = { editing = false },
            onConfirm = { input ->
                input.toIntOrNull()?.takeIf { it > 0 }?.let {
                    onChange(it.toString())
                    editing = false
                }
            },
        )
    }
}

@Composable
private fun TerminalPreview(state: SettingsUiState, palette: ColorSchemePresets.PresetScheme) {
    val background = Color(palette.colors[palette.defaultBg])
    val foreground = Color(palette.colors[palette.defaultFg])
    val font = org.connectbot.util.rememberTerminalTypefaceResultFromStoredValue(state.fontFamily)
    val family = FontFamily(font.typeface)
    Surface(color = background, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(state.terminalMargin.dp).padding(vertical = 12.dp)) {
            Text("user@fold:~/shell $", color = Color(palette.colors[2]), fontFamily = family, fontSize = 12.sp, maxLines = 1)
            Text("Android Shell · SSH / Mosh", color = foreground, fontFamily = family, fontSize = 12.sp, maxLines = 1)
            Text("vim 한글.md ▌", color = foreground, fontFamily = family, fontSize = 12.sp, maxLines = 1)
            Text("[work] 0:zsh*  1:vim  2:logs", color = background, fontFamily = family, fontSize = 12.sp, maxLines = 1, modifier = Modifier.fillMaxWidth().background(Color(palette.colors[2])))
        }
    }
}

@Composable
private fun ColorPresetGrid(options: List<SettingsColorOption>, selectedId: Long, wide: Boolean, onSelect: (Long) -> Unit) {
    val columns = if (wide) 3 else 2
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        options.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { option ->
                    val palette = option.palette
                    Surface(
                        onClick = { onSelect(option.id) },
                        shape = RoundedCornerShape(16.dp),
                        border = if (option.id == selectedId) androidx.compose.foundation.BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        modifier = Modifier.weight(1f).semantics { selected = option.id == selectedId },
                    ) {
                        Column {
                            Column(Modifier.fillMaxWidth().background(Color(palette.colors[palette.defaultBg])).padding(12.dp)) {
                                Text("~ $ ls", color = Color(palette.colors[palette.defaultFg]), fontFamily = FontFamily.Monospace, fontSize = 11.sp)
                                Text("src  build", color = Color(palette.colors[4]), fontFamily = FontFamily.Monospace, fontSize = 11.sp)
                                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(top = 4.dp)) {
                                    (1..6).forEach { color -> Box(Modifier.size(10.dp).clip(CircleShape).background(Color(palette.colors[color]))) }
                                }
                            }
                            Text(palette.name, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
                repeat(columns - row.size) { Box(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun KeybarEditor(layout: TerminalBarLayout, onChange: (TerminalBarLayout) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SettingsGroup {
            TerminalKeyboardContent(
                modifierState = ModifierState(ModifierLevel.OFF, ModifierLevel.OFF, ModifierLevel.OFF),
                onCtrlPress = {}, onAltPress = {}, onEscPress = {}, onTabPress = {}, onKeyPress = {},
                onInteraction = {}, onHideIme = {}, onShowIme = {}, onScrollInProgressChange = {},
                imeVisible = false, playAnimation = false, bumpyArrows = false, layout = layout,
            )
        }
        SegmentedPreference(
            title = stringResource(R.string.settings_keybar_height),
            value = layout.keyHeight.toString(),
            entries = TerminalBarLayout.heights.map { stringResource(R.string.pref_terminal_margin_value, it) to it.toString() },
            onValueChange = { onChange(layout.copy(keyHeight = it.toInt())) },
        )
        PreferenceCategory(stringResource(R.string.settings_scroll_keys))
        SettingsGroup {
            layout.order.forEachIndexed { index, barKey ->
                ListItem(
                    headlineContent = { Text(barKey.label) },
                    trailingContent = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(enabled = index > 0, onClick = {
                                val order = layout.order.toMutableList()
                                java.util.Collections.swap(order, index, index - 1)
                                onChange(layout.copy(order = order))
                            }) { Icon(Icons.Default.ArrowUpward, stringResource(R.string.settings_move_key_up, barKey.label)) }
                            IconButton(enabled = index < layout.order.lastIndex, onClick = {
                                val order = layout.order.toMutableList()
                                java.util.Collections.swap(order, index, index + 1)
                                onChange(layout.copy(order = order))
                            }) { Icon(Icons.Default.ArrowDownward, stringResource(R.string.settings_move_key_down, barKey.label)) }
                            Switch(
                                checked = barKey !in layout.hidden,
                                onCheckedChange = { visible -> onChange(layout.copy(hidden = if (visible) layout.hidden - barKey else layout.hidden + barKey)) },
                            )
                        }
                    },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                )
            }
        }
        SettingsFootnote(stringResource(R.string.settings_fixed_keys))
        SettingsGroup {
            SwitchPreference(
                title = stringResource(R.string.settings_fn_group),
                summary = stringResource(R.string.settings_fn_group_summary),
                checked = layout.groupFunctionKeys,
                onCheckedChange = { onChange(layout.copy(groupFunctionKeys = it)) },
            )
        }
        TextButton(onClick = { onChange(TerminalBarLayout()) }) { Text(stringResource(R.string.settings_reset_keybar)) }
    }
}

private fun buildAvailableLanguageList(context: android.content.Context): List<Pair<String, String>> {
    val localeTags = mutableListOf<String>()
    val parser = context.resources.getXml(R.xml._generated_res_locale_config)
    while (parser.next() != XmlPullParser.END_DOCUMENT) {
        if (parser.eventType == XmlPullParser.START_TAG && parser.name == "locale") {
            val tag = parser.getAttributeValue(
                "http://schemas.android.com/apk/res/android",
                "name",
            )
            if (tag != null) {
                localeTags.add(tag)
            }
        }
    }
    parser.close()
    return localeTags
        .map { tag ->
            val locale = Locale.forLanguageTag(tag)
            val canonicalTag = locale.toLanguageTag()
            val nativeName = locale.getDisplayName(locale)
                .replaceFirstChar { it.titlecase(locale) }
            canonicalTag to nativeName
        }
        .distinctBy { it.first }
        .sortedBy { it.second.lowercase() }
}

@Composable
private fun PreferenceCategory(
    title: String,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
        )
    }
}

@Composable
private fun SwitchPreference(
    title: String,
    summary: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    highlightColor: Color = Color.Transparent,
) {
    Column(modifier = modifier) {
        ListItem(
            supportingContent = { Text(summary) },
            trailingContent = {
                Switch(
                    checked = checked,
                    onCheckedChange = onCheckedChange,
                )
            },
            colors = ListItemDefaults.colors(
                containerColor = highlightColor,
            ),
            modifier = Modifier.clickable { onCheckedChange(!checked) },
        ) { Text(title) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun NotificationChannelsPreference(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        ListItem(
            trailingContent = { Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null) },
            modifier = Modifier.clickable(onClick = onClick),
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        ) { Text(stringResource(R.string.pref_notification_channels_title)) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun TextPreference(
    title: String,
    summary: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showDialog by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        ListItem(
            supportingContent = { Text(summary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable { showDialog = true },
        ) { Text(title) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)

        if (showDialog) {
            TextPreferenceDialog(
                title = title,
                value = value,
                onDismiss = { showDialog = false },
                onConfirm = { newValue ->
                    onValueChange(newValue)
                    showDialog = false
                },
            )
        }
    }
}

@Composable
private fun TextPreferenceDialog(
    title: String,
    value: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var textValue by remember { mutableStateOf(value) }

    TextInputAlertDialog(
        onDismissRequest = onDismiss,
        onConfirm = { onConfirm(textValue) },
        value = textValue,
        onValueChange = { textValue = it },
        dismissButtonText = stringResource(R.string.delete_neg),
        title = { Text(title) },
    )
}

@Composable
private fun ListPreference(
    title: String,
    summary: String,
    value: String,
    entries: List<Pair<String, String>>,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showDialog by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        ListItem(
            supportingContent = { Text(summary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable { showDialog = true },
        ) { Text(title) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)

        if (showDialog) {
            ListPreferenceDialog(
                title = title,
                value = value,
                entries = entries,
                onDismiss = { showDialog = false },
                onConfirm = { newValue ->
                    onValueChange(newValue)
                    showDialog = false
                },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListPreferenceDialog(
    title: String,
    value: String,
    entries: List<Pair<String, String>>,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp))
        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
            entries.forEach { (label, entryValue) ->
                ListItem(
                    leadingContent = { RadioButton(selected = value == entryValue, onClick = null) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    modifier = Modifier.clickable { onConfirm(entryValue) },
                ) { Text(label) }
            }
        }
    }
}

@Composable
private fun LanguageListPreference(
    title: String,
    summary: String,
    value: String,
    entries: List<Pair<String, String>>,
    downloadStates: Map<String, LanguageDownloadState>,
    installedLanguages: Set<String>,
    onEntryClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showDialog by remember { mutableStateOf(false) }
    var pendingDownloadTag by remember { mutableStateOf<String?>(null) }

    // Close dialog once a pending download completes successfully (download state cleared + language installed)
    LaunchedEffect(downloadStates, installedLanguages) {
        val pendingTag = pendingDownloadTag
        if (pendingTag != null && downloadStates[pendingTag] == null && installedLanguages.contains(pendingTag)) {
            showDialog = false
            pendingDownloadTag = null
        }
    }

    Column(modifier = modifier) {
        ListItem(
            supportingContent = { Text(summary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable { showDialog = true },
        ) { Text(title) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)

        if (showDialog) {
            LanguageListPreferenceDialog(
                title = title,
                value = value,
                entries = entries,
                downloadStates = downloadStates,
                installedLanguages = installedLanguages,
                onDismiss = {
                    showDialog = false
                    pendingDownloadTag = null
                },
                onEntryClick = { tag ->
                    val needsDownload = tag.isNotEmpty() && !installedLanguages.contains(tag)
                    onEntryClick(tag)
                    if (needsDownload) {
                        pendingDownloadTag = tag
                    } else {
                        showDialog = false
                    }
                },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LanguageListPreferenceDialog(
    title: String,
    value: String,
    entries: List<Pair<String, String>>,
    downloadStates: Map<String, LanguageDownloadState>,
    installedLanguages: Set<String>,
    onDismiss: () -> Unit,
    onEntryClick: (String) -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp))
        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
            entries.forEach { (label, tag) ->
                val state = downloadStates[tag]
                val isDownloading = state is LanguageDownloadState.Downloading
                val needsDownload = tag.isNotEmpty() && !installedLanguages.contains(tag)
                ListItem(
                    leadingContent = { RadioButton(selected = value == tag, onClick = null) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    trailingContent = when {
                        isDownloading -> {
                            {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(24.dp),
                                    strokeWidth = 2.dp,
                                )
                            }
                        }

                        state is LanguageDownloadState.Failed -> {
                            {
                                Icon(
                                    imageVector = Icons.Filled.Error,
                                    contentDescription = stringResource(R.string.pref_language_download_failed),
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }

                        needsDownload -> {
                            {
                                Icon(
                                    imageVector = Icons.Filled.Download,
                                    contentDescription = stringResource(R.string.pref_language_download),
                                )
                            }
                        }

                        else -> null
                    },
                    modifier = if (isDownloading) Modifier else Modifier.clickable { onEntryClick(tag) },
                ) { Text(label) }
            }
        }
    }
}

@Composable
private fun ListPreferenceWithCustom(
    title: String,
    summary: String,
    value: String,
    entries: List<Pair<String, String>>,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    customLabel: String = "Custom...",
) {
    var showDialog by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        ListItem(
            supportingContent = { Text(summary) },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            modifier = Modifier.clickable { showDialog = true },
        ) { Text(title) }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)

        if (showDialog) {
            ListPreferenceWithCustomDialog(
                title = title,
                value = value,
                entries = entries,
                customLabel = customLabel,
                onDismiss = { showDialog = false },
                onConfirm = { newValue ->
                    onValueChange(newValue)
                    showDialog = false
                },
            )
        }
    }
}

@Composable
private fun ListPreferenceWithCustomDialog(
    title: String,
    value: String,
    entries: List<Pair<String, String>>,
    customLabel: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var showCustomInput by remember { mutableStateOf(false) }
    var customValue by remember { mutableStateOf(value) }

    if (showCustomInput) {
        TextInputAlertDialog(
            onDismissRequest = {
                showCustomInput = false
                onDismiss()
            },
            onConfirm = {
                showCustomInput = false
                onConfirm(customValue)
            },
            value = customValue,
            onValueChange = { customValue = it },
            confirmEnabled = customValue.isNotBlank(),
            title = { Text(title) },
            label = { Text(stringResource(R.string.dialog_custom_value_label)) },
        )
    } else {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text(title) },
            text = {
                Column {
                    entries.forEach { (label, entryValue) ->
                        ListItem(
                            modifier = Modifier.clickable { onConfirm(entryValue) },
                        ) { Text(label) }
                    }
                    HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                    ListItem(
                        modifier = Modifier.clickable {
                            customValue = value
                            showCustomInput = true
                        },
                    ) {
                        Text(
                            text = customLabel,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.delete_neg))
                }
            },
        )
    }
}

@Composable
private fun SliderPreference(
    title: String,
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
            )
            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = 0f..1f,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
            )
            Text(
                text = "${(value * 100).toInt()}%",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }
}

@Composable
private fun AddCustomTerminalTypePreference(
    customTerminalTypes: List<String>,
    onAddTerminalType: (String) -> Unit,
    onRemoveTerminalType: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showAddDialog by remember { mutableStateOf(false) }
    var newTerminalType by remember { mutableStateOf("") }

    Column(modifier = modifier) {
        ListItem(
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            supportingContent = { Text(stringResource(R.string.pref_customterminal_summary)) },
            modifier = Modifier.clickable { showAddDialog = true },
        ) { Text(stringResource(R.string.pref_customterminal_title)) }

        // Show existing custom terminal types with remove option
        customTerminalTypes.forEach { terminalType ->
            ListItem(
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                leadingContent = {
                    Icon(
                        imageVector = Icons.Default.Terminal,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                },
                trailingContent = {
                    IconButton(onClick = { onRemoveTerminalType(terminalType) }) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = stringResource(R.string.button_remove),
                        )
                    }
                },
                modifier = Modifier.padding(start = 16.dp),
            ) { Text(terminalType) }
        }

        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }

    if (showAddDialog) {
        TextInputAlertDialog(
            onDismissRequest = {
                showAddDialog = false
                newTerminalType = ""
            },
            onConfirm = {
                if (newTerminalType.isNotBlank()) {
                    onAddTerminalType(newTerminalType.trim())
                    showAddDialog = false
                    newTerminalType = ""
                }
            },
            value = newTerminalType,
            onValueChange = { newTerminalType = it },
            confirmEnabled = newTerminalType.isNotBlank(),
            confirmButtonText = stringResource(R.string.button_add),
            dismissButtonText = stringResource(R.string.delete_neg),
            title = { Text(stringResource(R.string.dialog_customterminal_title)) },
            label = { Text(stringResource(R.string.dialog_customterminal_hint)) },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddCustomFontPreference(
    customFonts: List<String>,
    validationInProgress: Boolean,
    validationError: String?,
    onAddFont: (String) -> Unit,
    onRemoveFont: (String) -> Unit,
    onClearError: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var showAddDialog by remember { mutableStateOf(false) }
    var newFontName by remember { mutableStateOf("") }

    // Show error snackbar if there's an error
    LaunchedEffect(validationError) {
        if (validationError != null) {
            // Error is shown in dialog, will be cleared when dialog closes
        }
    }

    Column(modifier = modifier) {
        ListItem(
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            supportingContent = { Text(stringResource(R.string.pref_customfont_summary)) },
            modifier = Modifier.clickable { showAddDialog = true },
        ) { Text(stringResource(R.string.pref_customfont_title)) }

        // Show existing custom fonts with remove option
        customFonts.forEach { fontName ->
            ListItem(
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                leadingContent = {
                    Icon(
                        imageVector = Icons.Default.FontDownload,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                },
                trailingContent = {
                    IconButton(onClick = { onRemoveFont(fontName) }) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = stringResource(R.string.button_remove),
                        )
                    }
                },
                modifier = Modifier.padding(start = 16.dp),
            ) { Text(fontName) }
        }

        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }

    if (showAddDialog) {
        TextInputAlertDialog(
            onDismissRequest = {
                if (!validationInProgress) {
                    showAddDialog = false
                    newFontName = ""
                    onClearError()
                }
            },
            onConfirm = {
                if (newFontName.isNotBlank() && !validationInProgress) {
                    onAddFont(newFontName.trim())
                }
            },
            value = newFontName,
            onValueChange = {
                newFontName = it
                onClearError()
            },
            confirmEnabled = newFontName.isNotBlank() && !validationInProgress,
            dismissEnabled = !validationInProgress,
            confirmButtonText = stringResource(R.string.button_add),
            enabled = !validationInProgress,
            title = { Text(stringResource(R.string.dialog_customfont_title)) },
            label = { Text(stringResource(R.string.dialog_customfont_hint)) },
            supportingText = if (validationError != null) {
                { Text(validationError, color = MaterialTheme.colorScheme.error) }
            } else if (validationInProgress) {
                { Text(stringResource(R.string.font_validating)) }
            } else {
                null
            },
            isError = validationError != null,
            keyboardOptions = KeyboardOptions(
                autoCorrectEnabled = false,
                imeAction = ImeAction.Done,
            ),
        )
    }

    // Close dialog when font is successfully added
    LaunchedEffect(customFonts.size) {
        if (showAddDialog && !validationInProgress && validationError == null && newFontName.isNotBlank()) {
            // Font was added successfully
            showAddDialog = false
            newFontName = ""
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LocalFontPreference(
    localFonts: List<Pair<String, String>>,
    importInProgress: Boolean,
    importError: String?,
    onImportFont: (Uri, String) -> Unit,
    onDeleteFont: (String) -> Unit,
    onClearError: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var pendingUri by remember { mutableStateOf<Uri?>(null) }
    var showNameDialog by remember { mutableStateOf(false) }
    var fontDisplayName by remember { mutableStateOf("") }

    val fontPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            pendingUri = uri
            fontDisplayName = ""
            showNameDialog = true
        }
    }

    Column(modifier = modifier) {
        ListItem(
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            supportingContent = {
                Text(
                    if (importInProgress) {
                        stringResource(R.string.font_importing)
                    } else {
                        stringResource(R.string.pref_localfont_summary)
                    },
                )
            },
            modifier = Modifier.clickable(enabled = !importInProgress) {
                fontPickerLauncher.launch(arrayOf("font/*", "application/x-font-ttf", "application/x-font-otf"))
            },
        ) { Text(stringResource(R.string.pref_localfont_title)) }

        // Show existing local fonts with delete option
        localFonts.forEach { (displayName, fileName) ->
            ListItem(
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                leadingContent = {
                    Icon(
                        imageVector = Icons.Default.FolderOpen,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                },
                trailingContent = {
                    IconButton(onClick = { onDeleteFont(fileName) }) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = stringResource(R.string.button_remove),
                        )
                    }
                },
                modifier = Modifier.padding(start = 16.dp),
            ) { Text(displayName) }
        }

        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
    }

    // Dialog to get display name for imported font
    if (showNameDialog) {
        TextInputAlertDialog(
            onDismissRequest = {
                if (!importInProgress) {
                    showNameDialog = false
                    pendingUri = null
                    fontDisplayName = ""
                    onClearError()
                }
            },
            onConfirm = {
                pendingUri?.let { uri ->
                    if (fontDisplayName.isNotBlank() && !importInProgress) {
                        onImportFont(uri, fontDisplayName.trim())
                    }
                }
            },
            value = fontDisplayName,
            onValueChange = {
                fontDisplayName = it
                onClearError()
            },
            confirmEnabled = fontDisplayName.isNotBlank() && !importInProgress,
            dismissEnabled = !importInProgress,
            confirmButtonText = stringResource(R.string.button_import),
            enabled = !importInProgress,
            title = { Text(stringResource(R.string.dialog_localfont_title)) },
            label = { Text(stringResource(R.string.dialog_localfont_hint)) },
            supportingText = if (importError != null) {
                { Text(importError, color = MaterialTheme.colorScheme.error) }
            } else if (importInProgress) {
                { Text(stringResource(R.string.font_importing)) }
            } else {
                null
            },
            isError = importError != null,
        )
    }

    // Close dialog when font is successfully imported
    LaunchedEffect(localFonts.size) {
        if (showNameDialog && !importInProgress && importError == null && fontDisplayName.isNotBlank()) {
            showNameDialog = false
            pendingUri = null
            fontDisplayName = ""
        }
    }
}

@PreviewScreen
@Composable
private fun SettingsScreenPreview() {
    ConnectBotTheme {
        SettingsScreenContent(
            uiState = SettingsUiState(
                authOnLaunch = false,
                canAuthenticate = true,
                memkeys = true,
                connectionAlerts = true,
                wifilock = false,
                backupkeys = true,
                scrollback = "500",
                rotation = "Default",
                titlebarhide = false,
                fullscreen = true,
                pgupdngesture = true,
                swipeSessions = false,
                volumefont = true,
                keepalive = true,
                alwaysvisible = true,
                imeTogglekey = true,
                imeShortcutInputMode = ImeShortcutInputMode.FORCE_ASCII,
                shiftfkeys = false,
                ctrlfkeys = false,
                stickymodifiers = "yes",
                keymode = "Use right-side keys",
                camera = "Ctrl+A then Space",
                bumpyarrows = true,
                bell = true,
                bellVolume = 0.75f,
                bellVibrate = true,
                bellNotification = false,
                fontFamily = "JETBRAINS_MONO",
                customFonts = listOf("Cascadia Code", "Hack"),
                customTerminalTypes = listOf("rxvt-unicode", "tmux-256color"),
                localFonts = listOf("My Custom Font" to "my_custom_font.ttf"),
                fontValidationInProgress = false,
                fontValidationError = null,
                fontImportInProgress = false,
                fontImportError = null,
            ),
            onNavigateBack = {},
            onAuthOnLaunchChange = {},
            onMemkeysChange = {},
            onConnectionAlertsChange = {},
            onWifilockChange = {},
            onBackupkeysChange = {},
            onScrollbackChange = {},
            onAddCustomTerminalType = {},
            onRemoveCustomTerminalType = {},
            onFontFamilyChange = {},
            onAddCustomFont = {},
            onRemoveCustomFont = {},
            onClearFontError = {},
            onImportLocalFont = { _, _ -> },
            onDeleteLocalFont = {},
            onClearImportError = {},
            onDefaultProfileChange = {},
            onLanguageChange = {},
            onThemeModeChange = {},
            onRotationChange = {},
            onFullscreenChange = {},
            onTitleBarHideChange = {},
            onPgUpDnGestureChange = {},
            onSwipeSessionsChange = {},
            onVolumeFontChange = {},
            onKeepAliveChange = {},
            onAlwaysVisibleChange = {},
            onImeToggleKeyChange = {},
            onImeShortcutInputModeChange = {},
            onShiftFkeysChange = {},
            onCtrlFkeysChange = {},
            onStickyModifiersChange = {},
            onKeyModeChange = {},
            onCameraChange = {},
            onBumpyArrowsChange = {},
            onBellChange = {},
            onBellVolumeChange = {},
            onBellVibrateChange = {},
            onBellNotificationChange = {},
            onConnectionLostNotificationChange = {},
            onNotificationSettingsClick = {},
        )
    }
}

@Composable
private fun NotificationPermissionDeniedDialog(
    onDismiss: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.connection_alert_permission_denied_title)) },
        text = { Text(stringResource(R.string.connection_alert_permission_denied_message)) },
        confirmButton = {
            TextButton(onClick = onOpenSettings) {
                Text(stringResource(R.string.open_settings))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(android.R.string.cancel))
            }
        },
    )
}
