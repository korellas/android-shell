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

package org.connectbot.transport

import com.trilead.ssh2.ChannelCondition
import com.trilead.ssh2.Connection
import com.trilead.ssh2.StreamGobbler
import com.trilead.ssh2.crypto.PublicKeyUtils
import java.io.IOException
import java.io.InputStream
import java.security.PublicKey

internal enum class KeyRegistration { ADDED, ALREADY_PRESENT }
internal enum class KeyLoginVerification { VERIFIED, REJECTED, ADDITIONAL_AUTH_REQUIRED }

internal object SshKeyEnrollment {
    val installScript = """
        cd || exit 1
        umask 077
        directory=.ssh
        file=.ssh/authorized_keys
        if [ -L "${'$'}directory" ] || [ -L "${'$'}file" ]; then
            printf '%s\n' 'Refusing a symlink in the SSH key path.' >&2
            exit 1
        fi
        if { [ -e "${'$'}directory" ] && [ ! -d "${'$'}directory" ]; } ||
           { [ -e "${'$'}file" ] && [ ! -f "${'$'}file" ]; }; then
            printf '%s\n' 'The SSH key path is not a regular directory and file.' >&2
            exit 1
        fi
        IFS= read -r key || exit 1
        IFS=' ' read -r kind blob comment <<KEY
        ${'$'}key
        KEY
        [ -n "${'$'}kind" ] && [ -n "${'$'}blob" ] || exit 1
        mkdir -p "${'$'}directory" &&
        touch "${'$'}file" &&
        chmod 700 "${'$'}directory" && chmod 600 "${'$'}file" || exit 1
        awk -v kind="${'$'}kind" -v blob="${'$'}blob" '
            /^[[:space:]]*#/ { next }
            { for (i = 1; i < NF; i++) if (${'$'}i == kind && ${'$'}(i + 1) == blob) found = 1 }
            END { exit !found }
        ' "${'$'}file"
        case ${'$'}? in
            0) printf '%s\n' ALREADY_PRESENT; exit 0 ;;
            1) ;;
            *) printf '%s\n' 'Could not check existing SSH keys.' >&2; exit 1 ;;
        esac
        if [ -s "${'$'}file" ] && [ -n "${'$'}(tail -c 1 "${'$'}file")" ]; then
            printf '\n' >> "${'$'}file" || exit 1
        fi
        printf '%s\n' "${'$'}key" >> "${'$'}file" || exit 1
        if command -v restorecon >/dev/null 2>&1; then
            restorecon "${'$'}directory" "${'$'}file" >/dev/null 2>&1 || :
        fi
        printf '%s\n' ADDED
    """.trimIndent()

    fun install(connection: Connection, publicKey: PublicKey): KeyRegistration {
        val keyLine = PublicKeyUtils.toAuthorizedKeysFormat(publicKey, "android-shell")
        require(!keyLine.contains('\n') && !keyLine.contains('\r'))
        connection.openSession().use { session ->
            StreamGobbler(session.stdout).use { stdout ->
                StreamGobbler(session.stderr).use { stderr ->
                    session.execCommand("exec sh -c '" + installScript.replace("'", "'\\''") + "'")
                    session.stdin.use { it.write((keyLine + "\n").toByteArray(Charsets.UTF_8)) }
                    if (session.waitForCondition(ChannelCondition.EOF, COMMAND_TIMEOUT_MS) and ChannelCondition.TIMEOUT != 0) {
                        throw IOException("Public-key registration timed out; the server file may already have been updated.")
                    }
                    session.waitForCondition(ChannelCondition.EXIT_STATUS, COMMAND_TIMEOUT_MS)
                    val output = readOutput(stdout).trim()
                    val error = readOutput(stderr).trim()
                    if (session.exitStatus != 0) throw IOException(error.ifBlank { "Server did not confirm public-key registration." })
                    return when (output.lineSequence().lastOrNull()) {
                        "ADDED" -> KeyRegistration.ADDED
                        "ALREADY_PRESENT" -> KeyRegistration.ALREADY_PRESENT
                        else -> throw IOException("Server did not confirm public-key registration.")
                    }
                }
            }
        }
    }

    private fun readOutput(input: InputStream): String {
        val buffer = ByteArray(MAX_OUTPUT_BYTES)
        var size = 0
        while (size < buffer.size) {
            val count = input.read(buffer, size, buffer.size - size)
            if (count < 0) break
            size += count
        }
        return String(buffer, 0, size, Charsets.UTF_8)
    }

    private const val COMMAND_TIMEOUT_MS = 30_000L
    private const val MAX_OUTPUT_BYTES = 4096
}
