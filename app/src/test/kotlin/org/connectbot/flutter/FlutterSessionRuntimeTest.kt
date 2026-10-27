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

import android.annotation.TargetApi
import android.content.Context
import android.content.SharedPreferences
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Vibrator
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.connectbot.data.entity.Host
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.service.ConnectionNotifier
import org.connectbot.service.DisconnectReason
import org.connectbot.service.NotificationSession
import org.connectbot.util.PreferenceConstants
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class FlutterSessionRuntimeTest {
    private val dispatcher = StandardTestDispatcher()
    private val application get() = RuntimeEnvironment.getApplication()
    private lateinit var notifier: ConnectionNotifier
    private lateinit var preferences: SharedPreferences
    private var processState = Lifecycle.State.INITIALIZED
    private lateinit var runtime: FlutterSessionRuntime

    @Before
    fun setUp() {
        val dispatchers = CoroutineDispatchers(dispatcher, dispatcher, dispatcher)
        preferences = application.getSharedPreferences("runtime-test", Context.MODE_PRIVATE)
        preferences.edit().clear().putBoolean(PreferenceConstants.BELL, false).commit()
        notifier = Mockito.mock(ConnectionNotifier::class.java)
        processState = ProcessLifecycleOwner.get().lifecycle.currentState
        runtime = FlutterSessionRuntime(
            application,
            dispatchers,
            notifier,
            preferences,
        )
    }

    @After
    fun restoreProcessState() {
        (ProcessLifecycleOwner.get().lifecycle as LifecycleRegistry).currentState = processState
    }

    private fun appVisible(visible: Boolean) {
        (ProcessLifecycleOwner.get().lifecycle as LifecycleRegistry).currentState = if (visible) Lifecycle.State.STARTED else Lifecycle.State.CREATED
    }

    @Test
    @TargetApi(30)
    fun networkQueryRequiresInternetAndValidatedCapabilities() {
        val manager = application.getSystemService(ConnectivityManager::class.java)
        val network = requireNotNull(manager.activeNetwork)
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        shadowOf(manager).setNetworkCapabilities(network, capabilities)
        assertFalse(runtime.networkAvailable())
        shadowOf(capabilities).addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        assertTrue(runtime.networkAvailable())
        shadowOf(capabilities).removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        assertFalse(runtime.networkAvailable())
    }

    @Test
    @TargetApi(30)
    fun pendingNetworkSessionObservesRestorationAndLocalOnlySessionsReleaseCallback() = runTest(dispatcher) {
        val manager = application.getSystemService(ConnectivityManager::class.java)
        val shadow = shadowOf(manager)
        val network = requireNotNull(manager.activeNetwork)
        val capabilities = NetworkCapabilities()
        shadowOf(capabilities).addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        shadow.setNetworkCapabilities(network, capabilities)
        val received = mutableListOf<Any?>()
        runtime.setEngineEventSink(object : io.flutter.plugin.common.EventChannel.EventSink {
            override fun success(event: Any?) {
                received.add(event)
            }
            override fun error(code: String, message: String?, details: Any?) = Unit
            override fun endOfStream() = Unit
        })
        received.clear()
        val pending = NotificationSession("ssh-1", Host(), connected = false, connecting = true)
        runtime.updateSessions(listOf(pending))
        val callback = shadow.networkCallbacks.single()
        runtime.updateSessions(listOf(pending))
        assertEquals(setOf(callback), shadow.networkCallbacks)
        callback.onAvailable(network)
        advanceUntilIdle()
        shadowOf(capabilities).addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        callback.onCapabilitiesChanged(network, capabilities)
        advanceUntilIdle()
        callback.onLost(network)
        advanceUntilIdle()
        assertEquals(listOf(false, true, false).map { mapOf("type" to "networkChanged", "available" to it) }, received)
        runtime.updateSessions(listOf(NotificationSession("local-1", Host.createLocalHost("Local"), connected = true)))
        assertTrue(shadow.networkCallbacks.isEmpty())
        callback.onCapabilitiesChanged(network, capabilities)
        advanceUntilIdle()
        assertEquals(3, received.size)
    }

    @Test
    @Config(sdk = [28])
    fun visibleConsoleBellVibratesInsteadOfPostingNotification() = runTest(dispatcher) {
        val session = NotificationSession("ssh-1", Host(), connected = true)
        runtime.updateSessions(listOf(session))
        appVisible(true)
        runtime.setConsoleVisibility(session.id, true)
        runtime.bell(session.id)
        assertTrue(shadowOf(application.getSystemService(Vibrator::class.java)).isVibrating)
        Mockito.verify(notifier).handleAction(application, ConnectionNotifier.ACTION_SEEN, session.id)
        Mockito.verify(notifier, Mockito.never()).showActivityNotification(application, session)
    }

    @Test
    fun visibleBellUsesRawSoundVolumeAndReleasesPlayerWhenDisabled() = runTest(dispatcher) {
        val session = NotificationSession("ssh-1", Host(), connected = true)
        runtime.updateSessions(listOf(session))
        appVisible(true)
        runtime.setConsoleVisibility(session.id, true)
        preferences.edit().putBoolean(PreferenceConstants.BELL, true)
            .putBoolean(PreferenceConstants.CONNECTION_ALERTS, false)
            .putFloat(PreferenceConstants.BELL_VOLUME, 0.6f).commit()
        Mockito.mockConstruction(MediaPlayer::class.java).use { construction ->
            runtime.bell(session.id)
            val player = construction.constructed().single()
            Mockito.verify(player).setVolume(0.6f, 0.6f)
            Mockito.verify(player).seekTo(0)
            Mockito.verify(player).start()
            preferences.edit().putBoolean(PreferenceConstants.BELL, false).commit()
            runtime.bell(session.id)
            Mockito.verify(player).release()
        }
    }

    @Test
    fun backgroundAndOtherConsoleBellsUseOriginatingSessionAndHonorMasterSwitch() = runTest(dispatcher) {
        val first = NotificationSession("ssh-1", Host(), connected = true)
        val second = NotificationSession("ssh-2", Host(), connected = true)
        runtime.updateSessions(listOf(first, second))
        appVisible(true)
        runtime.setConsoleVisibility(first.id, true)
        runtime.bell(second.id)
        Mockito.verify(notifier).showActivityNotification(application, second)
        appVisible(false)
        runtime.bell(first.id)
        Mockito.verify(notifier).showActivityNotification(application, first)
        preferences.edit().putBoolean(PreferenceConstants.CONNECTION_ALERTS, false).commit()
        runtime.bell(first.id)
        Mockito.verify(notifier, Mockito.times(1)).showActivityNotification(application, first)
    }

    @Test
    @Config(sdk = [24, 28])
    fun individualBellNotificationSwitchIsRespected() = runTest(dispatcher) {
        val session = NotificationSession("ssh-1", Host(), connected = true)
        runtime.updateSessions(listOf(session))
        preferences.edit().putBoolean(PreferenceConstants.BELL_NOTIFICATION, false).commit()
        runtime.bell(session.id)
        Mockito.verify(notifier, Mockito.never()).showActivityNotification(application, session)
    }

    @Test
    @Config(sdk = [28])
    fun departingConsoleCannotHideNewSelectionAndBellPreferenceIsRespected() = runTest(dispatcher) {
        val first = NotificationSession("ssh-1", Host(), connected = true)
        val second = NotificationSession("ssh-2", Host(), connected = true)
        runtime.updateSessions(listOf(first, second))
        appVisible(true)
        runtime.setConsoleVisibility(first.id, true)
        runtime.setConsoleVisibility(second.id, true)
        runtime.setConsoleVisibility(first.id, false)
        runtime.bell(second.id)
        Mockito.verify(notifier, Mockito.never()).showActivityNotification(application, second)
        preferences.edit().putBoolean(PreferenceConstants.BELL_NOTIFICATION, false).commit()
        runtime.bell(first.id)
        Mockito.verify(notifier, Mockito.never()).showActivityNotification(application, first)
    }

    @Test
    @Config(sdk = [24, 28])
    fun individualDisconnectNotificationSwitchIsRespected() = runTest(dispatcher) {
        val session = NotificationSession("ssh-1", Host(), connected = true)
        runtime.updateSessions(listOf(session))
        appVisible(false)
        preferences.edit().putBoolean(PreferenceConstants.CONNECTION_LOST_NOTIFICATION, false).commit()
        runtime.sessionEnded(session.id, DisconnectReason.NETWORK_LOST)
        Mockito.verify(notifier).sessionEnded(application, session.copy(connected = false, connecting = false), DisconnectReason.NETWORK_LOST, false)
    }

    @Test
    fun endNoticesKeepReasonAndSuppressVisibleConsoleAlerts() = runTest(dispatcher) {
        val session = NotificationSession("ssh-1", Host(), connected = true)
        val ended = session.copy(connected = false, connecting = false)
        runtime.updateSessions(listOf(session))
        appVisible(true)
        runtime.setConsoleVisibility(session.id, true)
        runtime.sessionEnded(session.id, DisconnectReason.NETWORK_LOST)
        Mockito.verify(notifier).sessionEnded(application, ended, DisconnectReason.NETWORK_LOST, false)
        appVisible(false)
        runtime.sessionEnded(session.id, DisconnectReason.IO_ERROR)
        Mockito.verify(notifier).sessionEnded(application, ended, DisconnectReason.IO_ERROR, true)
        runtime.sessionEnded(session.id, DisconnectReason.USER_REQUESTED)
        Mockito.verify(notifier).sessionEnded(application, ended, DisconnectReason.USER_REQUESTED, true)
        preferences.edit().putBoolean(PreferenceConstants.CONNECTION_ALERTS, false).commit()
        runtime.sessionEnded(session.id, DisconnectReason.AUTH_FAIL)
        Mockito.verify(notifier).sessionEnded(application, ended, DisconnectReason.AUTH_FAIL, false)
    }

    @Test
    fun connectingSessionStartsServiceBeforeAuthenticationCompletes() = runTest(dispatcher) {
        runtime.updateSessions(listOf(NotificationSession("ssh-1", Host(protocol = "ssh"), connected = false, connecting = true)))

        assertEquals(FlutterSessionService::class.java.name, shadowOf(application).nextStartedService.component!!.className)
    }

    @Test
    fun localShellAlsoKeepsForegroundServiceAlive() = runTest(dispatcher) {
        runtime.updateSessions(listOf(NotificationSession("local-1", Host.createLocalHost("Local"), connected = true)))

        assertEquals(FlutterSessionService::class.java.name, shadowOf(application).nextStartedService.component!!.className)
    }

    @Test
    fun closedSessionsDoNotStartService() = runTest(dispatcher) {
        runtime.updateSessions(listOf(NotificationSession("closed", Host(), connected = false)))

        assertNull(shadowOf(application).nextStartedService)
    }

    @Test
    fun launchConnectionSurvivesUntilDartListensAndIsDeliveredOnce() {
        val received = mutableListOf<Any?>()
        val sink = object : io.flutter.plugin.common.EventChannel.EventSink {
            override fun success(event: Any?) {
                received.add(event)
            }
            override fun error(code: String, message: String?, details: Any?) = Unit
            override fun endOfStream() = Unit
        }
        val connection = mapOf("type" to "connect", "uri" to "ssh://user@example.test")
        runtime.emitEngineEvent(connection)
        runtime.emitEngineEvent(mapOf("type" to "changed"))
        runtime.setEngineEventSink(sink)
        assertEquals(listOf(mapOf("type" to "changed"), connection), received)
        received.clear()
        runtime.setEngineEventSink(null)
        runtime.setEngineEventSink(sink)
        assertEquals(listOf(mapOf("type" to "changed")), received)
    }
}
