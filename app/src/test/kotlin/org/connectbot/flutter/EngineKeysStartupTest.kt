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

import kotlinx.coroutines.test.runTest
import org.connectbot.data.PubkeyRepository
import org.connectbot.data.entity.Pubkey
import org.connectbot.service.TerminalManager
import org.connectbot.ui.screens.pubkeylist.PubkeyListViewModel
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class EngineKeysStartupTest {
    @Test
    fun editingEncryptedStartupKeyPreservesPassphrasePromptBehavior() = runTest {
        val key = Pubkey(id = 2, nickname = "Protected", type = "RSA", publicKey = byteArrayOf(1), privateKey = byteArrayOf(2), encrypted = true, startup = true, confirmation = false, createdDate = 0)
        val engine = Mockito.mock(AndroidShellEngine::class.java)
        val activity = Mockito.mock(FlutterShellActivity::class.java)
        val keys = Mockito.mock(PubkeyRepository::class.java)
        val manager = Mockito.mock(TerminalManager::class.java)
        Mockito.`when`(engine.activity).thenReturn(activity)
        Mockito.`when`(activity.keyList).thenReturn(Mockito.mock(PubkeyListViewModel::class.java))
        Mockito.`when`(engine.keys).thenReturn(keys)
        Mockito.`when`(engine.manager).thenReturn(manager)
        Mockito.`when`(keys.getById(key.id)).thenReturn(key)
        engine.keyOperation("key.save", mapOf("id" to key.id, "nickname" to "Renamed"))
        val saved = Mockito.mockingDetails(keys).invocations.single { it.method.name == "save" }.arguments[0] as Pubkey
        assertEquals(key.copy(nickname = "Renamed"), saved)
    }
}
