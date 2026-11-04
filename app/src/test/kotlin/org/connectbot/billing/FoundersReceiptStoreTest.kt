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

package org.connectbot.billing

import android.content.Context
import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import com.android.billingclient.api.Purchase
import org.json.JSONObject
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.security.KeyPairGenerator
import java.security.Signature

@RunWith(RobolectricTestRunner::class)
class FoundersReceiptStoreTest {
    private val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private val publicKey = Base64.encodeToString(pair.public.encoded, Base64.NO_WRAP)
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val preferences = context.getSharedPreferences("founders-test", Context.MODE_PRIVATE)
    private lateinit var receipts: FoundersReceiptStore

    @Before
    fun setUp() {
        preferences.edit().clear().commit()
        receipts = FoundersReceiptStore(preferences, publicKey, "test.tilde")
    }

    private fun purchase(
        product: String = FoundersEditionBilling.PRODUCT_ID,
        packageName: String = "test.tilde",
        purchaseState: Int = 0,
    ): Purchase {
        val json = JSONObject().put("productId", product).put("packageName", packageName)
            .put("purchaseState", purchaseState).put("purchaseToken", "test-token").toString()
        val signature = Signature.getInstance("SHA1withRSA").apply {
            initSign(pair.private)
            update(json.toByteArray(Charsets.UTF_8))
        }.sign()
        return Purchase(json, Base64.encodeToString(signature, Base64.NO_WRAP))
    }

    @Test
    fun verifiedPurchaseSurvivesRestartAndCanBeCleared() {
        val purchase = purchase()
        assertTrue(receipts.isValid(purchase))
        receipts.save(purchase)
        assertTrue(FoundersReceiptStore(preferences, publicKey, "test.tilde").load() != null)
        receipts.clear()
        assertNull(receipts.load())
    }

    @Test
    fun invalidSignatureNeverGrantsOwnership() {
        val original = purchase()
        val tampered = Purchase(original.originalJson.replace("test-token", "altered"), original.signature)
        assertFalse(receipts.isValid(tampered))
        assertFalse(receipts.isValid(Purchase(original.originalJson, "invalid")))
        assertFalse(FoundersReceiptStore(preferences, "", "test.tilde").isValid(original))
    }

    @Test
    fun differentProductOrPackageAndPendingPaymentNeverGrantOwnership() {
        assertFalse(receipts.isValid(purchase(product = "another_product")))
        assertFalse(receipts.isValid(purchase(packageName = "another.app")))
        assertFalse(receipts.isValid(purchase(purchaseState = 4)))
    }

    @Test
    fun cachedReceiptIsReverifiedWithTheConfiguredKey() {
        receipts.save(purchase())
        val other = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val otherKey = Base64.encodeToString(other.public.encoded, Base64.NO_WRAP)
        assertNull(FoundersReceiptStore(preferences, otherKey, "test.tilde").load())
    }
}
