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

import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class LauncherActivityTest {
    @Test
    fun exportedLauncherStripsUntrustedIntentState() {
        val incoming = Intent("evil.action.CONNECT").apply {
            data = Uri.parse("ssh://attacker@example.test")
            addCategory("evil.category")
            putExtra("sessionId", "attacker-controlled")
        }
        val activity = Robolectric.buildActivity(LauncherActivity::class.java, incoming).create().get()

        val launched = shadowOf(activity).nextStartedActivity
        assertEquals(ComponentName(activity, FlutterShellActivity::class.java), launched.component)
        assertEquals(Intent.ACTION_MAIN, launched.action)
        assertNull(launched.data)
        assertNull(launched.categories)
        assertTrue(launched.extras == null || launched.extras!!.isEmpty)
    }

    @Test
    fun onlyTheDataFreeLauncherIsExportedAndAndroidBackupIsDisabled() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val manager = context.packageManager
        val launcher = manager.getActivityInfo(ComponentName(context, LauncherActivity::class.java), 0)
        val shell = manager.getActivityInfo(ComponentName(context, FlutterShellActivity::class.java), 0)
        val app = manager.getApplicationInfo(context.packageName, 0)

        assertTrue(launcher.exported)
        assertFalse(shell.exported)
        assertEquals(0, app.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
    }
}
