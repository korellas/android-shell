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

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.connectbot.BuildConfig
import org.connectbot.di.CoroutineDispatchers
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@Singleton
class FoundersEditionBilling internal constructor(
    private val receipts: FoundersReceiptStore,
    private val dispatchers: CoroutineDispatchers,
    builder: BillingClient.Builder,
) : PurchasesUpdatedListener {
    @Inject
    constructor(
        @ApplicationContext context: Context,
        preferences: SharedPreferences,
        dispatchers: CoroutineDispatchers,
        builder: BillingClient.Builder,
    ) : this(FoundersReceiptStore(preferences, BuildConfig.PLAY_BILLING_PUBLIC_KEY, context.packageName), dispatchers, builder)

    data class State(
        val owned: Boolean = false,
        val checking: Boolean = true,
        val ready: Boolean = false,
        val pending: Boolean = false,
        val price: String? = null,
        val error: String? = null,
    ) {
        fun toWire(): Map<String, Any?> = mapOf(
            "owned" to owned,
            "checking" to checking,
            "ready" to ready,
            "pending" to pending,
            "price" to price,
            "error" to error,
        )
    }

    private val scope = CoroutineScope(SupervisorJob() + dispatchers.main)
    private val operations = Mutex()
    private val _state = MutableStateFlow(State())
    val state = _state.asStateFlow()
    private var product: ProductDetails? = null
    private val client = builder.setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection().build()

    suspend fun refresh() = withContext(dispatchers.main) {
        operations.withLock {
            product = null
            _state.update { it.copy(checking = true, ready = false, price = null, error = null) }
            try {
                val cached = withContext(dispatchers.io) { receipts.load() }
                _state.update { it.copy(owned = cached != null) }
                if (!withContext(dispatchers.io) { receipts.configured }) return@withLock
                connect()
                val purchases = queryPurchases()
                val purchased = purchases.firstOrNull {
                    PRODUCT_ID in it.products && it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isSuspended
                }
                if (purchased == null) {
                    withContext(dispatchers.io) { receipts.clear() }
                    _state.update {
                        it.copy(owned = false, pending = purchases.any { purchase -> PRODUCT_ID in purchase.products && purchase.purchaseState == Purchase.PurchaseState.PENDING })
                    }
                } else {
                    acceptPurchase(purchased)
                }
                product = queryProduct()
                val offer = product?.oneTimePurchaseOfferDetailsList?.firstOrNull()
                _state.update { it.copy(ready = offer != null && it.error == null, price = offer?.formattedPrice) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                _state.update { it.copy(ready = false, error = "billing_unavailable") }
            } finally {
                _state.update { it.copy(checking = false) }
            }
        }
    }

    suspend fun purchase(activity: Activity) = withContext(dispatchers.main) {
        operations.withLock {
            val details = product ?: return@withLock
            val offer = details.oneTimePurchaseOfferDetailsList?.firstOrNull() ?: return@withLock
            val current = state.value
            if (!current.ready || current.checking || current.pending || current.owned) return@withLock
            _state.update { it.copy(pending = true, error = null) }
            val result = client.launchBillingFlow(
                activity,
                BillingFlowParams.newBuilder().setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
                            .apply { offer.offerToken?.let { setOfferToken(it) } }.build(),
                    ),
                ).build(),
            )
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                _state.update {
                    it.copy(pending = false, error = if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) null else "purchase_failed")
                }
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        scope.launch {
            if (result.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                refresh()
                return@launch
            }
            operations.withLock {
                when (result.responseCode) {
                    BillingClient.BillingResponseCode.OK -> {
                        val matching = purchases.orEmpty().filter { PRODUCT_ID in it.products }
                        _state.update { it.copy(pending = matching.any { purchase -> purchase.purchaseState == Purchase.PurchaseState.PENDING }, error = null) }
                        try {
                            matching.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.forEach { acceptPurchase(it) }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (_: Exception) {
                            _state.update { it.copy(pending = false, error = "purchase_failed") }
                        }
                    }

                    BillingClient.BillingResponseCode.USER_CANCELED -> _state.update { it.copy(pending = false, error = null) }

                    else -> _state.update { it.copy(pending = false, error = "purchase_failed") }
                }
            }
        }
    }

    private suspend fun acceptPurchase(purchase: Purchase) {
        if (!withContext(dispatchers.io) { receipts.isValid(purchase) }) {
            _state.update { it.copy(pending = false, ready = false, error = "verification_failed") }
            return
        }
        val alreadyDelivered = withContext(dispatchers.io) { receipts.load()?.purchaseToken == purchase.purchaseToken }
        if (!purchase.isAcknowledged && !alreadyDelivered) {
            val result = suspendCancellableCoroutine { continuation ->
                client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) {
                    if (continuation.isActive) continuation.resume(it)
                }
            }
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                _state.update { it.copy(pending = false, ready = false, error = "acknowledgement_failed") }
                return
            }
        }
        withContext(dispatchers.io) { receipts.save(purchase) }
        _state.update { it.copy(owned = true, pending = false, error = null) }
    }

    private suspend fun connect() {
        if (client.isReady) return
        suspendCancellableCoroutine { continuation ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (!continuation.isActive) return
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                        continuation.resume(Unit)
                    } else {
                        continuation.resumeWithException(IllegalStateException("billing_unavailable"))
                    }
                }

                override fun onBillingServiceDisconnected() {
                    _state.update { it.copy(ready = false) }
                    if (continuation.isActive) continuation.resumeWithException(IllegalStateException("billing_unavailable"))
                }
            })
        }
    }

    private suspend fun queryPurchases(): List<Purchase> = suspendCancellableCoroutine { continuation ->
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { result, purchases ->
            if (continuation.isActive) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    continuation.resume(purchases)
                } else {
                    continuation.resumeWithException(IllegalStateException("billing_unavailable"))
                }
            }
        }
    }

    private suspend fun queryProduct(): ProductDetails? = suspendCancellableCoroutine { continuation ->
        val params = QueryProductDetailsParams.newBuilder().setProductList(
            listOf(QueryProductDetailsParams.Product.newBuilder().setProductId(PRODUCT_ID).setProductType(BillingClient.ProductType.INAPP).build()),
        ).build()
        client.queryProductDetailsAsync(params) { result, details ->
            if (continuation.isActive) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    continuation.resume(details.productDetailsList.firstOrNull { it.productId == PRODUCT_ID })
                } else {
                    continuation.resumeWithException(IllegalStateException("billing_unavailable"))
                }
            }
        }
    }

    companion object {
        const val PRODUCT_ID = "founders_edition"
    }
}
