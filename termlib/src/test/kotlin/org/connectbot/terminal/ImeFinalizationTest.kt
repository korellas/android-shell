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

import android.content.Context
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.runtime.snapshots.SnapshotStateObserver
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.anyInt
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowKeyCharacterMap

@RunWith(AndroidJUnit4::class)
@Config(shadows = [ImeFinalizationTest.UnmappedCharacterKeyMap::class])
class ImeFinalizationTest {
    private lateinit var terminal: TerminalEmulatorImpl
    private lateinit var received: StringBuilder
    private lateinit var handler: KeyboardHandler
    private lateinit var view: ImeInputView
    private lateinit var connection: InputConnection

    @Before
    fun setUp() {
        terminal = mock(TerminalEmulatorImpl::class.java)
        received = StringBuilder()
        doAnswer {
            received.appendCodePoint(it.getArgument<Int>(1))
            null
        }.`when`(terminal).dispatchCharacter(anyInt(), anyInt())
        handler = KeyboardHandler(terminal)
        view = ImeInputView(
            ApplicationProvider.getApplicationContext<Context>(),
            handler,
            onUpdateSelection = { _, _, _, _, _ -> },
            onRestartInput = {},
            onShowKeyboard = {},
            onHideKeyboard = {},
        )
        view.setOnKeyListener { _, _, event -> view.handleRawKeyEvent(event) }
        connection = view.onCreateInputConnection(EditorInfo())
    }

    @Test
    fun finalHangulSyllablesSurviveSpaceAndEnter() {
        connection.commitText("안녕하세", 1)
        connection.setComposingText("요", 1)
        connection.finishComposingText()
        connection.commitText(" ", 1)
        connection.commitText("한국인입니", 1)
        connection.setComposingText("다", 1)
        connection.finishComposingText()
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))

        assertEquals("안녕하세요 한국인입니다", received.toString())
        verify(terminal).dispatchKey(0, VTermKey.ENTER)
    }

    @Test
    fun compositionRevisionsSendOnlyTheFinalText() {
        connection.setComposingText("ㅂ", 1)
        connection.setComposingText("바", 1)
        connection.setComposingText("방", 1)
        connection.finishComposingText()
        connection.finishComposingText()

        assertEquals("방", received.toString())
    }

    @Test
    fun pendingHangulCompositionIsVisibleWithoutSendingIntermediateText() {
        for (text in listOf("ㅂ", "부", "붸", "뷀", "뷁")) {
            connection.setComposingText(text, 1)

            assertEquals(text, view.preeditText)
            assertEquals("", received.toString())
        }
        connection.finishComposingText()

        assertEquals("", view.preeditText)
        assertEquals("뷁", received.toString())
    }

    @Test
    fun pendingCompositionChangesInvalidateTheDrawObserver() {
        val observer = SnapshotStateObserver { it() }
        var redraws = 0
        observer.start()
        try {
            observer.observeReads(Unit, { _: Unit -> redraws++ }) { view.preeditText }
            connection.setComposingText("ㅂ", 1)
            Snapshot.sendApplyNotifications()

            assertTrue("Pending composition must invalidate the canvas", redraws > 0)
        } finally {
            observer.stop()
            observer.clear()
        }
    }

    @Test
    fun explicitCommitClearsThePendingPreview() {
        connection.setComposingText("바", 1)
        assertEquals("바", view.preeditText)
        connection.commitText("방", 1)

        assertEquals("", view.preeditText)
        assertEquals("방", received.toString())
        connection.finishComposingText()
        assertEquals("방", received.toString())
    }

    @Test
    fun shrinkingOrCancellingCompositionUpdatesThePreviewWithoutSending() {
        for (text in listOf("뷁", "붸", "ㅂ", "")) {
            connection.setComposingText(text, 1)
            assertEquals(text, view.preeditText)
        }
        connection.finishComposingText()

        assertEquals("", view.preeditText)
        assertEquals("", received.toString())
    }

    @Test
    fun resettingImeClearsThePendingPreview() {
        connection.setComposingText("한", 1)
        assertEquals("한", view.preeditText)
        view.resetImeBuffer()

        assertEquals("", view.preeditText)
        connection.finishComposingText()
        assertEquals("", received.toString())
    }

    @Test
    fun newInputConnectionDoesNotKeepAnOldPreview() {
        connection.setComposingText("한", 1)
        assertEquals("한", view.preeditText)
        connection = view.onCreateInputConnection(EditorInfo())

        assertEquals("", view.preeditText)
        connection.finishComposingText()
        assertEquals("", received.toString())
    }

    @Test
    fun everyPrecomposedHangulSyllableSurvivesFinalization() {
        val expected = StringBuilder()
        for (codePoint in '가'.code..'힣'.code) {
            val syllable = codePoint.toChar().toString()
            connection.setComposingText(syllable, 1)
            connection.finishComposingText()
            expected.append(syllable)
        }

        assertEquals(expected.toString(), received.toString())
    }

    @Test
    fun explicitCommitDoesNotReplayAnOlderComposition() {
        connection.setComposingText("바", 1)
        connection.commitText("방", 1)
        connection.finishComposingText()
        connection.finishComposingText()

        assertEquals("방", received.toString())
    }

    @Test
    fun finalizedUnicodePreservesCodePointsAndNormalizesText() {
        connection.setComposingText("한글🙂日本語e\u0301", 1)
        connection.finishComposingText()

        assertEquals("한글🙂日本語é", received.toString())
    }

    @Test
    fun keyDownAndKeyUpDoNotDuplicateAsciiAndSpecialKeys() {
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_A))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_A))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_TAB))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_TAB))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ESCAPE))
        connection.deleteSurroundingText(1, 0)

        assertEquals("a", received.toString())
        verify(terminal).dispatchKey(0, VTermKey.TAB)
        verify(terminal).dispatchKey(0, VTermKey.ESCAPE)
        verify(terminal).dispatchKey(0, VTermKey.BACKSPACE)
    }

    @Test
    fun ctrlAndAltStillApplyToCommittedText() {
        val modifiers = mock(ModifierManager::class.java)
        handler.modifierManager = modifiers
        `when`(modifiers.isCtrlActive()).thenReturn(true)
        connection.commitText("c", 1)

        `when`(modifiers.isCtrlActive()).thenReturn(false)
        `when`(modifiers.isAltActive()).thenReturn(true)
        connection.commitText("x", 1)
        connection.finishComposingText()

        assertEquals("cx", received.toString())
        verify(terminal).dispatchCharacter(4, 'c'.code)
        verify(terminal).dispatchCharacter(2, 'x'.code)
    }

    @Test
    fun fullEditorCompositionStillFlushesOnEnter() {
        val compose = ComposeMode().apply { activate() }
        handler.composeMode = compose
        view.isComposeModeActive = true
        connection = view.onCreateInputConnection(EditorInfo())
        connection.setComposingText("ㅂ", 1)
        connection.setComposingText("방", 1)
        connection.finishComposingText()

        assertEquals("", received.toString())
        assertEquals("방", compose.buffer)
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))

        assertEquals("방", received.toString())
        assertEquals("", compose.buffer)
        verify(terminal).dispatchKey(0, VTermKey.ENTER)
    }

    // Robolectric synthesizes KEYCODE_UNKNOWN down/up events for unmapped characters.
    // Android returns null instead, making BaseInputConnection send ACTION_MULTIPLE.
    @Implements(KeyCharacterMap::class)
    class UnmappedCharacterKeyMap : ShadowKeyCharacterMap() {
        companion object {
            @JvmStatic
            @Implementation(methodName = "nativeGetEvents")
            fun eventsForCharacters(ptr: Long, chars: CharArray): Array<KeyEvent>? {
                val events = ShadowKeyCharacterMap.nativeGetEvents(ptr, chars)
                return events.takeUnless { it.any { event -> event.keyCode == KeyEvent.KEYCODE_UNKNOWN } }
            }
        }
    }
}
