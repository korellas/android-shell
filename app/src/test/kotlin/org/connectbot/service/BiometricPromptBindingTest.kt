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

package org.connectbot.service

import androidx.biometric.BiometricPrompt
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.Signature

@RunWith(RobolectricTestRunner::class)
@OptIn(ExperimentalCoroutinesApi::class)
class BiometricPromptBindingTest {
    @Test fun successWithoutRequestedSignatureIsRejected() = runTest {
        val manager = PromptManager()
        val crypto = BiometricPrompt.CryptoObject(Signature.getInstance("SHA256withECDSA"))
        val result = async { manager.requestBiometricAuth("key", "alias", crypto) }
        runCurrent()
        manager.respond(PromptResponse.BiometricResponse(true))
        assertFalse(result.await())
    }

    @Test fun sameSignatureInReturnedCryptoObjectIsAccepted() = runTest {
        val manager = PromptManager()
        val signature = Signature.getInstance("SHA256withECDSA")
        val result = async { manager.requestBiometricAuth("key", "alias", BiometricPrompt.CryptoObject(signature)) }
        runCurrent()
        manager.respond(PromptResponse.BiometricResponse(true, BiometricPrompt.CryptoObject(signature)))
        assertTrue(result.await())
    }

    @Test fun anotherSignatureCannotAuthorizeTheRequestedOperation() = runTest {
        val manager = PromptManager()
        val result = async {
            manager.requestBiometricAuth("key", "alias", BiometricPrompt.CryptoObject(Signature.getInstance("SHA256withECDSA")))
        }
        runCurrent()
        manager.respond(PromptResponse.BiometricResponse(true, BiometricPrompt.CryptoObject(Signature.getInstance("SHA256withECDSA"))))
        assertFalse(result.await())
    }

    @Test fun legacyTimeBasedPromptRemainsCompatible() = runTest {
        val manager = PromptManager()
        val result = async { manager.requestBiometricAuth("key", "alias") }
        runCurrent()
        manager.respond(PromptResponse.BiometricResponse(true))
        assertTrue(result.await())
    }
}
