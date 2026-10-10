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

import android.content.SharedPreferences
import androidx.core.content.edit

enum class TerminalBarKey(val label: String) {
    ALT("Alt"),
    UP("↑"),
    DOWN("↓"),
    LEFT("←"),
    RIGHT("→"),
    HOME("Home"),
    END("End"),
    PAGE_UP("PgUp"),
    PAGE_DOWN("PgDn"),
    INSERT("Ins"),
    DELETE("Del"),
    FUNCTION_KEYS("F1–F12"),
}

data class TerminalBarLayout(
    val keyHeight: Int = 28,
    val order: List<TerminalBarKey> = TerminalBarKey.entries,
    val hidden: Set<TerminalBarKey> = emptySet(),
    val groupFunctionKeys: Boolean = true,
) {
    val height: Int get() = keyHeight + 8
    val visibleKeys: List<TerminalBarKey> get() = order.filterNot { it in hidden }

    fun save(prefs: SharedPreferences) {
        prefs.edit {
            putInt(PreferenceConstants.TERMINAL_BAR_HEIGHT, keyHeight)
            putString(PreferenceConstants.TERMINAL_BAR_ORDER, order.joinToString(",") { it.name })
            putStringSet(PreferenceConstants.TERMINAL_BAR_HIDDEN, hidden.map { it.name }.toSet())
            putBoolean(PreferenceConstants.TERMINAL_BAR_FN, groupFunctionKeys)
        }
    }

    companion object {
        val heights = listOf(26, 28, 36)

        fun load(prefs: SharedPreferences): TerminalBarLayout {
            val savedOrder = prefs.getString(PreferenceConstants.TERMINAL_BAR_ORDER, "") ?: ""
            val order = savedOrder.split(",").mapNotNull { name -> TerminalBarKey.entries.find { it.name == name } }.distinct()
            val hidden = prefs.getStringSet(PreferenceConstants.TERMINAL_BAR_HIDDEN, emptySet()).orEmpty()
            return TerminalBarLayout(
                keyHeight = prefs.getInt(PreferenceConstants.TERMINAL_BAR_HEIGHT, 28).takeIf { it in heights } ?: 28,
                order = order + TerminalBarKey.entries.filterNot { it in order },
                hidden = TerminalBarKey.entries.filter { it.name in hidden }.toSet(),
                groupFunctionKeys = prefs.getBoolean(PreferenceConstants.TERMINAL_BAR_FN, true),
            )
        }
    }
}
