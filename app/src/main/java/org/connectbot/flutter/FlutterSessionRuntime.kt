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

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.ase.Exec
import dagger.hilt.android.qualifiers.ApplicationContext
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.connectbot.R
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.service.ConnectionNotifier
import org.connectbot.service.DisconnectReason
import org.connectbot.service.NotificationSession
import org.connectbot.util.PreferenceConstants
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import javax.inject.Inject
import javax.inject.Singleton

/** Application-owned engine and PTYs; no Activity is retained by a running session. */
@Singleton
class FlutterSessionRuntime @Inject constructor(
    @ApplicationContext private val context: Context,
    private val dispatchers: CoroutineDispatchers,
    private val notifier: ConnectionNotifier,
    private val preferences: SharedPreferences,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.io)
    private val operations = Mutex()
    private val locals = mutableMapOf<String, LocalPty>()
    private var engine: FlutterEngine? = null
    private var events: EventChannel.EventSink? = null
    private var commands: MethodChannel? = null
    private var engineEvents: EventChannel.EventSink? = null
    private var pendingConnection: Map<String, Any?>? = null
    private val codecs = SshCodecs()
    private var service: FlutterSessionService? = null
    private var sessions = emptyList<NotificationSession>()
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var observedNetwork: Network? = null
    private var visibleSessionId: String? = null
    private var mediaPlayer: MediaPlayer? = null
    private var wifiLock: WifiManager.WifiLock? = null

    /** Called on the main thread by FlutterActivity.provideFlutterEngine. */
    fun acquireEngine(): FlutterEngine {
        engine?.let { return it }
        val created = FlutterEngine(context)
        EventChannel(created.dartExecutor.binaryMessenger, "dev.korellas.androidshell/local_pty_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                }
                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )
        commands = MethodChannel(created.dartExecutor.binaryMessenger, "dev.korellas.androidshell/runtime")
        EventChannel(created.dartExecutor.binaryMessenger, "dev.korellas.androidshell/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    setEngineEventSink(sink)
                }
                override fun onCancel(arguments: Any?) {
                    setEngineEventSink(null)
                }
            },
        )
        commands?.setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val args = (call.arguments as? Map<String, Any?>).orEmpty()
                    val value = when (call.method) {
                        "runtime.sessions" -> {
                            @Suppress("UNCHECKED_CAST")
                            val records = (args["sessions"] as? List<Map<String, Any?>>).orEmpty()
                            updateSessions(
                                records.map { record ->
                                    @Suppress("UNCHECKED_CAST")
                                    val host = (record["host"] as Map<String, Any?>).toHost()
                                    NotificationSession(record["id"].toString(), host, record["connected"] == true || record["open"] == true, record["connecting"] == true)
                                },
                            )
                            null
                        }

                        "runtime.networkAvailable" -> networkAvailable()

                        "runtime.bell" -> {
                            bell(args.text("id"))
                            null
                        }

                        "runtime.visibility" -> {
                            setConsoleVisibility(args.text("id"), args.flag("visible"))
                            null
                        }

                        "runtime.sessionEnded" -> {
                            sessionEnded(args.text("id"), DisconnectReason.valueOf(args.text("reason")))
                            null
                        }

                        "ssh.decode", "ssh.encode", "ssh.closeCodec" -> synchronized(codecs) { codecs.operation(call.method, args) }

                        "local.start" -> {
                            startLocal(args.text("id"), args.number("columns").toInt(), args.number("rows").toInt(), args.text("term", "xterm-256color"))
                            null
                        }

                        "local.write" -> {
                            writeLocal(args.text("id"), requireNotNull(args["bytes"] as? ByteArray))
                            null
                        }

                        "local.resize" -> {
                            resizeLocal(args.text("id"), args.number("columns").toInt(), args.number("rows").toInt(), args.number("pixelWidth").toInt(), args.number("pixelHeight").toInt())
                            null
                        }

                        "local.close" -> {
                            closeLocal(args.text("id"))
                            null
                        }

                        else -> throw IllegalArgumentException("Unknown runtime method")
                    }
                    withContext(dispatchers.main) { result.success(value) }
                } catch (error: Exception) {
                    withContext(dispatchers.main) { result.error("runtime_error", error.message, null) }
                }
            }
        }
        engine = created
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    internal fun setEngineEventSink(sink: EventChannel.EventSink?) {
        engineEvents = sink
        if (sink != null) {
            sink.success(mapOf("type" to "changed"))
            val connection = pendingConnection
            pendingConnection = null
            connection?.let { sink.success(it) }
        }
    }

    internal fun emitEngineEvent(event: Map<String, Any?>) {
        val sink = engineEvents
        if (sink != null) {
            sink.success(event)
        } else if (event["type"] == "connect") {
            // The launch intent can arrive before Dart subscribes to the cached engine.
            pendingConnection = event.toMap()
        }
    }

    private suspend fun emit(event: Map<String, Any?>) = withContext(dispatchers.main) {
        events?.success(event)
    }

    suspend fun startLocal(id: String, columns: Int, rows: Int, term: String = "xterm-256color") = withContext(dispatchers.io) {
        operations.withLock {
            require(id.isNotBlank())
            require(columns > 0 && rows > 0)
            check(id !in locals) { "Local session already exists" }
            // Set TERM in the child shell rather than changing the process-wide environment.
            require(term.matches(Regex("[A-Za-z0-9._+-]+")))
            val pids = IntArray(1)
            val fd = Exec.createSubprocess("/system/bin/sh", "-c", "export TERM=$term; exec /system/bin/sh -", pids)
            check(fd.valid() && pids[0] > 0) { "Unable to create local shell" }
            val pty = LocalPty(fd, pids[0])
            locals[id] = pty
            try {
                Exec.setPtyWindowSize(fd, rows, columns, 0, 0)
            } catch (error: Throwable) {
                locals.remove(id)
                pty.close()
                throw error
            }
            val reader = scope.launch {
                try {
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = pty.input.read(buffer)
                        if (count < 0) break
                        if (count > 0) {
                            val bytes = buffer.copyOf(count)
                            withContext(dispatchers.main) {
                                if (!pty.closed) events?.success(mapOf("id" to id, "type" to "output", "bytes" to bytes))
                            }
                        }
                    }
                } catch (error: java.io.IOException) {
                    // Closing a PTY, including normal shell exit, interrupts the blocking read.
                }
            }
            scope.launch {
                val code = Exec.waitFor(pty.pid)
                reader.join()
                operations.withLock {
                    if (locals[id] === pty) {
                        locals.remove(id)
                        pty.close(kill = false)
                        emit(mapOf("id" to id, "type" to "exit", "exitCode" to code))
                    }
                }
            }
            Unit
        }
    }

    suspend fun writeLocal(id: String, bytes: ByteArray) = withContext(dispatchers.io) {
        operations.withLock {
            val pty = requireNotNull(locals[id]) { "Local session is closed" }
            pty.output.write(bytes)
            pty.output.flush()
        }
    }

    suspend fun resizeLocal(id: String, columns: Int, rows: Int, pixelWidth: Int = 0, pixelHeight: Int = 0) = withContext(dispatchers.io) {
        require(columns > 0 && rows > 0 && pixelWidth >= 0 && pixelHeight >= 0)
        operations.withLock {
            val pty = requireNotNull(locals[id]) { "Local session is closed" }
            Exec.setPtyWindowSize(pty.fd, rows, columns, pixelWidth, pixelHeight)
        }
    }

    suspend fun closeLocal(id: String) = withContext(dispatchers.io) {
        operations.withLock {
            locals.remove(id)?.close()
            Unit
        }
    }

    private fun NetworkCapabilities?.hasInternet(): Boolean = this != null &&
        hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) && hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

    internal fun networkAvailable(): Boolean {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        return manager.getNetworkCapabilities(manager.activeNetwork).hasInternet()
    }

    private fun updateNetworkObservation(wanted: Boolean) {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        if (wanted && networkCallback == null) {
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    val source = this
                    scope.launch(dispatchers.main) {
                        if (networkCallback === source) {
                            observedNetwork = network
                            emitEngineEvent(mapOf("type" to "networkChanged", "available" to manager.getNetworkCapabilities(network).hasInternet()))
                        }
                    }
                }

                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                    val source = this
                    scope.launch(dispatchers.main) {
                        if (networkCallback === source && observedNetwork == network) {
                            emitEngineEvent(mapOf("type" to "networkChanged", "available" to capabilities.hasInternet()))
                        }
                    }
                }

                override fun onLost(network: Network) {
                    val source = this
                    scope.launch(dispatchers.main) {
                        if (networkCallback === source && observedNetwork == network) {
                            observedNetwork = null
                            emitEngineEvent(mapOf("type" to "networkChanged", "available" to false))
                        }
                    }
                }
            }
            observedNetwork = manager.activeNetwork
            networkCallback = callback
            manager.registerDefaultNetworkCallback(callback)
        } else if (!wanted) {
            networkCallback?.let { manager.unregisterNetworkCallback(it) }
            networkCallback = null
            observedNetwork = null
        }
    }

    private fun isConsoleVisible(id: String): Boolean = visibleSessionId == id &&
        ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)

    private fun notificationEnabled(preference: String): Boolean = preferences.getBoolean(PreferenceConstants.CONNECTION_ALERTS, true) &&
        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O || preferences.getBoolean(preference, true))

    internal suspend fun setConsoleVisibility(id: String, visible: Boolean) = withContext(dispatchers.main) {
        require(id.isNotBlank())
        if (visible) {
            require(sessions.any { it.id == id }) { "Unknown session" }
            visibleSessionId = id
            notifier.handleAction(context, ConnectionNotifier.ACTION_SEEN, id)
        } else if (visibleSessionId == id) {
            visibleSessionId = null
        }
    }

    internal suspend fun bell(id: String) = withContext(dispatchers.main) {
        val session = requireNotNull(sessions.find { it.id == id }) { "Unknown session" }
        if (isConsoleVisible(id)) {
            withContext(dispatchers.io) {
                operations.withLock { playBell() }
            }
        } else if (notificationEnabled(PreferenceConstants.BELL_NOTIFICATION)) {
            notifier.showActivityNotification(context, session)
        }
    }

    internal suspend fun sessionEnded(id: String, reason: DisconnectReason) = withContext(dispatchers.main) {
        val session = requireNotNull(sessions.find { it.id == id }) { "Unknown session" }
        val alert = notificationEnabled(PreferenceConstants.CONNECTION_LOST_NOTIFICATION) && !isConsoleVisible(id)
        notifier.sessionEnded(context, session.copy(connected = false, connecting = false), reason, alert)
    }

    private fun playBell() {
        if (preferences.getBoolean(PreferenceConstants.BELL, true)) {
            val player = mediaPlayer ?: MediaPlayer().also { created ->
                try {
                    created.setAudioAttributes(
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
                    )
                    context.resources.openRawResourceFd(R.raw.bell).use { file ->
                        created.setDataSource(file.fileDescriptor, file.startOffset, file.length)
                    }
                    created.isLooping = false
                    created.prepare()
                    mediaPlayer = created
                } catch (error: Exception) {
                    created.release()
                    throw error
                }
            }
            val volume = preferences.getFloat(PreferenceConstants.BELL_VOLUME, PreferenceConstants.DEFAULT_BELL_VOLUME)
            player.setVolume(volume, volume)
            player.seekTo(0)
            player.start()
        } else {
            releaseBell()
        }
        if (preferences.getBoolean(PreferenceConstants.BELL_VIBRATE, true)) {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Vibrator::class.java)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(30)
            }
        }
    }

    private fun releaseBell() {
        mediaPlayer?.release()
        mediaPlayer = null
    }

    /** Dart supplies immutable snapshots, including local shells and connecting sessions. */
    suspend fun updateSessions(current: List<NotificationSession>) = withContext(dispatchers.main) {
        sessions = current.toList()
        if (sessions.none { it.id == visibleSessionId }) visibleSessionId = null
        val active = sessions.any { it.connected || it.connecting }
        if (active) {
            if (service == null) ContextCompat.startForegroundService(context, Intent(context, FlutterSessionService::class.java))
            service?.let { notifier.showRunningNotification(it, sessions) }
        } else {
            service?.let {
                notifier.hideRunningNotification(it)
                it.stopSelf()
            }
            notifier.updateSessions(context, sessions)
            withContext(dispatchers.io) { operations.withLock { releaseBell() } }
        }
        updateNetworkObservation(sessions.any { (it.connected || it.connecting) && it.host.protocol != "local" })
        updateWifiLock()
    }

    internal fun attachService(attached: FlutterSessionService) {
        service = attached
        if (sessions.none { it.connected || it.connecting }) {
            attached.stopSelf()
        } else {
            notifier.showRunningNotification(attached, sessions)
        }
    }

    internal fun detachService(detached: FlutterSessionService) {
        if (service !== detached) return
        service = null
        updateNetworkObservation(false)
        if (sessions.any { it.connected || it.connecting }) disconnectAll()
        scope.launch {
            operations.withLock {
                locals.values.forEach { it.close() }
                locals.clear()
                releaseBell()
            }
            wifiLock?.let { if (it.isHeld) it.release() }
        }
        notifier.hideRunningNotification(detached)
    }

    internal fun disconnectAll() {
        commands?.invokeMethod("disconnectAll", null)
    }

    @Suppress("DEPRECATION")
    private suspend fun updateWifiLock() {
        val networkActive = sessions.any { (it.connected || it.connecting) && it.host.protocol != "local" }
        withContext(dispatchers.io) {
            updateWifiLock(networkActive)
        }
    }

    @Suppress("DEPRECATION")
    private fun updateWifiLock(networkActive: Boolean) {
        val wanted = networkActive && preferences.getBoolean(PreferenceConstants.WIFI_LOCK, true)
        if (wanted && wifiLock == null) {
            wifiLock = context.getSystemService(WifiManager::class.java).createWifiLock("ConnectBot:FlutterSessions")
        }
        wifiLock?.let {
            if (wanted && !it.isHeld) it.acquire()
            if (!wanted && it.isHeld) it.release()
        }
    }

    private class LocalPty(val fd: FileDescriptor, val pid: Int) {
        val input = FileInputStream(fd)
        val output = FileOutputStream(fd)

        @Volatile var closed = false
            private set

        fun close(kill: Boolean = true) {
            closed = true
            // Kill first: a blocked PTY read must be unblocked before streams are released.
            if (kill) Exec.kill(pid, 9)
            runCatching { output.close() }
            runCatching { input.close() }
        }
    }
}
