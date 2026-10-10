/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2025-2026 Kenny Root
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

package org.connectbot.service

import android.app.backup.BackupAgentHelper
import android.app.backup.FullBackupDataOutput
import android.app.backup.SharedPreferencesBackupHelper
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.preference.PreferenceManager
import androidx.room.Room
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.connectbot.data.ColorSchemeRepository
import org.connectbot.data.ConnectBotDatabase
import org.connectbot.data.HostRepository
import org.connectbot.data.PubkeyRepository
import org.connectbot.di.CoroutineDispatchers
import org.connectbot.util.LocalFontProvider
import org.connectbot.util.PreferenceConstants
import org.connectbot.util.SecurePasswordStorage
import java.io.EOFException
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class BackupAgent : BackupAgentHelper() {
    private var snapshotRestored = false

    override fun onCreate() {
        // Keep restoring preferences from older key/value backups.
        addHelper(PreferenceConstants.BACKUP_PREF_KEY, SharedPreferencesBackupHelper(this, packageName + "_preferences"))
    }

    override fun onFullBackup(data: FullBackupDataOutput) {
        val preferences = File(dataDir, "shared_prefs/${packageName}_preferences.xml")
        if (preferences.isFile) fullBackupFile(preferences, data)
        val fonts = File(filesDir, LocalFontProvider.FONTS_DIR).canonicalFile
        fonts.walkTopDown().filter { it.isFile && it.canonicalPath.startsWith(fonts.path + File.separator) }
            .forEach { fullBackupFile(it, data) }

        if (!getDatabasePath(DATABASE_NAME).isFile) return
        val encryptedTransport = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            data.transportFlags and (FLAG_CLIENT_SIDE_ENCRYPTION_ENABLED or FLAG_DEVICE_TO_DEVICE_TRANSFER) != 0
        val backupKeys = encryptedTransport && PreferenceManager.getDefaultSharedPreferences(this)
            .getBoolean(PreferenceConstants.BACKUP_KEYS, PreferenceConstants.BACKUP_KEYS_DEFAULT)
        val snapshot = getDatabasePath(SNAPSHOT_NAME)
        // Auto Backup runs in restricted mode, without the normal Hilt application.
        val database = Room.databaseBuilder(this, ConnectBotDatabase::class.java, DATABASE_NAME)
            .addMigrations(ConnectBotDatabase.MIGRATION_4_5, ConnectBotDatabase.MIGRATION_10_11).build()
        val dispatchers = CoroutineDispatchers(default = Dispatchers.Default, io = Dispatchers.IO, main = Dispatchers.Main)
        val hosts = HostRepository(this, database, database.hostDao(), database.portForwardDao(), database.knownHostDao(), SecurePasswordStorage(this))
        val filter = BackupFilter(this, hosts, ColorSchemeRepository(database.colorSchemeDao(), dispatchers), PubkeyRepository(database.pubkeyDao()))
        try {
            runBlocking { filter.buildFilteredDatabase(snapshot, backupKeys) }
            fullBackupFile(snapshot, data)
        } finally {
            filter.cleanupTempDatabase(snapshot)
            database.close()
        }
    }

    override fun onRestoreFile(data: ParcelFileDescriptor, size: Long, destination: File, type: Int, mode: Long, mtime: Long) {
        val target = destination.canonicalFile
        val snapshot = getDatabasePath(SNAPSHOT_NAME).canonicalFile
        val preferences = File(dataDir, "shared_prefs/${packageName}_preferences.xml").canonicalFile
        val fonts = File(filesDir, LocalFontProvider.FONTS_DIR).canonicalFile
        val accepted = target == snapshot || target == preferences ||
            target.path.startsWith(fonts.path + File.separator)
        if (accepted) {
            super.onRestoreFile(data, size, target, type, mode, mtime)
            if (target == snapshot && type == TYPE_FILE) snapshotRestored = true
        } else {
            // The framework owns this descriptor; consume only this entry, without closing it.
            val input = FileInputStream(data.fileDescriptor)
            val buffer = ByteArray(8192)
            var remaining = size
            while (remaining > 0) {
                val read = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (read < 0) throw EOFException("Incomplete backup entry")
                remaining -= read
            }
        }
    }

    override fun onRestoreFinished() {
        super.onRestoreFinished()
        val snapshot = getDatabasePath(SNAPSHOT_NAME)
        if (!snapshotRestored || !snapshot.isFile) return
        val live = getDatabasePath(DATABASE_NAME)
        if (!snapshot.renameTo(live)) throw IOException("Could not restore connection database")
        // Restore runs before app launch; journals from the replaced database must not be replayed.
        File(live.path + "-wal").delete()
        File(live.path + "-shm").delete()
        val passwords = File(dataDir, "shared_prefs/${SecurePasswordStorage.PREFS_FILE_NAME}.xml")
        for (file in listOf(passwords, File(passwords.path + ".bak"))) {
            if (file.exists() && !file.delete()) throw IOException("Could not clear device-bound passwords after restore")
        }
        snapshotRestored = false
    }

    companion object {
        private const val DATABASE_NAME = "connectbot.db"
        private const val SNAPSHOT_NAME = "connectbot_backup_temp.db"
    }
}
