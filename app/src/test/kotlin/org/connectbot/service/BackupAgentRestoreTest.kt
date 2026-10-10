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

package org.connectbot.service

import android.content.Context
import android.os.ParcelFileDescriptor
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 35])
class BackupAgentRestoreTest {
    @Before
    fun resetFrameworkPathsBetweenTestDirectories() {
        // Robolectric changes the app data directory between tests; FullBackup caches it by package.
        ReflectionHelpers.getStaticField<MutableMap<*, *>>(Class.forName("android.app.backup.FullBackup"), "kPackageBackupSchemeMap").clear()
    }

    @Test
    fun replacingDatabaseClearsOldPasswordsWhoseHostIdsCouldCollide() {
        val passwordFile = File(context.dataDir, "shared_prefs/secure_host_passwords.xml")
        passwordFile.parentFile!!.mkdirs()
        passwordFile.writeText("old-device-ciphertext")
        val live = context.getDatabasePath("connectbot.db")
        try {
            restore(context.getDatabasePath("connectbot_backup_temp.db"), "restored hosts")
            assertFalse(passwordFile.exists())
        } finally {
            passwordFile.delete()
            live.delete()
        }
    }
    private val context = ReflectionHelpers.callInstanceMethod<Context>(
        ApplicationProvider.getApplicationContext<Context>(),
        "createCredentialProtectedStorageContext",
    )

    private fun restore(destination: File, text: String) {
        val agent = BackupAgent()
        ReflectionHelpers.callInstanceMethod<Unit>(agent, "attachBaseContext", ReflectionHelpers.ClassParameter.from(Context::class.java, context))
        val source = File.createTempFile("restore-input", ".txt", context.cacheDir)
        try {
            source.writeText(text)
            ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                agent.onRestoreFile(descriptor, source.length(), destination, android.app.backup.BackupAgent.TYPE_FILE, 384, 0)
            }
            if (destination.name == "connectbot_backup_temp.db") {
                assertTrue("Restore must write the filtered snapshot before finalizing", destination.exists())
            }
            agent.onRestoreFinished()
        } finally {
            source.delete()
        }
    }

    @Test
    fun filteredSnapshotRestoresAsLiveDatabase() {
        val live = context.getDatabasePath("connectbot.db")
        try {
            restore(context.getDatabasePath("connectbot_backup_temp.db"), "filtered snapshot")
            assertEquals("filtered snapshot", live.readText())
        } finally {
            live.delete()
            context.getDatabasePath("connectbot_backup_temp.db").delete()
        }
    }

    @Test
    fun defaultPreferencesRestoreFromTheSystemSharedPreferencesDomain() {
        val preferences = File(context.dataDir, "shared_prefs/${context.packageName}_preferences.xml")
        try {
            restore(preferences, "app preferences")
            assertEquals("app preferences", preferences.readText())
        } finally {
            preferences.delete()
        }
    }

    @Test
    fun encryptedPasswordsAreNeverRestoredToAnotherDevice() {
        val secret = File(context.dataDir, "shared_prefs/secure_host_passwords.xml")
        try {
            restore(secret, "device-bound ciphertext")
            assertFalse(secret.exists())
        } finally {
            secret.delete()
        }
    }
}
