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

/** Persisted automation and Flutter keyboard wire codes. */
object VTermKey {
    const val NONE = 0
    const val ENTER = 1
    const val TAB = 2
    const val BACKSPACE = 3
    const val ESCAPE = 4

    const val UP = 5
    const val DOWN = 6
    const val LEFT = 7
    const val RIGHT = 8

    const val INS = 9
    const val DEL = 10
    const val HOME = 11
    const val END = 12
    const val PAGEUP = 13
    const val PAGEDOWN = 14

    // In vterm_keycodes.h enum VTERM_KEY_FUNCTION_0 = 256
    const val FUNCTION_0 = 256
    const val FUNCTION_1 = 257
    const val FUNCTION_2 = 258
    const val FUNCTION_3 = 259
    const val FUNCTION_4 = 260
    const val FUNCTION_5 = 261
    const val FUNCTION_6 = 262
    const val FUNCTION_7 = 263
    const val FUNCTION_8 = 264
    const val FUNCTION_9 = 265
    const val FUNCTION_10 = 266
    const val FUNCTION_11 = 267
    const val FUNCTION_12 = 268

    // Keypad keys (start after FUNCTION_MAX which is 256 + 255 = 511)
    const val KP_0 = 512
    const val KP_1 = 513
    const val KP_2 = 514
    const val KP_3 = 515
    const val KP_4 = 516
    const val KP_5 = 517
    const val KP_6 = 518
    const val KP_7 = 519
    const val KP_8 = 520
    const val KP_9 = 521
    const val KP_MULT = 522
    const val KP_PLUS = 523
    const val KP_COMMA = 524
    const val KP_MINUS = 525
    const val KP_PERIOD = 526
    const val KP_DIVIDE = 527
    const val KP_ENTER = 528
    const val KP_EQUAL = 529
}
