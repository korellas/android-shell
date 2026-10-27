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
import org.connectbot.data.entity.AutomationActionType
import org.connectbot.data.entity.AutomationFailurePolicy
import org.connectbot.data.entity.Host
import org.connectbot.data.entity.PortForward
import org.junit.Assert.assertThrows
import org.junit.Test

class EngineSelectionValidationTest {
    @Test
    fun unsupportedHostProtocolsCanBePreservedOrConvertedButNotNewlySelected() {
        for (protocol in listOf("mosh", "telnet")) {
            val previous = Host(id = 1, protocol = protocol)
            assertThrows(IllegalArgumentException::class.java) { validateHostSelection(previous, null, null) }
            assertThrows(IllegalArgumentException::class.java) { validateHostSelection(previous, Host(id = 1), null) }
            validateHostSelection(previous.copy(nickname = "renamed"), previous, null)
            validateHostSelection(previous.copy(protocol = "ssh"), previous, null)
        }
    }

    @Test
    fun newJumpSelectionRequiresAnotherExistingSshHost() {
        val host = Host(id = 1, jumpHostId = 2)
        validateHostSelection(host, null, Host(id = 2))
        for (jump in listOf(null, Host(id = 1), Host(id = 2, protocol = "local"))) {
            assertThrows(IllegalArgumentException::class.java) { validateHostSelection(host, null, jump) }
        }
        validateHostSelection(host.copy(nickname = "renamed"), host, null)
        validateHostSelection(host.copy(jumpHostId = null), host, null)
    }

    @Test
    fun socks4CannotBeCreatedOrEnabledButExistingMetadataCanBeSavedOrDisabled() {
        val legacy = PortForward(id = 1, hostId = 1, nickname = "legacy", type = "dynamic4", sourcePort = 1080, destAddr = null, destPort = 0)
        assertThrows(IllegalArgumentException::class.java) { validateForwardSelection(legacy, null) }
        validateForwardSelection(legacy.copy(nickname = "renamed"), legacy)
        val disabled = legacy.copy(startEnabled = false)
        validateForwardSelection(disabled, legacy)
        assertThrows(IllegalArgumentException::class.java) { validateForwardSelection(legacy, disabled) }
        validateForwardSelection(legacy.copy(type = "dynamic5"), legacy)
    }

    @Test
    fun localForwardAutomationCannotBeAddedButItsStoredSelectionCanBePreserved() {
        val local = Host(protocol = "local")
        for (type in listOf(AutomationActionType.ENABLE_FORWARD, AutomationActionType.DISABLE_FORWARD)) {
            val action = AutomationAction(id = "legacy", hostId = 1, type = type, forwardId = 2)
            assertThrows(IllegalArgumentException::class.java) { validateAutomationSelection(action, local, null) }
            assertThrows(IllegalArgumentException::class.java) { validateAutomationSelection(action.copy(forwardId = 3), local, action) }
            validateAutomationSelection(action.copy(failurePolicy = AutomationFailurePolicy.CONTINUE), local, action)
            validateAutomationSelection(action.copy(type = AutomationActionType.SEND_TEXT), local, action)
            validateAutomationSelection(action, Host(), null)
        }
    }
}
