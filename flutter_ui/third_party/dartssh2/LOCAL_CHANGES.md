# App-local dartssh2 copy

Source: [vicajilau/dartssh2](https://github.com/vicajilau/dartssh2) at `20b39cc5b08cdecb9c466743059f5e8446b80c9a` (4.1.0). The upstream MIT license is preserved in `LICENSE`.

This copy lets the app preserve its SSH compression setting without publishing the compression patch upstream. Compression defaults to off and uses the Dart VM SDK zlib implementation. Authentication-policy changes are taken from commit `5e39f0be2cbfb3b866962c028e0545acf8c54667`, submitted separately in [upstream PR #251](https://github.com/vicajilau/dartssh2/pull/251).

The app-local `onIdentitiesRequest` callback defers key unlock and confirmation until the verified server permits public-key authentication. It is separate from the submitted upstream change.

Encrypted SEC1 EC PEM keys reuse the existing RSA PEM decryption helper before SEC1 parsing; no additional cipher implementation is introduced.

Update this copy by comparing against the pinned upstream source and running its tests plus the app OpenSSH validation before switching versions.
