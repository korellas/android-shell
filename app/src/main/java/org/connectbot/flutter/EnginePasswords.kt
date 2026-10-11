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

import org.connectbot.data.entity.Host
import org.connectbot.util.SecurePasswordStorage

internal fun SecurePasswordStorage.updateHostPassword(host: Host, args: Wire) {
    if (host.protocol != "ssh" && host.protocol != "mosh") return
    when {
        host.identityId != null -> deletePassword(host.id)
        args.text("password").isNotEmpty() -> savePassword(host.id, args.text("password"))
        args.flag("clearPassword") -> deletePassword(host.id)
    }
}

internal fun SecurePasswordStorage.updateIdentityPassword(id: Long, args: Wire) {
    when {
        args.text("password").isNotEmpty() -> saveIdentityPassword(id, args.text("password"))
        args.flag("clearPassword") -> deleteIdentityPassword(id)
    }
}
