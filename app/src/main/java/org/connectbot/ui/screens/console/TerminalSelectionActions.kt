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

package org.connectbot.ui.screens.console

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import org.connectbot.R
import org.connectbot.terminal.SelectionController
import org.connectbot.terminal.SelectionMode

@Composable
internal fun TerminalSelectionActions(
    controller: SelectionController,
    onEdit: (String) -> Unit,
    onPaste: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(modifier, shape = RoundedCornerShape(16.dp), shadowElevation = 8.dp, tonalElevation = 6.dp) {
        Row {
            TextButton(onClick = { controller.copySelection() }) { Text(stringResource(R.string.selection_copy)) }
            TextButton(onClick = {
                controller.clearSelection()
                onPaste()
            }) { Text(stringResource(R.string.console_menu_paste)) }
            TextButton(onClick = { controller.setSelectionMode(SelectionMode.LINE) }) { Text(stringResource(R.string.selection_line)) }
            TextButton(onClick = { onEdit(controller.copySelection()) }) { Text(stringResource(R.string.selection_edit)) }
            IconButton(onClick = controller::clearSelection) {
                Icon(Icons.Default.Close, stringResource(R.string.button_close))
            }
        }
    }
}
