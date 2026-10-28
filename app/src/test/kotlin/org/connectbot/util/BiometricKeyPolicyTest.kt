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

import android.security.keystore.KeyGenParameterSpec
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.anyString
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.security.KeyPairGenerator
import java.security.spec.AlgorithmParameterSpec

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BiometricKeyPolicyTest {
    @Test fun newlyGeneratedKeyRequiresBiometricForEveryOperation() {
        val pair = KeyPairGenerator.getInstance("EC").generateKeyPair()
        val generator = mock(KeyPairGenerator::class.java)
        `when`(generator.generateKeyPair()).thenReturn(pair)
        mockStatic(KeyPairGenerator::class.java).use { factory ->
            factory.`when`<KeyPairGenerator> { KeyPairGenerator.getInstance(anyString(), anyString()) }.thenReturn(generator)
            BiometricKeyManagerImpl(ApplicationProvider.getApplicationContext()).generateEcKey("test-alias")
        }
        val spec = ArgumentCaptor.forClass(AlgorithmParameterSpec::class.java)
        verify(generator).initialize(spec.capture())
        val parameters = spec.value as KeyGenParameterSpec
        assertTrue(parameters.isUserAuthenticationRequired)
        assertEquals(0, parameters.userAuthenticationValidityDurationSeconds)
    }
}
