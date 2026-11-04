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

import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import kotlinx.coroutines.withContext
import org.connectbot.R
import java.io.File
import java.io.IOException

internal fun requireTransferFile(cacheDirectory: File, path: String): File {
    val file = File(path).canonicalFile
    val directory = File(cacheDirectory, "sftp-transfer").canonicalFile
    require(file.parentFile == directory && file.isFile) { "Invalid staged transfer file" }
    return file
}

private fun AndroidShellEngine.newTransferFile(): File {
    val directory = File(activity.cacheDir, "sftp-transfer")
    check(directory.isDirectory || directory.mkdirs()) { activity.getString(R.string.flutter_could_not_create_the_temporary_transfer_folder) }
    return File.createTempFile("transfer-", ".part", directory)
}

internal suspend fun AndroidShellEngine.fileTransferOperation(method: String, args: Wire): Any? = when (method) {
    "file.pickUpload" -> {
        val uri = withContext(activity.dispatchers.main) { activity.pickDocument(arrayOf("*/*")) }
        if (uri == null) {
            null
        } else {
            withContext(activity.dispatchers.io) {
                val resolver = activity.contentResolver
                val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)) else null
                }
                require(!name.isNullOrBlank()) { activity.getString(R.string.flutter_could_not_read_the_selected_file_name) }
                val staged = newTransferFile()
                try {
                    requireNotNull(resolver.openInputStream(uri)) { activity.getString(R.string.flutter_could_not_open_the_selected_file) }.use { source ->
                        staged.outputStream().use { output -> source.copyTo(output) }
                    }
                    mapOf("path" to staged.path, "name" to name, "size" to staged.length())
                } catch (error: Exception) {
                    staged.delete()
                    throw error
                }
            }
        }
    }

    "file.prepareDownload" -> {
        val uri = withContext(activity.dispatchers.main) { activity.createDocument(args.text("name")) }
        if (uri == null) {
            null
        } else {
            withContext(activity.dispatchers.io) {
                try {
                    mapOf("path" to newTransferFile().path, "uri" to uri.toString())
                } catch (error: Exception) {
                    DocumentsContract.deleteDocument(activity.contentResolver, uri)
                    throw error
                }
            }
        }
    }

    "file.finishTransfer" -> withContext(activity.dispatchers.io) {
        val staged = requireTransferFile(activity.cacheDir, args.text("path"))
        val uri = args.optionalText("uri")?.let(Uri::parse)
        try {
            if (uri != null) {
                if (args.flag("save")) {
                    try {
                        requireNotNull(activity.contentResolver.openOutputStream(uri, "wt")) { activity.getString(R.string.flutter_could_not_open_the_download_file) }.use { output ->
                            staged.inputStream().use { input -> input.copyTo(output) }
                        }
                    } catch (error: Exception) {
                        if (!DocumentsContract.deleteDocument(activity.contentResolver, uri)) {
                            throw IOException(activity.getString(R.string.flutter_could_not_save_download_1_s_could_not, error.message, uri), error)
                        }
                        throw error
                    }
                } else {
                    check(DocumentsContract.deleteDocument(activity.contentResolver, uri)) { activity.getString(R.string.flutter_could_not_remove_cancelled_download_1_s, uri) }
                }
            }
        } finally {
            check(staged.delete()) { activity.getString(R.string.flutter_could_not_remove_temporary_transfer_file_1_s, staged.path) }
        }
        null
    }

    else -> error("Unsupported file transfer operation: $method")
}
