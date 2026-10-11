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

import android.annotation.SuppressLint
import com.trilead.ssh2.ChannelCondition
import com.trilead.ssh2.Connection
import com.trilead.ssh2.Session
import com.trilead.ssh2.crypto.PublicKeyUtils
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyLong
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermissions
import java.security.KeyPairGenerator

// POSIX file operations run on the desktop JVM, not the Android device.
@SuppressLint("NewApi")
class SshKeyEnrollmentTest {
    @get:Rule val temporary = TemporaryFolder()
    private val key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey android-shell"

    @Test fun usesDedicatedExecChannelAndSendsOnlyPublicKeyOnStdin() {
        val connection = mock(Connection::class.java)
        val session = mock(Session::class.java)
        val input = ByteArrayOutputStream()
        `when`(connection.openSession()).thenReturn(session)
        `when`(session.stdout).thenReturn(ByteArrayInputStream("ADDED\n".toByteArray()))
        `when`(session.stderr).thenReturn(ByteArrayInputStream(byteArrayOf()))
        `when`(session.stdin).thenReturn(input)
        `when`(session.waitForCondition(anyInt(), anyLong())).thenReturn(ChannelCondition.EOF or ChannelCondition.EXIT_STATUS)
        `when`(session.exitStatus).thenReturn(0)
        val publicKey = KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair().public
        assertEquals(KeyRegistration.ADDED, SshKeyEnrollment.install(connection, publicKey))
        assertEquals(PublicKeyUtils.toAuthorizedKeysFormat(publicKey, "android-shell") + "\n", input.toString("UTF-8"))
        val command = ArgumentCaptor.forClass(String::class.java)
        verify(session).execCommand(command.capture())
        assertEquals(0, ProcessBuilder("sh", "-n", "-c", command.value).start().waitFor())
        verify(session, never()).startShell()
        verify(session).close()
        verify(connection, never()).close()
    }

    private fun install(home: File, publicKey: String = key, extraPrelude: String = ""): Pair<Int, String> {
        // Isolate the remote user's home without changing the machine's HOME.
        val command = "cd() { command cd '${home.path}'; }\n" + extraPrelude + SshKeyEnrollment.installScript
        val input = temporary.newFile().apply { writeText(publicKey + "\n") }
        val process = ProcessBuilder("sh", "-c", command).redirectInput(input).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().readText()
        return process.waitFor() to output
    }

    @Test fun addsKeyWithoutReplacingExistingKeysAndAddsMissingNewline() {
        val home = temporary.newFolder()
        val directory = File(home, ".ssh").apply { mkdir() }
        val file = File(directory, "authorized_keys").apply { writeText("ssh-rsa ExistingKey old") }
        assertEquals(0, install(home).first)
        assertEquals("ssh-rsa ExistingKey old\n$key\n", file.readText())
        assertEquals(PosixFilePermissions.fromString("rwx------"), Files.getPosixFilePermissions(directory.toPath()))
        assertEquals(PosixFilePermissions.fromString("rw-------"), Files.getPosixFilePermissions(file.toPath()))
    }

    @Test fun repeatedRegistrationDoesNotDuplicateKey() {
        val home = temporary.newFolder()
        assertEquals(0, install(home).first)
        val result = install(home)
        assertEquals(0, result.first)
        assertTrue(result.second.contains("ALREADY_PRESENT"))
        assertEquals("$key\n", File(home, ".ssh/authorized_keys").readText())
    }

    @Test fun existingRestrictedKeyIsPreservedDespiteDifferentComment() {
        val home = temporary.newFolder()
        File(home, ".ssh").mkdir()
        val restricted = "from=\"192.0.2.1\",no-port-forwarding ${key.substringBeforeLast(' ')} different-comment\n"
        val file = File(home, ".ssh/authorized_keys").apply { writeText(restricted) }
        val result = install(home)
        assertEquals(0, result.first)
        assertTrue(result.second.contains("ALREADY_PRESENT"))
        assertEquals(restricted, file.readText())
    }

    @Test fun refusesSymlinkWithoutModifyingItsTarget() {
        val home = temporary.newFolder()
        File(home, ".ssh").mkdir()
        val target = temporary.newFile().apply { writeText("do not touch") }
        Files.createSymbolicLink(File(home, ".ssh/authorized_keys").toPath(), target.toPath())
        assertTrue(install(home).first != 0)
        assertEquals("do not touch", target.readText())
    }

    @Test fun commentsAreDataAndCannotExecuteCommands() {
        val home = temporary.newFolder()
        val publicKey = "$key ; touch injected"
        assertEquals(0, install(home, publicKey).first)
        assertEquals("$publicKey\n", File(home, ".ssh/authorized_keys").readText())
        assertFalse(File(home, "injected").exists())
    }

    @Test fun duplicateCheckFailureDoesNotAppendUnrestrictedKey() {
        val home = temporary.newFolder()
        File(home, ".ssh").mkdir()
        val file = File(home, ".ssh/authorized_keys").apply { writeText("existing\n") }
        assertTrue(install(home, extraPrelude = "awk() { return 2; }\n").first != 0)
        assertEquals("existing\n", file.readText())
    }

    @Test fun directoryAtAuthorizedKeysPathIsNotModified() {
        val home = temporary.newFolder()
        val path = File(home, ".ssh/authorized_keys").apply { mkdirs() }
        Files.setPosixFilePermissions(path.toPath(), PosixFilePermissions.fromString("rwxr-xr-x"))
        assertTrue(install(home).first != 0)
        assertEquals(PosixFilePermissions.fromString("rwxr-xr-x"), Files.getPosixFilePermissions(path.toPath()))
    }
}
