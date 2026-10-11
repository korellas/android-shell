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
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.core.graphics.toColorInt
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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
import org.connectbot.data.entity.AutomationAction
import org.connectbot.data.entity.AutomationActionType
import org.connectbot.data.entity.AutomationFailurePolicy
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.Identity
import org.connectbot.data.entity.PortForward
import org.connectbot.data.entity.Profile
import org.connectbot.service.ConnectionNotifier
import org.connectbot.service.DisconnectReason
import org.connectbot.service.PromptRequest
import org.connectbot.service.PromptResponse
import org.connectbot.service.ServiceError
import org.connectbot.service.TerminalBridge
import org.connectbot.service.TerminalManager
import org.connectbot.service.automation.AutomationKeySupport
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
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private val methods = MethodChannel(flutter.dartExecutor.binaryMessenger, "dev.korellas.androidshell/engine")
    private val events = EventChannel(flutter.dartExecutor.binaryMessenger, "dev.korellas.androidshell/events")
    private var sink: EventChannel.EventSink? = null
    internal var manager: TerminalManager? = null
    private var managerJob: Job? = null
    private val observerJobs = mutableListOf<Job>()
    private val sessionJobs = mutableMapOf<Long, Job>()
    private data class PendingPrompt(val token: String, val request: PromptRequest)
    private val prompts = mutableMapOf<Long, PendingPrompt>()
    internal val terminalViews = mutableMapOf<Int, NativeTerminalView>()
    internal var activeOwner: String? = null
    internal var activeHostId: Long? = null
    private var pendingIntent: Intent? = null
    private var selectedSession: Long? = null
    private var disposed = false

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        flutter.platformViewsController.registry.registerViewFactory("dev.korellas.androidshell/terminal", NativeTerminalFactory(this))
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
        observerJobs += activity.lifecycleScope.launch { activity.hostList.uiState.collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { hosts.observeIdentities().collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { profiles.observeAll().collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { activity.keyList.uiState.collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { activity.keyGenerator.uiState.collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { activity.settings.uiState.collect { changed() } }
        observerJobs += activity.lifecycleScope.launch { activity.enrollment.uiState.collect { changed() } }
    }

    internal fun changed() {
        terminalViews.values.toList().forEach { it.updateLock(!ready) }
        activity.applyWindowOptions()
        if (!disposed) sink?.success(mapOf("type" to "changed"))
    }
    internal fun requestTextInput(owner: String, text: String) {
        if (!disposed && ready && activeOwner == owner) sink?.success(mapOf("type" to "textInput", "owner" to owner, "text" to text))
    }
    internal fun switchSession(owner: String, id: Long, direction: Int) {
        val sessions = manager?.bridgesFlow?.value.orEmpty()
        val current = sessions.indexOfFirst { it.host.id == id }
        if (current < 0 || sessions.isEmpty()) return
        val target = sessions[(current + direction).coerceIn(0, sessions.lastIndex)].host.id
        sink?.success(mapOf("type" to "switchSession", "owner" to owner, "id" to target))
    }
    internal fun notify(message: String) {
        if (!disposed) sink?.success(mapOf("type" to "message", "message" to message))
    }
    internal val authenticated get() = !activity.appState.authOnLaunchEnabled || activity.appState.isAuthenticated.value
    internal val ready get() = authenticated && activity.appState.uiState.value is AppUiState.Ready && manager != null

    fun bind(service: TerminalManager) {
        activity.hostList.setTerminalManager(service)
        unbind()
        manager = service
        managerJob = activity.lifecycleScope.launch {
            launch { service.hostStatusChangedFlow.collect { changed() } }
            launch {
                service.serviceErrors.collect {
                    notify(
                        when (it) {
                            is ServiceError.KeyLoadFailed -> "${it.keyName}: ${it.reason}"
                            is ServiceError.ConnectionFailed -> "${it.hostNickname}: ${it.reason}"
                            is ServiceError.PortForwardLoadFailed -> "${it.hostNickname}: ${it.reason}"
                            is ServiceError.HostSaveFailed -> "${it.hostNickname}: ${it.reason}"
                            is ServiceError.ColorSchemeLoadFailed -> it.reason
                        },
                    )
                }
            }
            launch { service.pendingStartupKeyPrompts.collect { changed() } }
            service.bridgesFlow.collect { bridges ->
                val ids = bridges.map { it.host.id }.toSet()
                sessionJobs.keys.filter { it !in ids }.forEach {
                    sessionJobs.remove(it)?.cancel()
                    prompts.remove(it)
                }
                for (bridge in bridges) {
                    if (sessionJobs.containsKey(bridge.host.id)) continue
                    sessionJobs[bridge.host.id] = launch {
                        launch {
                            bridge.promptManager.promptState.collect { request ->
                                if (request == null) {
                                    prompts.remove(bridge.host.id)
                                } else {
                                    prompts[bridge.host.id] = PendingPrompt(UUID.randomUUID().toString(), request)
                                }
                                changed()
                            }
                        }
                        launch { bridge.authBanners.collect { changed() } }
                        launch { bridge.automationState.collect { changed() } }
                        launch { bridge.progressState.collect { changed() } }
                        launch { bridge.keyHandler.modifierState.collect { changed() } }
                        bridge.networkStatusMessages.collect { notify(it) }
                    }
                }
                changed()
            }
        }
        changed()
    }

    fun unbind() {
        managerJob?.cancel()
        managerJob = null
        sessionJobs.values.forEach { it.cancel() }
        sessionJobs.clear()
        prompts.clear()
        manager = null
        changed()
    }

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
                if (intent.action == FlutterShellActivity.DISCONNECT_ACTION) {
                    manager?.disconnectAll(false)
                } else {
                    val notified = intent.getStringExtra(ConnectionNotifier.EXTRA_SESSION_ID)
                    val uri = intent.data
                    val bridge = if (notified != null) {
                        manager?.bridgesFlow?.value?.find { it.notificationSessionId == notified }
                            ?: if (intent.getBooleanExtra(ConnectionNotifier.EXTRA_RECONNECT, false)) intent.data?.let { manager?.openConnection(it) } else null
                    } else if (uri != null) {
                        manager?.openConnection(uri)
                    } else {
                        null
                    }
                    if (bridge != null) selectedSession = bridge.host.id
                }
                changed()
            } catch (e: Exception) {
                notify(e.message ?: "연결에 실패했습니다.")
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        changed()
    }
    override fun onCancel(arguments: Any?) {
        sink = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        activity.lifecycleScope.launch {
            try {
                @Suppress("UNCHECKED_CAST")
                val args = (call.arguments as? Map<String, Any?>).orEmpty()
                val value = when (call.method) {
                    "snapshot" -> snapshot()

                    "authenticateApp" -> {
                        if (activity.authenticate("AndroidShell 잠금 해제", appLock = true) != null) activity.appState.onAuthenticationSuccess()
                        changed()
                        authenticated
                    }

                    "session.visibility" -> execute(call.method, args)

                    "retryMigration" -> {
                        activity.appState.retryMigration()
                        null
                    }

                    else -> {
                        check(ready) { "앱 초기화 또는 잠금 해제를 기다려 주세요." }
                        execute(call.method, args)
                    }
                }
                if (!disposed) result.success(value)
            } catch (e: CancellationException) {
                if (!disposed) result.error("cancelled", "작업이 취소되었습니다.", null)
                throw e
            } catch (e: Exception) {
                if (!disposed) result.error("engine_error", e.message ?: "작업을 완료할 수 없습니다.", null)
            }
        }
    }

    internal fun bridge(id: Long): TerminalBridge = manager?.bridgesFlow?.value?.find { it.host.id == id }
        ?: error("연결된 세션이 없습니다.")

    private suspend fun execute(method: String, args: Wire): Any? {
        return when (method) {
            "connect" -> {
                if (activity.appState.shouldRequestNotificationPermission()) activity.requestNotifications()
                val id = args.optionalId("id")
                if (activity.intent.action == Intent.ACTION_PICK && id != null) {
                    val host = requireNotNull(hosts.findHostById(id))
                    activity.setResult(android.app.Activity.RESULT_OK, Intent().setData(host.getUri()))
                    activity.finish()
                    return null
                }
                val bridge = if (id != null) manager!!.openConnectionForHostId(id) else manager!!.openConnection(Uri.parse(args.text("uri")))
                requireNotNull(bridge) { "호스트를 찾을 수 없습니다." }
                selectedSession = bridge.host.id
                changed()
                bridge.host.id
            }

            "session.consumeSelection" -> {
                selectedSession = null
                null
            }

            "session.select" -> {
                selectedSession = args.optionalId("id")
                changed()
                null
            }

            "session.disconnect" -> {
                bridge(args.number("id")).dispatchDisconnect(DisconnectReason.USER_REQUESTED)
                null
            }

            "session.disconnectAll" -> {
                manager!!.disconnectAll(args.flag("excludeLocal"))
                null
            }

            "session.sendText" -> {
                bridge(args.number("id")).injectString(args.text("text"))
                null
            }

            "session.key" -> {
                val view = terminalViews.values.lastOrNull { it.hostId == args.number("id") && it.routeOwner == activeOwner }
                if (view != null) view.dispatchKey(args.number("key").toInt()) else bridge(args.number("id")).keyHandler.sendPressedKey(args.number("key").toInt())
                null
            }

            "session.modifier" -> {
                bridge(args.number("id")).keyHandler.metaPress(args.number("code").toInt(), args.flag("sticky"))
                changed()
                null
            }

            "session.cancelAutomation" -> {
                bridge(args.number("id")).cancelAutomation()
                null
            }

            "session.dismissBanner" -> {
                bridge(args.number("id")).dismissAuthBanner(args.number("bannerId"))
                null
            }

            "session.urls" -> bridge(args.number("id")).scanForURLs()

            "session.font" -> {
                val bridge = bridge(args.number("id"))
                if (args.flag("increase")) bridge.increaseFontSize() else bridge.decreaseFontSize()
                null
            }

            "session.visibility" -> {
                if (args.flag("visible")) {
                    activeOwner = args.text("owner")
                    activeHostId = args.number("id")
                } else if (activeOwner == args.text("owner")) {
                    activeOwner = null
                    activeHostId = null
                }
                terminalViews.values.toList().forEach { it.updateVisibility() }
                activity.applyWindowOptions()
                null
            }

            "session.view" -> terminalViews.values.lastOrNull { it.hostId == args.number("id") && it.routeOwner == activeOwner }?.command(args.text("action"), args)

            "prompt.respond" -> respond(args)

            "host.save" -> {
                val old = args.optionalId("id")?.let { hosts.findHostById(it) }
                val host = (old?.toWire().orEmpty() + args).toHost()
                require(host.jumpHostId != host.id || host.id == 0L) { "자기 자신을 점프 호스트로 지정할 수 없습니다." }
                val saved = hosts.saveHost(host)
                withContext(activity.dispatchers.io) { activity.passwords.updateHostPassword(saved, args) }
                manager!!.bridgesFlow.value.find { it.host.id == saved.id }?.let { manager!!.updateHostConfiguration(it, saved) }
                changed()
                saved.toWire()
            }

            "host.delete" -> {
                hosts.findHostById(args.number("id"))?.let {
                    manager!!.disconnectHost(it.id)
                    hosts.deleteHost(it)
                }
                changed()
                null
            }

            "host.sort" -> {
                activity.hostList.toggleSortOrder()
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
                val name = args.text("name").trim()
                val username = args.text("username").trim()
                require(name.isNotEmpty() && username.isNotEmpty()) { "인증정보 이름과 사용자 이름을 입력하세요." }
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
                profiles.save((old?.toWire().orEmpty() + args).toProfile()).also {
                    activity.settings.refreshProfiles()
                    changed()
                }
            }

            "profile.delete" -> {
                check(profiles.delete(args.number("id"))) { "사용 중인 기본 프로필은 삭제할 수 없습니다." }
                activity.settings.refreshProfiles()
                changed()
                null
            }

            "profile.duplicate" -> profiles.duplicate(args.number("id"), args.text("name")).also { changed() }

            "forwards" -> hosts.getPortForwardsForHost(args.number("hostId")).map { forward ->
                val live = manager!!.bridgesFlow.value.find { it.host.id == forward.hostId }?.transport?.getPortForwards()?.find { it.id == forward.id }
                (live ?: forward).toWire()
            }

            "forward.save" -> {
                val forward = args.toForward()
                val saved = hosts.savePortForward(forward)
                manager!!.bridgesFlow.value.find { it.host.id == saved.hostId }?.let { bridge ->
                    val oldForward = bridge.transport?.getPortForwards()?.find { it.id == saved.id }
                    val wasEnabled = oldForward?.isEnabled() ?: (forward.id == 0L)
                    oldForward?.let {
                        bridge.disablePortForward(it)
                        bridge.removePortForward(it)
                    }
                    bridge.addPortForward(saved)
                    if (wasEnabled && bridge.transport?.isConnected() == true) check(bridge.enablePortForward(saved)) { "포워딩 활성화에 실패했습니다." }
                }
                changed()
                saved.toWire()
            }

            "forward.delete" -> {
                hosts.getPortForwardById(args.number("id"))?.let { forward ->
                    manager!!.bridgesFlow.value.find { it.host.id == forward.hostId }?.let { bridge ->
                        bridge.transport?.getPortForwards()?.find { it.id == forward.id }?.let {
                            bridge.disablePortForward(it)
                            bridge.removePortForward(it)
                        }
                    }
                    hosts.deletePortForward(forward)
                }
                changed()
                null
            }

            "forward.toggle" -> {
                val bridge = bridge(args.number("hostId"))
                val forward = requireNotNull(bridge.transport?.getPortForwards()?.find { it.id == args.number("id") })
                check(if (args.flag("enabled")) bridge.enablePortForward(forward) else bridge.disablePortForward(forward)) { "포워딩을 변경할 수 없습니다." }
                changed()
                null
            }

            "automation" -> hosts.getAutomation(args.number("hostId")).map { it.toWire() }

            "automation.save" -> {
                @Suppress("UNCHECKED_CAST")
                val actions = (args["actions"] as List<Map<String, Any?>>).mapIndexed { position, data -> data.toAutomation(args.number("hostId"), position) }
                require(actions.map { it.id }.distinct().size == actions.size) { "중복 자동화 ID입니다." }
                hosts.saveAutomation(args.number("hostId"), actions)
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

            "scheme.palette" -> mapOf("colors" to colors.getSchemeColors(args.number("id")).toList(), "foreground" to colors.getSchemeDefaults(args.number("id")).first, "background" to colors.getSchemeDefaults(args.number("id")).second)

            "scheme.color" -> {
                require(args.number("id") >= 0)
                require(args.number("index") in 0..255)
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

            "key.generate", "key.biometricUnlock", "key.delete", "key.load", "key.copy", "key.export", "key.import", "key.importPassword", "key.importName", "key.importCancel", "key.save", "key.enroll", "key.enrollmentBegin", "key.startup" -> keyOperation(method, args)

            "settings.update", "settings.notifications", "font.import", "font.delete", "font.custom", "font.customDelete", "terminalType.add", "terminalType.delete", "document.read", "document.write", "document.pick", "document.create", "help.document", "logs", "logs.clear", "logs.tombstone", "openUrl", "share", "shortcut" -> platformOperation(method, args)

            else -> error("지원하지 않는 엔진 작업: $method")
        }
    }

    private suspend fun respond(args: Wire): Any? {
        val id = args.number("hostId")
        val pending = prompts[id] ?: return false
        require(pending.token == args.text("token")) { "만료된 인증 요청입니다." }
        val bridge = bridge(id)
        require(bridge.promptManager.promptState.value === pending.request) { "만료된 인증 요청입니다." }
        val response = when (val request = pending.request) {
            is PromptRequest.StringPrompt -> PromptResponse.StringResponse(args["value"] as? String)

            is PromptRequest.BiometricPrompt -> {
                val auth = if (args.flag("value")) activity.authenticate(request.keyNickname, request.cryptoObject) else null
                require(bridge.promptManager.promptState.value === request) { "만료된 생체인증 요청입니다." }
                PromptResponse.BiometricResponse(auth != null, auth?.cryptoObject)
            }

            else -> PromptResponse.BooleanResponse(args.flag("value"))
        }
        bridge.promptManager.respond(response)
        prompts.remove(id)
        changed()
        return true
    }

    private suspend fun snapshot(): Wire {
        val state = activity.appState.uiState.value
        if (!ready) return mapOf("ready" to false, "authenticated" to authenticated, "error" to (state as? AppUiState.MigrationFailed)?.error)
        val service = manager!!
        return mapOf(
            "ready" to true, "authenticated" to true,
            "entryAction" to activity.intent.action,
            "themeColors" to mapOf("light" to org.connectbot.ui.theme.connectBotColorScheme(activity, false, dynamicColor = false).toWire(), "dark" to org.connectbot.ui.theme.connectBotColorScheme(activity, true, dynamicColor = false).toWire()),
            "autoHideDelayMs" to org.connectbot.ui.screens.console.AUTO_HIDE_DELAY_MS,
            "shortcutStyles" to org.connectbot.util.IconStyle.entries.map { mapOf("name" to it.name) },
            "defaults" to mapOf("host" to Host().toWire(), "profile" to Profile(name = "").toWire()),
            "sortedByColor" to activity.hostList.uiState.value.sortedByColor,
            "hosts" to hosts.getHosts(activity.hostList.uiState.value.sortedByColor).map { host ->
                host.toWire() + mapOf(
                    "hasPassword" to withContext(activity.dispatchers.io) { activity.passwords.hasPassword(host.id) },
                    "connectionState" to (activity.hostList.uiState.value.connectionStates[host.id]?.name ?: "UNKNOWN"),
                    "iconArgb" to (host.color?.takeIf { it.isNotBlank() }?.let { runCatching { it.toColorInt() }.getOrNull() } ?: ContextCompat.getColor(activity, org.connectbot.R.color.host_blue)),
                )
            },
            "identities" to hosts.getIdentities().map { mapOf("id" to it.id, "name" to it.name, "username" to it.username, "pubkeyId" to it.pubkeyId, "hasPassword" to withContext(activity.dispatchers.io) { activity.passwords.hasIdentityPassword(it.id) }) },
            "profiles" to profiles.getAll().map { it.toWire() },
            "keys" to keys.getAll().map { it.toWire(service.isKeyLoaded(it.nickname)) },
            "schemes" to colors.getAllSchemes().map { scheme ->
                val defaults = colors.getSchemeDefaults(scheme.id)
                mapOf("id" to scheme.id, "name" to scheme.name, "description" to scheme.description, "palette" to colors.getSchemeColors(scheme.id).toList(), "foreground" to defaults.first, "background" to defaults.second)
            },
            "knownHosts" to database.knownHostDao().getAll().map { mapOf("id" to it.id, "hostId" to it.hostId, "hostname" to it.hostname, "port" to it.port, "algorithm" to it.hostKeyAlgo, "key" to android.util.Base64.encodeToString(it.hostKey, android.util.Base64.NO_WRAP)) },
            "sessions" to service.bridgesFlow.value.map { bridge ->
                mapOf(
                    "id" to bridge.host.id, "nickname" to bridge.host.nickname, "protocol" to bridge.host.protocol, "open" to bridge.isSessionOpen,
                    "composeMode" to (terminalViews.values.lastOrNull { it.hostId == bridge.host.id && it.routeOwner == activeOwner }?.composeMode == true),
                    "awaitingClose" to bridge.isAwaitingClose(), "canForward" to bridge.canFowardPorts(), "canEnroll" to ((bridge.transport as? org.connectbot.transport.SSH)?.canEnrollKey == true),
                    "modifiers" to bridge.keyHandler.modifierState.value.let { mapOf("ctrl" to it.ctrlState.name, "alt" to it.altState.name, "shift" to it.shiftState.name) }, "automation" to bridge.automationState.value.let { mapOf("running" to it.running, "error" to it.error, "step" to it.step) },
                    "banners" to bridge.authBanners.value.map { mapOf("id" to it.id, "sourceName" to it.sourceName, "message" to it.message, "urls" to it.urls) },
                )
            },
            "selectedSession" to selectedSession,
            "prompts" to prompts.map { (id, prompt) -> prompt.request.toWire() + mapOf("hostId" to id, "token" to prompt.token, "nativePresentation" to (selectedSession == id || (activeOwner != null && activeHostId == id))) },
            "startupKeys" to service.pendingStartupKeyPrompts.value.map { it.toWire(false) },
            "preferences" to (activity.settings.uiState.value.toWire() + mapOf("defaultProfileId" to (activity.settings.uiState.value.defaultProfileId.takeIf { it > 0 } ?: profiles.getDefault().id))),
            "keyState" to activity.keyList.uiState.value.let { mapOf("error" to it.error, "pendingNickname" to it.pendingNicknameConfirmation?.nickname, "importPassword" to it.pendingImport?.let { pending -> mapOf("nickname" to pending.nickname, "type" to pending.keyType) }, "biometricUnlock" to it.biometricKeyToUnlock?.id, "nicknameError" to it.importNicknameError) },
            "generation" to activity.keyGenerator.uiState.value.let { mapOf("busy" to it.isGenerating, "biometricAvailable" to it.biometricAvailable, "nicknameExists" to it.nicknameExists) },
            "enrollment" to activity.enrollment.uiState.value.let { mapOf("stage" to it.stage.name, "error" to it.error, "busy" to it.busy, "biometricAvailable" to it.biometricAvailable) },
        )
    }

    fun dispose() {
        disposed = true
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        observerJobs.forEach { it.cancel() }
        unbind()
        terminalViews.values.toList().forEach { it.dispose() }
        terminalViews.clear()
    }
}

private fun PromptRequest.toWire(): Wire = when (this) {
    is PromptRequest.StringPrompt -> mapOf("type" to "string", "instructions" to instructions, "hint" to hint, "password" to isPassword)
    is PromptRequest.BooleanPrompt -> mapOf("type" to "boolean", "instructions" to instructions, "message" to message)
    is PromptRequest.HostKeyFingerprintPrompt -> mapOf("type" to "hostKey", "hostname" to hostname, "keyType" to keyType, "keySize" to keySize, "sha256" to sha256, "md5" to md5, "randomArt" to randomArt, "bubblebabble" to bubblebabble)
    is PromptRequest.BiometricPrompt -> mapOf("type" to "biometric", "nickname" to keyNickname)
}
private fun Wire.toForward(): PortForward {
    require(text("type") in setOf("local", "remote", "dynamic4", "dynamic5")) { "포워딩 유형을 확인하세요." }
    require(number("sourcePort") in 1..65535) { "소스 포트 범위를 확인하세요." }
    require(text("type") in setOf("dynamic4", "dynamic5") || (text("destAddr").isNotBlank() && number("destPort") in 1..65535)) { "대상 주소와 포트를 확인하세요." }
    return PortForward(number("id"), number("hostId"), text("nickname"), text("type"), text("sourceAddr", "localhost"), number("sourcePort").toInt(), optionalText("destAddr"), number("destPort").toInt(), flag("startEnabled", true))
}
private fun Wire.toAutomation(host: Long, position: Int): AutomationAction {
    val action = AutomationAction(
        id = text("id").ifEmpty { UUID.randomUUID().toString() }, hostId = host, position = position,
        type = AutomationActionType.valueOf(text("type")), text = text("text"), regex = flag("regex"), durationMs = number("durationMs", 30000),
        key = number("key", 1).toInt(), modifiers = number("modifiers").toInt(), forwardId = optionalId("forwardId"), failurePolicy = AutomationFailurePolicy.valueOf(text("failurePolicy", "STOP")),
    )
    require(action.durationMs >= 0) { "대기 시간을 확인하세요." }
    if (action.type == AutomationActionType.SEND_KEY) require(AutomationKeySupport.isSupported(action.key, action.modifiers)) { "지원하지 않는 자동화 키입니다." }
    return action
}
