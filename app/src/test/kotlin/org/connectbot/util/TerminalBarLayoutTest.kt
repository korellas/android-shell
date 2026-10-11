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

package org.connectbot.util

import android.content.Context
import androidx.core.content.edit
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

@RunWith(RobolectricTestRunner::class)
class TerminalBarLayoutTest {
    private val prefs = RuntimeEnvironment.getApplication().getSharedPreferences("terminal-bar-test", Context.MODE_PRIVATE)

    @Test
    fun layoutSurvivesReloadWithoutChangingFixedKeysOrOtherPreferences() {
        prefs.edit { putBoolean(PreferenceConstants.SWIPE_TMUX, true) }
        val layout = TerminalBarLayout(
            keyHeight = 36,
            order = TerminalBarKey.entries.reversed(),
            hidden = setOf(TerminalBarKey.ALT, TerminalBarKey.INSERT),
            groupFunctionKeys = false,
        )
        layout.save(prefs)
        assertEquals(layout, TerminalBarLayout.load(prefs))
        assertEquals(44, TerminalBarLayout.load(prefs).height)
        assertEquals(true, prefs.getBoolean(PreferenceConstants.SWIPE_TMUX, false))
    }

    @Test
    fun malformedSavedOrderIsNormalizedAndUnknownKeysAreIgnored() {
        prefs.edit {
            putInt(PreferenceConstants.TERMINAL_BAR_HEIGHT, -100)
            putString(PreferenceConstants.TERMINAL_BAR_ORDER, "DELETE,unknown,DELETE,ALT")
            putStringSet(PreferenceConstants.TERMINAL_BAR_HIDDEN, setOf("unknown", "ALT"))
        }
        val layout = TerminalBarLayout.load(prefs)
        assertEquals(28, layout.keyHeight)
        assertEquals(TerminalBarKey.entries.toSet(), layout.order.toSet())
        assertEquals(layout.order.size, layout.order.distinct().size)
        assertEquals(listOf(TerminalBarKey.DELETE, TerminalBarKey.ALT), layout.order.take(2))
        assertEquals(setOf(TerminalBarKey.ALT), layout.hidden)
    }
}
