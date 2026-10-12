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

package org.connectbot.terminal

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TerminalCursorColorTest {
    @Test
    fun coloredBlockUsesExactColorAndKeepsGlyphContrast() {
        val bitmap = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inversion = TerminalInversion()
        inversion.reset()
        inversion.cursor(RectF(0f, 0f, 8f, 8f), Color(0xff6fd8c4))
        inversion.draw(canvas) {
            canvas.drawColor(android.graphics.Color.BLACK)
            canvas.drawRect(2f, 2f, 4f, 4f, Paint().apply { color = android.graphics.Color.WHITE })
        }
        assertEquals(0xff6fd8c4.toInt(), bitmap.getPixel(0, 0))
        assertEquals(android.graphics.Color.BLACK, bitmap.getPixel(3, 3))
        bitmap.recycle()
    }
}
