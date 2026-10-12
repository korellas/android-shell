/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2025-2026 Kenny Root
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

package org.connectbot.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import org.connectbot.R

private val tildeFontFamily = FontFamily(Font(R.font.pretendard_regular))
private val baseTypography = Typography()

val AppTypography = Typography(
    displayLarge = baseTypography.displayLarge.copy(fontFamily = tildeFontFamily),
    displayMedium = baseTypography.displayMedium.copy(fontFamily = tildeFontFamily),
    displaySmall = baseTypography.displaySmall.copy(fontFamily = tildeFontFamily),
    headlineLarge = baseTypography.headlineLarge.copy(fontFamily = tildeFontFamily),
    headlineMedium = baseTypography.headlineMedium.copy(fontFamily = tildeFontFamily),
    headlineSmall = baseTypography.headlineSmall.copy(fontFamily = tildeFontFamily),
    titleMedium = baseTypography.titleMedium.copy(fontFamily = tildeFontFamily),
    titleSmall = baseTypography.titleSmall.copy(fontFamily = tildeFontFamily),
    bodyMedium = baseTypography.bodyMedium.copy(fontFamily = tildeFontFamily),
    bodySmall = baseTypography.bodySmall.copy(fontFamily = tildeFontFamily),
    labelLarge = baseTypography.labelLarge.copy(fontFamily = tildeFontFamily),
    labelMedium = baseTypography.labelMedium.copy(fontFamily = tildeFontFamily),
    bodyLarge = TextStyle(
        fontFamily = tildeFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = tildeFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = tildeFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp,
    ),
)
