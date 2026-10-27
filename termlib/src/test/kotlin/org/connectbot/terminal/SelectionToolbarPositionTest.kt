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

import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import org.junit.Assert.assertEquals
import org.junit.Test

class SelectionToolbarPositionTest {
    @Test
    fun placesToolbarBelowSelectionAndClampsAtRightEdge() {
        assertEquals(
            IntOffset(80, 100),
            selectionToolbarOffset(IntOffset(300, 100), 60, IntSize(240, 48), IntSize(320, 480)),
        )
    }

    @Test
    fun placesToolbarAboveWhenItDoesNotFitBelow() {
        assertEquals(
            IntOffset(12, 350),
            selectionToolbarOffset(IntOffset(12, 460), 398, IntSize(240, 48), IntSize(320, 480)),
        )
    }

    @Test
    fun clampsMeasuredLargeTextToolbarInsideShortViewport() {
        assertEquals(
            IntOffset(0, 0),
            selectionToolbarOffset(IntOffset(-10, 50), 20, IntSize(320, 120), IntSize(320, 128)),
        )
    }

    @Test
    fun clampsAbovePlacementToRemainingViewportHeight() {
        assertEquals(
            IntOffset(0, 32),
            selectionToolbarOffset(IntOffset(200, 500), 490, IntSize(320, 96), IntSize(320, 128)),
        )
    }
}
