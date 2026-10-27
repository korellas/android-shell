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

import android.Manifest
import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import dagger.hilt.android.AndroidEntryPoint
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import org.connectbot.data.ColorSchemeRepository
import org.connectbot.data.ConnectBotDatabase
import org.connectbot.data.HostRepository
import org.connectbot.data.ProfileRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.ui.AppViewModel
import org.connectbot.ui.screens.settings.SettingsViewModel
import javax.inject.Inject

@AndroidEntryPoint
class FlutterShellActivity : FlutterFragmentActivity() {
    @Inject lateinit var sessionRuntime: FlutterSessionRuntime

    @Inject lateinit var hosts: HostRepository

    @Inject lateinit var profiles: ProfileRepository

    @Inject lateinit var keys: PubkeyRepository

    @Inject lateinit var colors: ColorSchemeRepository

    @Inject lateinit var database: ConnectBotDatabase

    @Inject lateinit var biometricKeys: org.connectbot.util.BiometricKeyManager

    @Inject lateinit var passwords: org.connectbot.util.SecurePasswordStorage

    @Inject lateinit var preferences: android.content.SharedPreferences

    @Inject lateinit var dispatchers: CoroutineDispatchers
    val appState: AppViewModel by viewModels()
    val settings: SettingsViewModel by viewModels()
    internal lateinit var engine: AndroidShellEngine
    internal val logs: org.connectbot.ui.screens.help.LogViewerViewModel by viewModels()
    private var documentResult: CompletableDeferred<android.net.Uri?>? = null
    private val openDocument = registerForActivityResult(ActivityResultContracts.OpenDocument()) {
        documentResult?.complete(it)
        documentResult = null
    }
    private val createDocument = registerForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) {
        documentResult?.complete(it)
        documentResult = null
    }
    suspend fun pickDocument(types: Array<String>): android.net.Uri? {
        check(documentResult == null) { "파일 선택이 진행 중입니다." }
        val pending = CompletableDeferred<android.net.Uri?>()
        documentResult = pending
        openDocument.launch(types)
        return pending.await()
    }
    suspend fun createDocument(name: String): android.net.Uri? {
        check(documentResult == null) { "파일 선택이 진행 중입니다." }
        val pending = CompletableDeferred<android.net.Uri?>()
        documentResult = pending
        createDocument.launch(name)
        return pending.await()
    }
    private var permissionResult: CompletableDeferred<Boolean>? = null
    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) {
        settings.onNotificationPermissionResult(it)
        appState.onNotificationPermissionResult(it)
        permissionResult?.complete(it)
        permissionResult = null
    }
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine = sessionRuntime.acquireEngine()

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun createFlutterFragment(): FlutterFragment = super.createFlutterFragment().apply {
        // The new-engine builder sets this flag even for an Activity-provided engine.
        // Keep the runtime-owned engine alive when this Fragment is recreated.
        requireArguments().putBoolean("destroy_engine_with_fragment", false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = AndroidShellEngine(this, flutterEngine, hosts, profiles, keys, colors, database)
        engine.handleIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        lifecycleScope.launch { settings.requestNotificationPermission.collect { requestNotifications() } }
        lifecycleScope.launch { settings.openNotificationChannelSettings.collect { startActivity(it) } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (::engine.isInitialized) engine.handleIntent(intent)
    }

    suspend fun requestNotifications(): Boolean {
        permissionResult?.let { return it.await() }
        val pending = CompletableDeferred<Boolean>()
        permissionResult = pending
        permission.launch(Manifest.permission.POST_NOTIFICATIONS)
        return pending.await()
    }

    suspend fun authenticate(title: String, crypto: BiometricPrompt.CryptoObject? = null, appLock: Boolean = false): BiometricPrompt.AuthenticationResult? {
        val pending = CompletableDeferred<BiometricPrompt.AuthenticationResult?>()
        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    pending.complete(result)
                }
                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    pending.complete(null)
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder().setTitle(title)
            .setAllowedAuthenticators(if (appLock) BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL else BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .apply { if (!appLock) setNegativeButtonText("취소") }.build()
        if (crypto == null) prompt.authenticate(info) else prompt.authenticate(info, crypto)
        pending.invokeOnCompletion { if (pending.isCancelled) prompt.cancelAuthentication() }
        return try {
            pending.await()
        } finally {
            prompt.cancelAuthentication()
        }
    }

    internal fun applyWindowOptions() {
        if (!::engine.isInitialized) return
        val preferences = settings.uiState.value
        val consoleVisible = engine.ready && engine.activeOwner != null && engine.activeSessionId != null
        val controller = androidx.core.view.WindowInsetsControllerCompat(window, window.decorView)
        if (consoleVisible && preferences.fullscreen) {
            controller.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            controller.show(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        }
        requestedOrientation = when (preferences.rotation) {
            org.connectbot.util.PreferenceConstants.ROTATION_LANDSCAPE -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            org.connectbot.util.PreferenceConstants.ROTATION_PORTRAIT -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            org.connectbot.util.PreferenceConstants.ROTATION_AUTO -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
            else -> android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        val live = engine.activeSessionOpen
        if (consoleVisible && preferences.keepalive && live) {
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onDestroy() {
        if (::engine.isInitialized) engine.dispose()
        permissionResult?.cancel()
        documentResult?.cancel()
        super.onDestroy()
    }

    companion object {
        const val DISCONNECT_ACTION = "org.connectbot.action.DISCONNECT"
    }
}
