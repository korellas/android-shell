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

import android.content.res.Resources
import org.connectbot.R
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.PortForward
import org.connectbot.data.entity.Profile

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
    "useAuthAgent" to null, "postLogin" to null, "pubkeyId" to pubkeyId, "wantSession" to wantSession,
    "compression" to compression, "stayConnected" to stayConnected, "quickDisconnect" to quickDisconnect,
    "scrollbackLines" to scrollbackLines, "useCtrlAltAsMetaKey" to useCtrlAltAsMetaKey,
    "jumpHostId" to jumpHostId, "profileId" to profileId, "ipVersion" to ipVersion, "moshPort" to moshPort,
    "moshNetworkTimeout" to moshNetworkTimeout, "moshServer" to moshServer, "locale" to locale,
)
internal fun Wire.toHost(resources: Resources): Host {
    val defaults = Host().toWire()
    val data = defaults + this
    val protocol = data.text("protocol")
    require(protocol in setOf("ssh", "mosh", "telnet", "local")) { resources.getString(R.string.flutter_unsupported_protocol) }
    require(data.text("nickname").isNotBlank()) { resources.getString(R.string.flutter_enter_a_host_name) }
    require(protocol == "local" || data.text("hostname").isNotBlank()) { resources.getString(R.string.flutter_enter_a_server_address) }
    require(protocol == "local" || data.number("port") in 1..65535) { resources.getString(R.string.flutter_port_must_be_between_1_and_65535) }
    require(data.number("moshPort") in 0..65535) { resources.getString(R.string.flutter_check_the_mosh_port_range) }
    require(data.optionalId("moshNetworkTimeout") == null || data.number("moshNetworkTimeout") > 0) { resources.getString(R.string.flutter_mosh_timeout_must_be_positive) }
    return Host(
        id = data.number("id"), nickname = data.text("nickname"), favorite = data.flag("favorite"), identityId = data.optionalId("identityId"),
        protocol = protocol, username = data.text("username"), hostname = data.text("hostname"), port = if (protocol == "local") 0 else data.number("port").toInt(),
        hostKeyAlgo = data.optionalText("hostKeyAlgo"), lastConnect = data.number("lastConnect"), color = data.optionalText("color"),
        useKeys = data.flag("useKeys"), useAuthAgent = null, postLogin = null,
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
    "emulation" to emulation, "inlineImages" to "off", "forceSizeRows" to forceSizeRows, "forceSizeColumns" to forceSizeColumns,
)
internal fun Wire.toProfile(resources: Resources): Profile {
    val data = Profile(name = "").toWire() + this
    require(data.text("name").isNotBlank()) { resources.getString(R.string.flutter_enter_a_profile_name) }
    require(data.number("fontSize") in 4..72) { resources.getString(R.string.flutter_font_size_must_be_between_4_and_72) }
    require(data.optionalId("forceSizeRows") == null || data.number("forceSizeRows") > 0) { resources.getString(R.string.flutter_check_the_row_count) }
    require(data.optionalId("forceSizeColumns") == null || data.number("forceSizeColumns") > 0) { resources.getString(R.string.flutter_check_the_column_count) }
    return Profile(
        data.number("id"), data.text("name"), data.optionalText("iconColor"), data.number("colorSchemeId"), data.optionalText("fontFamily"),
        data.number("fontSize").toInt(), data.text("delKey"), data.text("encoding"), data.text("emulation"), "off",
        data.optionalId("forceSizeRows")?.toInt(), data.optionalId("forceSizeColumns")?.toInt(),
    )
}
internal fun PortForward.toWire(): Wire = mapOf(
    "id" to id, "hostId" to hostId, "nickname" to nickname, "type" to type,
    "sourceAddr" to if (type == "remote") sourceAddr else "127.0.0.1", "sourcePort" to sourcePort,
    "destAddr" to destAddr, "destPort" to destPort, "startEnabled" to false, "enabled" to isEnabled(),
)
