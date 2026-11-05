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

import android.content.Intent
import android.content.res.Resources
import androidx.core.content.ContextCompat
import androidx.core.graphics.toColorInt
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.connectbot.R
import org.connectbot.data.ColorSchemeRepository
import org.connectbot.data.ConnectBotDatabase
import org.connectbot.data.HostConfigJson
import org.connectbot.data.HostRepository
import org.connectbot.data.ProfileRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Identity
import org.connectbot.data.entity.PortForward
import org.connectbot.data.entity.Profile
import org.connectbot.service.ConnectionNotifier
import org.connectbot.ui.AppUiState
import java.util.UUID

internal class AndroidShellEngine(
    internal val activity: FlutterShellActivity,
    flutter: FlutterEngine,
    internal val hosts: HostRepository,
    internal val profiles: ProfileRepository,
    internal val keys: PubkeyRepository,
    internal val colors: ColorSchemeRepository,
    internal val database: ConnectBotDatabase,
) : MethodChannel.MethodCallHandler {
    private val methods = MethodChannel(flutter.dartExecutor.binaryMessenger, "dev.korellas.androidshell/engine")
    private val observerJobs = mutableListOf<Job>()
    internal var activeOwner: String? = null
    internal var activeSessionId: Long? = null
    private var pendingIntent: Intent? = null
    internal var activeSessionOpen = false
    private val deletedHosts = mutableMapOf<String, HostRepository.DeletedHost>()
    private var disposed = false

    init {
        methods.setMethodCallHandler(this)
        observerJobs += activity.lifecycleScope.launch {
            activity.appState.uiState.collect {
                changed()
                processIntent()
            }
        }
        observerJobs += activity.lifecycleScope.launch {
            activity.appState.isAuthenticated.collect {
                changed()
                processIntent()
            }
        }
        observerJobs += activity.lifecycleScope.launch { hosts.observeHosts().collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { hosts.observeIdentities().collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { profiles.observeAll().collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { activity.settings.uiState.collect { changed() } }
    }

    internal fun changed() {
        activity.applyWindowOptions()
        if (!disposed) activity.sessionRuntime.emitEngineEvent(mapOf("type" to "changed"))
    }
    internal fun notify(message: String, summary: String = message) {
        if (!disposed) activity.sessionRuntime.emitEngineEvent(mapOf("type" to "message", "message" to message, "summary" to summary))
    }
    private val sortedByColor get() = activity.preferences.getBoolean(org.connectbot.util.PreferenceConstants.SORT_BY_COLOR, false)
    internal val authenticated get() = !activity.appState.authOnLaunchEnabled || activity.appState.isAuthenticated.value
    internal val ready get() = authenticated && activity.appState.uiState.value is AppUiState.Ready

    fun handleIntent(intent: Intent) {
        pendingIntent = Intent(intent)
        processIntent()
    }
    private fun processIntent() {
        if (!ready) return
        val intent = pendingIntent ?: return
        pendingIntent = null
        activity.lifecycleScope.launch {
            try {
                val notified = intent.getStringExtra(ConnectionNotifier.EXTRA_SESSION_ID)?.toLongOrNull()
                if (notified != null) {
                    activity.sessionRuntime.emitEngineEvent(
                        mapOf(
                            "type" to "connect",
                            "id" to notified,
                            "uri" to null,
                            "reconnect" to intent.getBooleanExtra(ConnectionNotifier.EXTRA_RECONNECT, false),
                        ),
                    )
                }
                changed()
            } catch (e: Exception) {
                notify(e.message ?: activity.getString(R.string.flutter_connection_failed))
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        activity.lifecycleScope.launch {
            try {
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>).orEmpty()
                val value = when (call.method) {
                    "snapshot" -> snapshot()

                    "authenticateApp" -> {
                        if (activity.authenticate(activity.getString(R.string.flutter_unlock_tilde), appLock = true) != null) activity.appState.onAuthenticationSuccess()
                        changed()
                        authenticated
                    }

                    "session.visibility" -> execute(call.method, args)

                    "retryMigration" -> {
                        activity.appState.retryMigration()
                        null
                    }

                    else -> {
                        check(ready) { activity.getString(R.string.flutter_wait_for_app_initialization_or_unlock_the_app) }
                        execute(call.method, args)
                    }
                }
                if (!disposed) result.success(value)
            } catch (e: CancellationException) {
                if (!disposed) result.error("cancelled", activity.getString(R.string.flutter_operation_cancelled), null)
                throw e
            } catch (e: Exception) {
                if (!disposed) result.error("engine_error", e.message ?: activity.getString(R.string.flutter_could_not_complete_operation), null)
            }
        }
    }

    private suspend fun execute(method: String, args: Wire): Any? {
        if (method in setOf("file.pickUpload", "file.prepareDownload", "file.finishTransfer")) return fileTransferOperation(method, args)
        if (method.startsWith("key.storage")) return keyStorageOperation(method, args)
        if (method.startsWith("ssh.") || method == "session.prepare") return sshPlatformOperation(method, args)
        return when (method) {
            "session.visibility" -> {
                if (args.flag("visible")) {
                    activeOwner = args.text("owner")
                    activeSessionId = args.number("id")
                    activeSessionOpen = args.flag("open")
                } else if (activeOwner == args.text("owner")) {
                    activeOwner = null
                    activeSessionId = null
                    activeSessionOpen = false
                }
                activity.applyWindowOptions()
                null
            }

            "host.save" -> {
                requirePasskeyPasswordStorage(args)
                val old = args.optionalId("id")?.let { hosts.findHostById(it) }
                val host = ((old ?: activity.settings.uiState.value.newHostDefaults()).toWire() + args).toHost(activity.resources)
                validateHostSelection(activity.resources, host, old, host.jumpHostId?.let { hosts.findHostById(it) })
                val saved = hosts.saveHost(host)
                withContext(activity.dispatchers.io) { activity.passwords.updateHostPassword(saved, args) }
                changed()
                saved.toWire()
            }

            "host.delete" -> {
                val host = hosts.findHostById(args.number("id")) ?: return null
                val token = if (args.flag("undo")) {
                    val deleted = withContext(activity.dispatchers.io) { hosts.deleteHostForUndo(host) }
                    UUID.randomUUID().toString().also { deletedHosts[it] = deleted }
                } else {
                    withContext(activity.dispatchers.io) { hosts.deleteHost(host) }
                    null
                }
                changed()
                token
            }

            "host.restore" -> {
                val token = args.text("token")
                val deleted = deletedHosts[token] ?: error(activity.getString(R.string.flutter_the_undo_period_has_expired))
                withContext(activity.dispatchers.io) { hosts.restoreDeletedHost(deleted) }
                deletedHosts.remove(token)
                changed()
                null
            }

            "host.deleteFinish" -> {
                deletedHosts.remove(args.text("token"))
                null
            }

            "host.sort" -> {
                activity.preferences.edit().putBoolean(org.connectbot.util.PreferenceConstants.SORT_BY_COLOR, !sortedByColor).apply()
                changed()
                null
            }

            "host.forgetKeys" -> {
                hosts.deleteKnownHostsForHost(args.number("id"))
                changed()
                null
            }

            "host.favorite" -> {
                hosts.toggleFavorite(args.number("id"))
                null
            }

            "host.duplicate" -> {
                val host = requireNotNull(hosts.findHostById(args.number("id")))
                hosts.duplicateHostSettings(host.id, host.copy(id = 0, nickname = args.text("nickname"), lastConnect = 0)).toWire()
            }

            "identity.save" -> {
                requirePasskeyPasswordStorage(args)
                val name = args.text("name").trim()
                val username = args.text("username").trim()
                require(name.isNotEmpty() && username.isNotEmpty()) { activity.getString(R.string.flutter_enter_a_credential_name_and_username) }
                val identity = hosts.saveIdentity(Identity(args.number("id"), name, username, args.number("pubkeyId", -1)))
                withContext(activity.dispatchers.io) { activity.passwords.updateIdentityPassword(identity.id, args) }
                changed()
                identity.id
            }

            "identity.delete" -> {
                hosts.deleteIdentity(args.number("id"))
                changed()
                null
            }

            "profile.save" -> {
                val old = args.optionalId("id")?.let { profiles.getById(it) }
                profiles.save((old?.toWire().orEmpty() + args).toProfile(activity.resources)).also {
                    activity.settings.refreshProfiles()
                    changed()
                }
            }

            "profile.delete" -> {
                check(profiles.delete(args.number("id"))) { activity.getString(R.string.flutter_cannot_delete_the_default_profile_while_it_is) }
                activity.settings.refreshProfiles()
                changed()
                null
            }

            "profile.duplicate" -> profiles.duplicate(args.number("id"), args.text("name")).also { changed() }

            "forwards" -> hosts.getPortForwardsForHost(args.number("hostId")).map { it.toWire() }

            "forward.save" -> {
                val forward = args.toForward(activity.resources)
                val old = args.optionalId("id")?.let { hosts.getPortForwardById(it) }
                validateForwardSelection(activity.resources, forward, old)
                hosts.savePortForward(forward).also { changed() }.toWire()
            }

            "forward.delete" -> {
                hosts.getPortForwardById(args.number("id"))?.let { hosts.deletePortForward(it) }
                changed()
                null
            }

            "knownHost.delete" -> {
                database.knownHostDao().getAll().find { it.id == args.number("id") }?.let { hosts.deleteKnownHost(it) }
                changed()
                null
            }

            "scheme.create" -> colors.createCustomScheme(args.text("name"), args.text("description"), args.number("sourceId", -1)).also { changed() }

            "scheme.duplicate" -> colors.duplicateScheme(args.number("id"), args.text("name")).also { changed() }

            "scheme.delete" -> {
                require(args.number("id") >= 0)
                colors.deleteCustomScheme(args.number("id"))
                changed()
                null
            }

            "scheme.rename" -> {
                require(args.number("id") >= 0)
                colors.renameScheme(args.number("id"), args.text("name"))
                changed()
                null
            }

            "scheme.palette" -> {
                val appearance = colors.getSchemeAppearance(args.number("id"))
                mapOf("colors" to colors.getSchemeColors(args.number("id")).toList(), "foregroundColor" to appearance.first, "backgroundColor" to appearance.second, "cursorColor" to appearance.third)
            }

            "scheme.role" -> {
                colors.setSchemeRole(args.number("id"), args.text("role"), args.number("color").toInt())
                changed()
                null
            }

            "scheme.color" -> {
                require(args.number("id") >= 0)
                require(args.number("index") in 0..15)
                colors.setColorForScheme(args.number("id"), args.number("index").toInt(), args.number("color").toInt())
                changed()
                null
            }

            "scheme.defaults" -> {
                require(args.number("id") >= 0)
                colors.setDefaultColorsForScheme(args.number("id"), args.number("foreground").toInt(), args.number("background").toInt())
                changed()
                null
            }

            "scheme.reset" -> {
                require(args.number("id") >= 0)
                colors.resetSchemeToDefaults(args.number("id"))
                changed()
                null
            }

            "scheme.export" -> colors.exportScheme(args.number("id")).toJson()

            "scheme.import" -> colors.importScheme(args.text("text"), args.flag("overwrite")).also { changed() }

            "config.export" -> withContext(activity.dispatchers.io) { hosts.exportHostsToJson().first }

            "config.import" -> {
                val counts = withContext(activity.dispatchers.io) { hosts.importHostsFromJson(args.text("text")) }
                activity.settings.refreshProfiles()
                changed()
                mapOf(
                    "hostsImported" to counts.hostsImported,
                    "hostsSkipped" to counts.hostsSkipped,
                    "profilesImported" to counts.profilesImported,
                    "profilesSkipped" to counts.profilesSkipped,
                    "message" to activity.getString(
                        R.string.import_hosts_success,
                        counts.hostsImported,
                        counts.hostsSkipped,
                        counts.profilesImported,
                        counts.profilesSkipped,
                    ),
                )
            }

            "settings.update", "settings.preview", "settings.bellMode", "settings.notifications", "font.bytes", "font.import", "font.delete", "font.custom", "font.customDelete", "terminalType.add", "terminalType.delete", "document.read", "document.write", "document.pick", "document.create", "help.document", "logs", "logs.tombstone", "openUrl", "share" -> platformOperation(method, args)

            else -> {
                if (method.startsWith("session.") || method.startsWith("key.") || method == "prompt.respond" || method == "host.disconnect" || method == "forward.toggle") {
                    error("Operation is owned by Dart: $method")
                }
                error(activity.getString(R.string.flutter_unsupported_engine_operation_1_s, method))
            }
        }
    }

    private suspend fun snapshot(): Wire {
        val state = activity.appState.uiState.value
        if (!ready) return mapOf("ready" to false, "authenticated" to authenticated, "error" to (state as? AppUiState.MigrationFailed)?.error)
        return mapOf(
            "ready" to true, "authenticated" to true,
            "appVersion" to "${org.connectbot.BuildConfig.VERSION_NAME} (${org.connectbot.BuildConfig.VERSION_CODE})",
            "encodings" to withContext(activity.dispatchers.io) { java.nio.charset.Charset.availableCharsets().keys.toList() },
            "hardwareKeyboard" to withContext(activity.dispatchers.io) { android.view.InputDevice.getDeviceIds().any { android.view.InputDevice.getDevice(it)?.keyboardType == android.view.InputDevice.KEYBOARD_TYPE_ALPHABETIC } },
            "koreanKeyboard" to withContext(activity.dispatchers.io) {
                @Suppress("DEPRECATION")
                val locale = activity.getSystemService(android.view.inputmethod.InputMethodManager::class.java).currentInputMethodSubtype?.locale
                locale?.startsWith("ko") == true
            },
            "entryAction" to activity.intent.action,
            "autoHideDelayMs" to 3000L,
            "defaults" to mapOf("host" to activity.settings.uiState.value.newHostDefaults().toWire(), "profile" to Profile(name = "").toWire()),
            "sortedByColor" to sortedByColor,
            "hosts" to hosts.getHosts(sortedByColor).map { host ->
                host.toWire() + mapOf(
                    "hasPassword" to withContext(activity.dispatchers.io) { activity.passwords.hasPassword(host.id) },
                    "connectionState" to "UNKNOWN",
                    "iconArgb" to (host.color?.takeIf { it.isNotBlank() }?.let { runCatching { it.toColorInt() }.getOrNull() } ?: ContextCompat.getColor(activity, org.connectbot.R.color.host_blue)),
                )
            },
            "identities" to hosts.getIdentities().map { mapOf("id" to it.id, "name" to it.name, "username" to it.username, "pubkeyId" to it.pubkeyId, "hasPassword" to withContext(activity.dispatchers.io) { activity.passwords.hasIdentityPassword(it.id) }) },
            "profiles" to profiles.getAll().map { it.toWire() },
            "keys" to withContext(activity.dispatchers.io) { keys.getAll().map { it.storageWire(activity.biometricKeys) } },
            "schemes" to colors.getAllSchemes().map { scheme ->
                val defaults = colors.getSchemeDefaults(scheme.id)
                val appearance = colors.getSchemeAppearance(scheme.id)
                mapOf("id" to scheme.id, "name" to scheme.name, "description" to scheme.description, "palette" to colors.getSchemeColors(scheme.id).toList(), "foreground" to defaults.first, "background" to defaults.second, "foregroundColor" to appearance.first, "backgroundColor" to appearance.second, "cursorColor" to appearance.third)
            },
            "knownHosts" to database.knownHostDao().getAll().map { mapOf("id" to it.id, "hostId" to it.hostId, "hostname" to it.hostname, "port" to it.port, "algorithm" to it.hostKeyAlgo, "fingerprint" to it.sshFingerprint(), "key" to android.util.Base64.encodeToString(it.hostKey, android.util.Base64.NO_WRAP)) },
            "sessions" to emptyList<Wire>(),
            "selectedSession" to null,
            "prompts" to emptyList<Wire>(),
            "startupKeys" to emptyList<Wire>(),
            "preferences" to (activity.settings.uiState.value.toWire() + mapOf("defaultProfileId" to resolveTerminalProfile().id)),
            "keyState" to emptyMap<String, Any?>(),
            "generation" to mapOf("passkeyOnly" to true, "passkeyAvailable" to activity.passkeys.available, "busy" to false, "biometricAvailable" to false, "nicknameExists" to false),
            "enrollment" to emptyMap<String, Any?>(),
        )
    }

    fun dispose() {
        closeSshPlatform()
        deletedHosts.clear()
        disposed = true
        methods.setMethodCallHandler(null)
        observerJobs.forEach { it.cancel() }
    }
}

internal fun validateHostSelection(resources: Resources, host: Host, previous: Host?, jumpHost: Host?) {
    require(host.protocol in setOf("ssh", "local") || host.protocol == previous?.protocol) { resources.getString(R.string.flutter_only_ssh_and_local_connections_are_supported) }
    if (host.jumpHostId != null && host.jumpHostId != previous?.jumpHostId) {
        require(jumpHost != null && jumpHost.id != host.id && jumpHost.protocol == "ssh") { resources.getString(R.string.flutter_the_jump_host_must_be_a_different_ssh) }
    }
}

internal fun validateForwardSelection(resources: Resources, forward: PortForward, previous: PortForward?) {
    if (forward.type == "dynamic4") {
        require(previous?.type == "dynamic4" && (!forward.startEnabled || previous.startEnabled)) { resources.getString(R.string.flutter_socks4_forwarding_is_unsupported) }
    }
}

private fun Wire.toForward(resources: Resources): PortForward {
    require(text("type") in setOf("local", "remote", "dynamic4", "dynamic5")) { resources.getString(R.string.flutter_check_the_forwarding_type) }
    require(number("sourcePort") in 1..65535) { resources.getString(R.string.flutter_check_the_source_port_range) }
    require(text("type") in setOf("dynamic4", "dynamic5") || (text("destAddr").isNotBlank() && number("destPort") in 1..65535)) { resources.getString(R.string.flutter_check_the_destination_address_and_port) }
    val type = text("type")
    return PortForward(
        number("id"), number("hostId"), text("nickname"), type,
        if (type == "remote") text("sourceAddr", "localhost") else "127.0.0.1",
        number("sourcePort").toInt(), optionalText("destAddr"), number("destPort").toInt(), false,
    )
}
