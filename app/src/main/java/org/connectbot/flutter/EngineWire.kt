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

import org.connectbot.data.entity.AutomationAction
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.PortForward
import org.connectbot.data.entity.Profile
import org.connectbot.data.entity.Pubkey

internal typealias Wire = Map<String, Any?>
internal fun Wire.text(key: String, default: String = "") = this[key] as? String ?: default
internal fun Wire.number(key: String, default: Long = 0) = (this[key] as? Number)?.toLong() ?: default
internal fun Wire.flag(key: String, default: Boolean = false) = this[key] as? Boolean ?: default
internal fun Wire.optionalId(key: String) = (this[key] as? Number)?.toLong()
internal fun Wire.optionalText(key: String) = (this[key] as? String)?.takeIf { it.isNotEmpty() }

internal fun Host.toWire(): Wire = mapOf(
    "id" to id, "nickname" to nickname, "favorite" to favorite, "identityId" to identityId,
    "protocol" to protocol, "username" to username, "hostname" to hostname, "port" to port,
    "hostKeyAlgo" to hostKeyAlgo, "lastConnect" to lastConnect, "color" to color, "useKeys" to useKeys,
    "useAuthAgent" to useAuthAgent, "postLogin" to postLogin, "pubkeyId" to pubkeyId, "wantSession" to wantSession,
    "compression" to compression, "stayConnected" to stayConnected, "quickDisconnect" to quickDisconnect,
    "scrollbackLines" to scrollbackLines, "useCtrlAltAsMetaKey" to useCtrlAltAsMetaKey,
    "jumpHostId" to jumpHostId, "profileId" to profileId, "ipVersion" to ipVersion, "moshPort" to moshPort,
    "moshNetworkTimeout" to moshNetworkTimeout, "moshServer" to moshServer, "locale" to locale,
)
internal fun Wire.toHost(): Host {
    val defaults = Host().toWire()
    val data = defaults + this
    val protocol = data.text("protocol")
    require(protocol in setOf("ssh", "mosh", "telnet", "local")) { "Unsupported protocol" }
    require(data.text("nickname").isNotBlank()) { "호스트 이름을 입력하세요." }
    require(protocol == "local" || data.text("hostname").isNotBlank()) { "서버 주소를 입력하세요." }
    require(data.number("port") in 1..65535) { "포트는 1–65535 범위여야 합니다." }
    require(data.number("moshPort") in 0..65535) { "Mosh 포트 범위를 확인하세요." }
    require(data.optionalId("moshNetworkTimeout") == null || data.number("moshNetworkTimeout") > 0) { "Mosh 타임아웃은 양수여야 합니다." }
    return Host(
        id = data.number("id"), nickname = data.text("nickname"), favorite = data.flag("favorite"), identityId = data.optionalId("identityId"),
        protocol = protocol, username = data.text("username"), hostname = data.text("hostname"), port = data.number("port").toInt(),
        hostKeyAlgo = data.optionalText("hostKeyAlgo"), lastConnect = data.number("lastConnect"), color = data.optionalText("color"),
        useKeys = data.flag("useKeys"), useAuthAgent = data.optionalText("useAuthAgent"), postLogin = data.optionalText("postLogin"),
        pubkeyId = data.number("pubkeyId"), wantSession = data.flag("wantSession"), compression = data.flag("compression"),
        stayConnected = data.flag("stayConnected"), quickDisconnect = data.flag("quickDisconnect"), scrollbackLines = data.number("scrollbackLines").toInt(),
        useCtrlAltAsMetaKey = data.flag("useCtrlAltAsMetaKey"), jumpHostId = data.optionalId("jumpHostId"), profileId = data.optionalId("profileId"),
        ipVersion = data.text("ipVersion"), moshPort = data.number("moshPort").toInt(), moshNetworkTimeout = data.optionalId("moshNetworkTimeout")?.toInt(),
        moshServer = data.optionalText("moshServer"), locale = data.text("locale"),
    )
}
internal fun Profile.toWire(): Wire = mapOf(
    "id" to id, "name" to name, "iconColor" to iconColor, "colorSchemeId" to colorSchemeId,
    "fontFamily" to fontFamily, "fontSize" to fontSize, "delKey" to delKey, "encoding" to encoding,
    "emulation" to emulation, "inlineImages" to inlineImages, "forceSizeRows" to forceSizeRows, "forceSizeColumns" to forceSizeColumns,
)
internal fun Wire.toProfile(): Profile {
    val data = Profile(name = "").toWire() + this
    require(data.text("name").isNotBlank()) { "프로필 이름을 입력하세요." }
    require(data.number("fontSize") in 4..72) { "글자 크기는 4–72 범위여야 합니다." }
    require(data.text("inlineImages") in setOf("off", "ask", "on")) { "이미지 정책을 확인하세요." }
    require(data.optionalId("forceSizeRows") == null || data.number("forceSizeRows") > 0) { "행 크기를 확인하세요." }
    require(data.optionalId("forceSizeColumns") == null || data.number("forceSizeColumns") > 0) { "열 크기를 확인하세요." }
    return Profile(
        data.number("id"), data.text("name"), data.optionalText("iconColor"), data.number("colorSchemeId"), data.optionalText("fontFamily"),
        data.number("fontSize").toInt(), data.text("delKey"), data.text("encoding"), data.text("emulation"), data.text("inlineImages"),
        data.optionalId("forceSizeRows")?.toInt(), data.optionalId("forceSizeColumns")?.toInt(),
    )
}
internal fun PortForward.toWire(): Wire = mapOf(
    "id" to id, "hostId" to hostId, "nickname" to nickname, "type" to type,
    "sourceAddr" to sourceAddr, "sourcePort" to sourcePort, "destAddr" to destAddr, "destPort" to destPort, "startEnabled" to startEnabled, "enabled" to isEnabled(),
)
internal fun AutomationAction.toWire(): Wire = mapOf(
    "id" to id, "hostId" to hostId, "position" to position, "type" to type.name,
    "text" to text, "regex" to regex, "durationMs" to durationMs, "key" to key, "modifiers" to modifiers, "forwardId" to forwardId, "failurePolicy" to failurePolicy.name,
)
internal fun Pubkey.toWire(loaded: Boolean): Wire = mapOf(
    "id" to id, "nickname" to nickname, "type" to type, "encrypted" to encrypted,
    "startup" to startup, "confirmation" to confirmation, "createdDate" to createdDate, "biometric" to isBiometric, "allowBackup" to allowBackup, "loaded" to loaded,
)
