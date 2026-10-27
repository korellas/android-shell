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

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.connectbot.data.ConnectBotDatabase
import org.connectbot.data.entity.KnownHost
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File

@RunWith(RobolectricTestRunner::class)
class SshFingerprintMigrationTest {
    @Test
    fun schema14RawKeySurvivesAlongsideExplicitFingerprint() = runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "ssh-fingerprint-migration"
        context.deleteDatabase(name)
        val schema = JSONObject(File("schemas/org.connectbot.data.ConnectBotDatabase/14.json").readText()).getJSONObject("database")
        val rawKey = byteArrayOf(0, 1, 2, -1)
        context.openOrCreateDatabase(name, Context.MODE_PRIVATE, null).use { db ->
            val entities = schema.getJSONArray("entities")
            for (i in 0 until entities.length()) {
                val entity = entities.getJSONObject(i)
                val table = entity.getString("tableName")
                db.execSQL(entity.getString("createSql").replace("\${TABLE_NAME}", table))
                val indices = entity.getJSONArray("indices")
                for (j in 0 until indices.length()) {
                    db.execSQL(indices.getJSONObject(j).getString("createSql").replace("\${TABLE_NAME}", table))
                }
            }
            db.execSQL(
                "INSERT INTO known_hosts (host_id, hostname, port, host_key_algo, host_key) VALUES (NULL, 'server', 22, 'ssh-ed25519', ?)",
                arrayOf<Any>(rawKey),
            )
            db.version = 14
        }
        val database = Room.databaseBuilder(context, ConnectBotDatabase::class.java, name).build()
        try {
            val existing = database.knownHostDao().getAll().single()
            assertArrayEquals(rawKey, existing.hostKey)
            assertNull(existing.sha256Fingerprint)
            val fingerprint = existing.sshFingerprint()
            database.knownHostDao().insert(
                KnownHost(hostId = null, hostname = "other", port = 22, hostKeyAlgo = "ssh-ed25519", hostKey = byteArrayOf(), sha256Fingerprint = fingerprint),
            )
            val saved = database.knownHostDao().getByHostnameAndPort("other", 22).single()
            assertEquals(fingerprint, saved.sha256Fingerprint)
            assertArrayEquals(byteArrayOf(), saved.hostKey)
            assertArrayEquals(rawKey, database.knownHostDao().getByHostnameAndPort("server", 22).single().hostKey)
        } finally {
            database.close()
            context.deleteDatabase(name)
        }
    }
}
