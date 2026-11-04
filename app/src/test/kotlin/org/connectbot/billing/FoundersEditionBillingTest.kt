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
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.AcknowledgePurchaseResponseListener
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetailsResponseListener
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesResponseListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryProductDetailsResult
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.connectbot.di.CoroutineDispatchers
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import java.security.KeyPairGenerator
import java.security.Signature

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class FoundersEditionBillingTest {
    private val dispatcher = StandardTestDispatcher()
    private val dispatchers = CoroutineDispatchers(dispatcher, dispatcher, dispatcher)
    private val client = Mockito.mock(BillingClient::class.java)
    private val builder = Mockito.mock(BillingClient.Builder::class.java, Mockito.RETURNS_SELF)
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val preferences = context.getSharedPreferences("founders-flow-test", Context.MODE_PRIVATE)
    private val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private val publicKey = Base64.encodeToString(pair.public.encoded, Base64.NO_WRAP)
    private lateinit var receipts: FoundersReceiptStore
    private lateinit var billing: FoundersEditionBilling
    private var purchases = emptyList<Purchase>()
    private var queryResult = result(BillingClient.BillingResponseCode.OK)
    private var acknowledgement: AcknowledgePurchaseResponseListener? = null

    private fun result(code: Int) = BillingResult.newBuilder().setResponseCode(code).build()

    @Before
    fun setUp() {
        preferences.edit().clear().commit()
        receipts = FoundersReceiptStore(preferences, publicKey, "test.tilde")
        Mockito.`when`(builder.build()).thenReturn(client)
        Mockito.`when`(client.isReady).thenReturn(true)
        Mockito.doAnswer { invocation ->
            invocation.getArgument<PurchasesResponseListener>(1).onQueryPurchasesResponse(queryResult, purchases)
            null
        }.`when`(client).queryPurchasesAsync(Mockito.any(QueryPurchasesParams::class.java), Mockito.any(PurchasesResponseListener::class.java))
        Mockito.doAnswer { invocation ->
            invocation.getArgument<ProductDetailsResponseListener>(1).onProductDetailsResponse(
                result(BillingClient.BillingResponseCode.OK),
                QueryProductDetailsResult.create(emptyList(), emptyList()),
            )
            null
        }.`when`(client).queryProductDetailsAsync(Mockito.any(QueryProductDetailsParams::class.java), Mockito.any(ProductDetailsResponseListener::class.java))
        Mockito.doAnswer { invocation ->
            acknowledgement = invocation.getArgument(1)
            null
        }.`when`(client).acknowledgePurchase(Mockito.any(AcknowledgePurchaseParams::class.java), Mockito.any(AcknowledgePurchaseResponseListener::class.java))
        billing = FoundersEditionBilling(receipts, dispatchers, builder)
    }

    private fun purchase(state: Int = 0, suspended: Boolean = false): Purchase {
        val json = JSONObject().put("productId", FoundersEditionBilling.PRODUCT_ID).put("packageName", "test.tilde")
            .put("purchaseState", state).put("purchaseToken", "test-token").put("acknowledged", false).put("suspended", suspended).toString()
        val signature = Signature.getInstance("SHA1withRSA").apply {
            initSign(pair.private)
            update(json.toByteArray(Charsets.UTF_8))
        }.sign()
        return Purchase(json, Base64.encodeToString(signature, Base64.NO_WRAP))
    }

    @Test
    fun confirmedPurchaseGrantsAdsRemovalOnlyAfterAcknowledgement() = runTest(dispatcher) {
        billing.refresh()
        billing.onPurchasesUpdated(result(BillingClient.BillingResponseCode.OK), mutableListOf(purchase()))
        advanceUntilIdle()
        assertNotNull(acknowledgement)
        assertFalse(billing.state.value.owned)
        assertNull(receipts.load())
        acknowledgement!!.onAcknowledgePurchaseResponse(result(BillingClient.BillingResponseCode.OK))
        advanceUntilIdle()
        assertTrue(billing.state.value.owned)
        assertNotNull(receipts.load())
    }

    @Test
    fun pendingAndCancelledPurchasesDoNotGrantAdsRemoval() = runTest(dispatcher) {
        billing.refresh()
        billing.onPurchasesUpdated(result(BillingClient.BillingResponseCode.OK), mutableListOf(purchase(state = 4)))
        advanceUntilIdle()
        assertTrue(billing.state.value.pending)
        assertFalse(billing.state.value.owned)
        assertNull(acknowledgement)
        billing.onPurchasesUpdated(result(BillingClient.BillingResponseCode.USER_CANCELED), null)
        advanceUntilIdle()
        assertFalse(billing.state.value.pending)
        assertFalse(billing.state.value.owned)
    }

    @Test
    fun failedAcknowledgementDoesNotPersistEntitlement() = runTest(dispatcher) {
        billing.refresh()
        billing.onPurchasesUpdated(result(BillingClient.BillingResponseCode.OK), mutableListOf(purchase()))
        advanceUntilIdle()
        acknowledgement!!.onAcknowledgePurchaseResponse(result(BillingClient.BillingResponseCode.ERROR))
        advanceUntilIdle()
        assertFalse(billing.state.value.owned)
        assertNull(receipts.load())
        assertEquals("acknowledgement_failed", billing.state.value.error)
    }

    @Test
    fun successfulOwnershipRefreshRevokesMissingPurchaseWhileOfflineKeepsVerifiedReceipt() = runTest(dispatcher) {
        receipts.save(purchase())
        queryResult = result(BillingClient.BillingResponseCode.NETWORK_ERROR)
        billing.refresh()
        assertTrue(billing.state.value.owned)
        queryResult = result(BillingClient.BillingResponseCode.OK)
        billing.refresh()
        assertFalse(billing.state.value.owned)
        assertNull(receipts.load())
    }

    @Test
    fun forgedPurchaseDoesNotReachAcknowledgement() = runTest(dispatcher) {
        billing.refresh()
        val original = purchase()
        billing.onPurchasesUpdated(result(BillingClient.BillingResponseCode.OK), mutableListOf(Purchase(original.originalJson, "invalid")))
        advanceUntilIdle()
        assertFalse(billing.state.value.owned)
        assertNull(acknowledgement)
        assertEquals("verification_failed", billing.state.value.error)
    }

    @Test
    fun suspendedOwnershipIsRemovedOnRefresh() = runTest(dispatcher) {
        receipts.save(purchase())
        purchases = listOf(purchase(suspended = true))
        billing.refresh()
        assertFalse(billing.state.value.owned)
        assertNull(receipts.load())
        assertNull(acknowledgement)
    }
}
