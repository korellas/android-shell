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

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class EngineFileTransferTest {
    @get:Rule val folder = TemporaryFolder()

    @Test
    fun `accepts only a staged file in transfer cache`() {
        val cache = folder.newFolder("cache")
        val staged = File(File(cache, "sftp-transfer").apply { mkdirs() }, "transfer.part").apply { writeText("data") }
        assertEquals(staged.canonicalFile, requireTransferFile(cache, staged.path))
    }

    @Test
    fun `rejects paths outside transfer cache without touching files`() {
        val cache = folder.newFolder("cache")
        File(cache, "sftp-transfer").mkdirs()
        val unrelated = File(cache, "important").apply { writeText("original") }
        assertThrows(IllegalArgumentException::class.java) { requireTransferFile(cache, unrelated.path) }
        assertThrows(IllegalArgumentException::class.java) { requireTransferFile(cache, File(cache, "sftp-transfer/../important").path) }
        assertEquals("original", unrelated.readText())
    }
}
