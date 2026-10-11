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
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.Mockito.verifyNoMoreInteractions

class EnginePasswordsTest {
    private val passwords = mock(SecurePasswordStorage::class.java)
    private val host = Host(id = 7, protocol = "ssh")

    @Test fun blankPasswordPreservesStoredPassword() {
        passwords.updateHostPassword(host, mapOf("password" to ""))
        passwords.updateIdentityPassword(3, mapOf("password" to ""))
        verifyNoInteractions(passwords)
    }

    @Test fun newPasswordsUseExistingEncryptedStorage() {
        passwords.updateHostPassword(host, mapOf("password" to "new-host-password"))
        passwords.updateIdentityPassword(3, mapOf("password" to "new-identity-password"))
        verify(passwords).savePassword(7, "new-host-password")
        verify(passwords).saveIdentityPassword(3, "new-identity-password")
        verifyNoMoreInteractions(passwords)
    }

    @Test fun explicitClearRemovesStoredPassword() {
        passwords.updateHostPassword(host, mapOf("clearPassword" to true))
        passwords.updateIdentityPassword(3, mapOf("clearPassword" to true))
        verify(passwords).deletePassword(7)
        verify(passwords).deleteIdentityPassword(3)
        verifyNoMoreInteractions(passwords)
    }

    @Test fun replacementAfterClearSavesTheNewPassword() {
        passwords.updateHostPassword(host, mapOf("clearPassword" to true, "password" to "replacement"))
        passwords.updateIdentityPassword(3, mapOf("clearPassword" to true, "password" to "replacement"))
        verify(passwords).savePassword(7, "replacement")
        verify(passwords).saveIdentityPassword(3, "replacement")
        verifyNoMoreInteractions(passwords)
    }

    @Test fun sharedAccountRemovesPerHostPassword() {
        passwords.updateHostPassword(host.copy(identityId = 3), mapOf("password" to "ignored"))
        verify(passwords).deletePassword(7)
        verifyNoMoreInteractions(passwords)
    }

    @Test fun localAndTelnetEditsDoNotChangePasswords() {
        for (protocol in listOf("local", "telnet")) {
            passwords.updateHostPassword(host.copy(protocol = protocol), mapOf("clearPassword" to true))
        }
        verifyNoInteractions(passwords)
    }
}
