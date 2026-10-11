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

import android.content.ContentResolver
import android.database.MatrixCursor
import android.net.Uri
import android.provider.OpenableColumns
import org.connectbot.ui.screens.settings.SettingsUiState
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class EngineSettingsFontTest {
    @Test
    fun importedFontUsesFileNameForSelectionAndDeletion() {
        val state = SettingsUiState(localFonts = listOf("My Font" to "My_Font.otf"))
        val fonts = state.toWire()["localFonts"] as List<*>
        assertEquals(mapOf("displayName" to "My Font", "fileName" to "My_Font.otf"), fonts.single())
    }

    @Test
    fun selectedFontKeepsProviderNameAndExtension() {
        val uri = Uri.parse("content://documents/opaque-id")
        for (name in listOf("한글_Font.otf", "Terminal.ttf", "Collection.ttc")) {
            val cursor = MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME))
            cursor.addRow(arrayOf(name))
            val resolver = Mockito.mock(ContentResolver::class.java)
            Mockito.`when`(resolver.query(ArgumentMatchers.eq(uri), ArgumentMatchers.any(), ArgumentMatchers.isNull(), ArgumentMatchers.isNull(), ArgumentMatchers.isNull())).thenReturn(cursor)
            assertEquals(name, resolver.selectedFontFileName(uri))
            assertEquals(true, cursor.isClosed)
        }
    }

    @Test
    fun missingDocumentNameUsesValidFontFileName() {
        val uri = Uri.parse("content://documents/opaque-id")
        val resolver = Mockito.mock(ContentResolver::class.java)
        assertEquals("Imported font.ttf", resolver.selectedFontFileName(uri))
    }
}
