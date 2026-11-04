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

import android.content.SharedPreferences
import android.util.Base64
import com.android.billingclient.api.Purchase
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

internal class FoundersReceiptStore(
    private val preferences: SharedPreferences,
    private val publicKey: String,
    private val packageName: String,
) {
    private val key by lazy {
        runCatching {
            KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.decode(publicKey, Base64.DEFAULT)))
        }.getOrNull()
    }
    val configured: Boolean get() = key != null

    fun isValid(purchase: Purchase): Boolean = runCatching {
        purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isSuspended &&
            purchase.packageName == packageName &&
            purchase.products == listOf(FoundersEditionBilling.PRODUCT_ID) &&
            purchase.purchaseToken.isNotBlank() &&
            key?.let { publicKey ->
                Signature.getInstance("SHA1withRSA").run {
                    initVerify(publicKey)
                    update(purchase.originalJson.toByteArray(Charsets.UTF_8))
                    verify(Base64.decode(purchase.signature, Base64.DEFAULT))
                }
            } == true
    }.getOrDefault(false)

    fun save(purchase: Purchase) {
        require(isValid(purchase))
        check(preferences.edit().putString(RECEIPT, purchase.originalJson).putString(SIGNATURE, purchase.signature).commit())
    }

    fun clear() {
        check(preferences.edit().remove(RECEIPT).remove(SIGNATURE).commit())
    }

    fun load(): Purchase? = runCatching {
        val json = preferences.getString(RECEIPT, null) ?: return null
        val signature = preferences.getString(SIGNATURE, null) ?: return null
        Purchase(json, signature).takeIf(::isValid)
    }.getOrNull()

    private companion object {
        const val RECEIPT = "founders.verifiedReceipt"
        const val SIGNATURE = "founders.verifiedSignature"
    }
}
