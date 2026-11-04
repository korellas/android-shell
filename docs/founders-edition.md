# Founders Edition

Founders Edition is an Android in-app, non-consumable purchase that removes the
settings banners. The app remains free to download. Purchase status comes from
Google Play; the app does not consume the product.

## Play Console setup

Create a one-time product with the ID owned by
`FoundersEditionBilling.PRODUCT_ID`. Configure a buy purchase option, availability,
and pricing in Play Console. The app displays the formatted price returned by
Google Play rather than calculating or hardcoding a local price.

Supply the app's Base64-encoded Google Play licensing public key through the
Gradle property `playBillingPublicKey`. This is the public key used to verify
purchase signatures, not the APK signing key. Without a usable verification key,
the purchase action stays unavailable.

Use a license tester for an end-to-end purchase, cancellation, pending payment,
and restoration check. The package must match the app configured in Play Console.
See [Google's billing test guide](https://developer.android.com/google/play/billing/test).
Unit tests and a purchase screen preview do not validate the live store setup.

## Ownership

`FoundersReceiptStore` verifies the Google signature, package, product, and
purchased state. `FoundersEditionBilling` acknowledges a verified purchase before
persisting delivery. Pending, cancelled, suspended, or invalid purchases do not
grant ownership.

Verified receipts are cached in app-private preferences and reverified when read.
A successful Google Play ownership refresh removes a missing entitlement. A
failed refresh retains a valid cached receipt so an offline buyer keeps access.
This integration verifies receipts on the device; it does not provide a billing
backend or real-time refund notifications. See Google's
[billing security recommendations](https://developer.android.com/google/play/billing/security).
