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

import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class FlutterShellActivityLifecycleTest {
    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @Test
    fun launchAndRecreateKeepInitializedBridgeAndCachedFlutterEngine() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val intent = Intent(instrumentation.targetContext, FlutterShellActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
        ActivityScenario.launch<FlutterShellActivity>(intent).use { scenario ->
            instrumentation.waitForIdleSync()
            lateinit var cachedEngine: FlutterEngine
            lateinit var firstBridge: AndroidShellEngine
            scenario.onActivity { activity ->
                cachedEngine = requireNotNull(activity.supportFragmentManager.fragments.filterIsInstance<FlutterFragment>().single().flutterEngine)
                firstBridge = activity.engine
                assertSame(activity, firstBridge.activity)
                assertSame(cachedEngine, activity.sessionRuntime.acquireEngine())
                assertTrue(cachedEngine.dartExecutor.isExecutingDart)
            }
            assertSnapshotResponds(scenario)

            scenario.recreate()
            instrumentation.waitForIdleSync()
            scenario.onActivity { activity ->
                assertSame(cachedEngine, activity.supportFragmentManager.fragments.filterIsInstance<FlutterFragment>().single().flutterEngine)
                assertSame(cachedEngine, activity.sessionRuntime.acquireEngine())
                assertTrue(cachedEngine.dartExecutor.isExecutingDart)
                assertNotSame(firstBridge, activity.engine)
                assertSame(activity, activity.engine.activity)
            }
            assertSnapshotResponds(scenario)
        }
    }

    private fun assertSnapshotResponds(scenario: ActivityScenario<FlutterShellActivity>) {
        val completed = CountDownLatch(1)
        val snapshot = AtomicReference<Map<*, *>?>()
        val failure = AtomicReference<String?>()
        scenario.onActivity { activity ->
            activity.engine.onMethodCall(
                MethodCall("snapshot", null),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        snapshot.set(result as? Map<*, *>)
                        completed.countDown()
                    }
                    override fun error(code: String, message: String?, details: Any?) {
                        failure.set("$code: $message")
                        completed.countDown()
                    }
                    override fun notImplemented() {
                        failure.set("snapshot was not implemented")
                        completed.countDown()
                    }
                },
            )
        }
        assertTrue("The current Activity bridge must respond after fragment initialization", completed.await(10, TimeUnit.SECONDS))
        assertNull(failure.get())
        assertEquals(true, snapshot.get()?.containsKey("ready"))
    }
}
