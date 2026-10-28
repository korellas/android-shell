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

import android.net.Uri
import android.util.Base64
import androidx.room.withTransaction
import kotlinx.coroutines.withContext
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.KnownHost
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import java.util.WeakHashMap

internal suspend fun AndroidShellEngine.sshPlatformOperation(method: String, args: Wire): Any? {
    check(authenticated) { "App is locked" }
    if (method == "session.prepare") {
        withContext(activity.dispatchers.main) {
            if (activity.appState.shouldRequestNotificationPermission()) activity.requestNotifications()
        }
    }
    if (method == "ssh.sign") {
        val key = withContext(activity.dispatchers.io) { requireNotNull(keys.getById(args.number("id"))) }
        val manager = activity.biometricKeys
        require(key.isKeystoreSshKeyEligible(manager)) { "Native signing requires an eligible Android Keystore P-256 key" }
        val crypto = withContext(activity.dispatchers.io) {
            val alias = requireNotNull(key.keystoreAlias)
            val public = requireNotNull(manager.getPublicKey(alias))
            manager.getCryptoObject(alias, sshSigningAlgorithm(public, args.text("algorithm")))
        }
        val authenticatedCrypto = withContext(activity.dispatchers.main) {
            activity.authenticate(key.nickname, crypto)?.cryptoObject
        } ?: return mapOf("authcancel" to true)
        val signature = requireNotNull(authenticatedCrypto.signature) { "Authentication did not authorize signing" }
        check(signature === crypto.signature) { "Authentication returned a different signing operation" }
        return withContext(activity.dispatchers.io) {
            mapOf("signature" to manager.sign(signature, args.bytes("data")))
        }
    }
    return withContext(activity.dispatchers.io) {
        when (method) {
            "ssh.prepare", "session.prepare" -> {
                val host = args.optionalId("id")?.let { requireNotNull(hosts.findHostById(it)) }
                    ?: resolveSshUri(args.text("uri"))
                if (method == "session.prepare") hosts.touchHost(host)
                val seen = mutableSetOf<Long>()
                val jumps = mutableListOf<Wire>()
                var next = host.jumpHostId
                if (host.id > 0) seen.add(host.id)
                while (next != null) {
                    require(seen.add(next) && seen.size <= 32) { "Cyclic or excessive SSH jump chain" }
                    val jump = requireNotNull(hosts.findHostById(next)) { "Missing jump host" }
                    jumps.add(prepareSshHost(jump))
                    next = jump.jumpHostId
                }
                prepareSshHost(host) + ("jumps" to jumps.reversed())
            }

            "ssh.keyMaterial" -> {
                val key = requireNotNull(keys.getById(args.number("id")))
                key.sshKeyMaterial(activity.biometricKeys)
            }

            "ssh.knownHosts" -> database.knownHostDao().getByHostId(args.number("id")).map { it.sshTrustWire() }

            "ssh.checkHost", "ssh.saveHost" -> {
                val hostname = args.text("hostname")
                val port = args.number("port").toInt()
                require(hostname.isNotBlank() && port in 1..65535)
                val algorithm = canonicalSshHostAlgorithm(args.text("algorithm"))
                require(algorithm.isNotBlank())
                val fingerprint = normalizeSshFingerprint(args.text("fingerprint"))
                database.withTransaction {
                    val dao = database.knownHostDao()
                    val known = dao.getByHostnameAndPort(hostname, port)
                    val status = sshTrustStatus(known, algorithm, fingerprint)
                    if (method == "ssh.saveHost") {
                        require(args.flag("accept")) { "Explicit host trust acceptance required" }
                        require(status != "changed") { "Changed host keys must be removed before trusting a replacement" }
                        if (status != "match") {
                            val hostId = args.optionalId("id")?.takeIf { it > 0 }
                            if (hostId != null) requireNotNull(hosts.findHostById(hostId))
                            dao.insert(KnownHost(hostId = hostId, hostname = hostname, port = port, hostKeyAlgo = algorithm, hostKey = byteArrayOf(), sha256Fingerprint = fingerprint))
                        }
                    }
                    mapOf("status" to status, "known" to known.map { it.sshTrustWire() })
                }
            }

            "ssh.decode", "ssh.encode", "ssh.closeCodec" -> synchronized(sshCodecs) {
                val codecs = sshCodecs.getOrPut(this@sshPlatformOperation) { SshCodecs() }
                codecs.operation(method, args)
            }

            else -> error("Unknown SSH platform operation: $method")
        }
    }
}

internal suspend fun AndroidShellEngine.resolveSshUri(text: String): Host {
    val uri = Uri.parse(if (text.contains("://")) text else "ssh://$text")
    val defaults = activity.settings.uiState.value.newHostDefaults()
    if (uri.scheme == "local") return Host.createLocalHost(uri.fragment ?: "Local").copy(profileId = defaults.profileId, scrollbackLines = defaults.scrollbackLines)
    require(uri.scheme == "ssh") { "Only SSH and local connections are supported" }
    val hostname = requireNotNull(uri.host) { "Missing SSH hostname" }
    val username = uri.userInfo.orEmpty()
    require(!username.contains(':')) { "Passwords in SSH addresses are not supported" }
    val port = if (uri.port == -1) 22 else uri.port
    require(port in 1..65535 && hostname.isNotBlank())
    val existing = hosts.findHost(mapOf("protocol" to "ssh", "hostname" to hostname, "username" to username, "port" to port.toString()))
    return existing ?: defaults.copy(id = -1, nickname = uri.fragment ?: hostname, hostname = hostname, username = username, port = port)
}

private suspend fun AndroidShellEngine.prepareSshHost(configured: Host): Wire {
    require(configured.protocol in setOf("ssh", "local")) { "Only SSH and local connections are supported" }
    val identity = configured.identityId?.let { database.identityDao().getById(it) }
    require(configured.identityId == null || identity != null) { "Missing SSH identity" }
    val host = if (identity == null) configured else configured.copy(username = identity.username, pubkeyId = identity.pubkeyId)
    val profile = resolveTerminalProfile(host.profileId)
    Charset.forName(profile.encoding)
    val password = if (identity != null) activity.passwords.getIdentityPassword(identity.id) else activity.passwords.getPassword(host.id)
    val manager = activity.biometricKeys
    val candidates = if (host.protocol == "local" || !host.useKeys || host.pubkeyId == -2L) {
        emptyList()
    } else if (host.pubkeyId >= 0) {
        listOfNotNull(keys.getById(host.pubkeyId)).filter { it.isKeystoreSshKeyEligible(manager) }
    } else {
        keys.getAll().filter { it.isKeystoreSshKeyEligible(manager) }
    }
    val schemeId = profile.colorSchemeId
    val defaults = colors.getSchemeDefaults(schemeId)
    val appearance = colors.getSchemeAppearance(schemeId)
    return mapOf(
        "scheme" to mapOf("palette" to colors.getSchemeColors(schemeId).toList(), "foreground" to defaults.first, "background" to defaults.second, "foregroundColor" to appearance.first, "backgroundColor" to appearance.second, "cursorColor" to appearance.third),
        "host" to host.toWire(),
        "profile" to profile.toWire(),
        "password" to password,
        "keys" to candidates.map { it.storageWire(manager) },
        "forwards" to hosts.getPortForwardsForHost(host.id).map { it.toWire() },
    )
}

internal fun normalizeSshFingerprint(value: String): String {
    val encoded = value.removePrefix("SHA256:")
    require(encoded.matches(Regex("[A-Za-z0-9+/]{43}=?"))) { "Invalid SHA256 host fingerprint" }
    val bytes = Base64.decode(encoded, Base64.NO_WRAP)
    require(bytes.size == 32)
    return "SHA256:" + Base64.encodeToString(bytes, Base64.NO_WRAP or Base64.NO_PADDING)
}

internal fun KnownHost.sshFingerprint(): String = sha256Fingerprint?.let(::normalizeSshFingerprint)
    ?: run {
        require(hostKey.isNotEmpty()) { "Known host has no key or fingerprint" }
        "SHA256:" + Base64.encodeToString(MessageDigest.getInstance("SHA-256").digest(hostKey), Base64.NO_WRAP or Base64.NO_PADDING)
    }

internal fun canonicalSshHostAlgorithm(algorithm: String): String = when (algorithm) {
    "rsa-sha2-256", "rsa-sha2-512" -> "ssh-rsa"
    else -> algorithm
}

internal fun sshTrustStatus(known: List<KnownHost>, algorithm: String, fingerprint: String): String = when {
    known.any { canonicalSshHostAlgorithm(it.hostKeyAlgo) == canonicalSshHostAlgorithm(algorithm) && it.sshFingerprint() == fingerprint } -> "match"
    known.isNotEmpty() -> "changed"
    else -> "new"
}

private fun KnownHost.sshTrustWire(): Wire = mapOf("id" to id, "algorithm" to hostKeyAlgo, "fingerprint" to sshFingerprint(), "hostname" to hostname, "port" to port)
private fun Wire.bytes(key: String): ByteArray = requireNotNull(this[key] as? ByteArray) { "Missing $key bytes" }
private val sshCodecs = WeakHashMap<AndroidShellEngine, SshCodecs>()
internal fun AndroidShellEngine.closeSshPlatform() {
    synchronized(sshCodecs) { sshCodecs.remove(this) }
}

internal class SshCodecs {
    private class State(val charset: Charset) {
        val decoder = charset.newDecoder().onMalformedInput(CodingErrorAction.REPLACE).onUnmappableCharacter(CodingErrorAction.REPLACE)
        val encoder = charset.newEncoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
        var pendingBytes = byteArrayOf()
        var pendingText = ""
        var decoded = false
        var encoded = false
    }
    private val sessions = mutableMapOf<String, State>()

    fun operation(method: String, args: Wire): Any? {
        val id = args.text("sessionId")
        require(id.isNotEmpty() && id.length <= 256)
        if (method == "ssh.closeCodec") {
            sessions.remove(id)
            return null
        }
        val charset = Charset.forName(args.text("encoding"))
        val state = sessions[id] ?: run {
            require(sessions.size < 128) { "Too many active SSH codecs" }
            State(charset).also { sessions[id] = it }
        }
        require(state.charset == charset) { "Cannot change an active stream encoding" }
        val final = args.flag("final")
        return if (method == "ssh.decode") {
            check(!state.decoded) { "Decoder already finished" }
            val input = ByteBuffer.wrap(state.pendingBytes + args.bytes("bytes"))
            val output = CharBuffer.allocate(4096)
            val text = StringBuilder()
            while (true) {
                val result = state.decoder.decode(input, output, final)
                output.flip()
                text.append(output)
                output.clear()
                if (result.isError) result.throwException()
                if (!result.isOverflow) break
            }
            state.pendingBytes = ByteArray(input.remaining()).also { input.get(it) }
            if (final) {
                while (true) {
                    val result = state.decoder.flush(output)
                    output.flip()
                    text.append(output)
                    output.clear()
                    if (result.isError) result.throwException()
                    if (!result.isOverflow) break
                }
                state.decoded = true
            }
            text.toString()
        } else {
            check(!state.encoded) { "Encoder already finished" }
            val input = CharBuffer.wrap(state.pendingText + args.text("text"))
            val output = ByteBuffer.allocate(4096)
            val bytes = ByteArrayOutputStream()
            while (true) {
                val result = state.encoder.encode(input, output, final)
                bytes.write(output.array(), 0, output.position())
                output.clear()
                if (result.isError) result.throwException()
                if (!result.isOverflow) break
            }
            state.pendingText = input.toString()
            if (final) {
                while (true) {
                    val result = state.encoder.flush(output)
                    bytes.write(output.array(), 0, output.position())
                    output.clear()
                    if (result.isError) result.throwException()
                    if (!result.isOverflow) break
                }
                state.encoded = true
            }
            bytes.toByteArray()
        }
    }
}
