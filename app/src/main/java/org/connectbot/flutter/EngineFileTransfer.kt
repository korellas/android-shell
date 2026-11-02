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
    check(directory.isDirectory || directory.mkdirs()) { "파일 전송 임시 폴더를 만들 수 없습니다." }
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
                require(!name.isNullOrBlank()) { "선택한 파일의 이름을 읽을 수 없습니다." }
                val staged = newTransferFile()
                try {
                    requireNotNull(resolver.openInputStream(uri)) { "선택한 파일을 열 수 없습니다." }.use { source ->
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
                        requireNotNull(activity.contentResolver.openOutputStream(uri, "wt")) { "다운로드 파일을 열 수 없습니다." }.use { output ->
                            staged.inputStream().use { input -> input.copyTo(output) }
                        }
                    } catch (error: Exception) {
                        if (!DocumentsContract.deleteDocument(activity.contentResolver, uri)) {
                            throw IOException("다운로드 저장 실패: ${error.message}. 불완전 파일을 지우지 못했습니다: $uri", error)
                        }
                        throw error
                    }
                } else {
                    check(DocumentsContract.deleteDocument(activity.contentResolver, uri)) { "취소한 다운로드 파일을 지우지 못했습니다: $uri" }
                }
            }
        } finally {
            check(staged.delete()) { "파일 전송 임시 파일을 지우지 못했습니다: ${staged.path}" }
        }
        null
    }

    else -> error("Unsupported file transfer operation: $method")
}
