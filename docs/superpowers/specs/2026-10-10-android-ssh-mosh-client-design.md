# Android SSH/Mosh Client Design

## Goal

Build an open-source Android terminal client from the current ConnectBot codebase. The first usable build must connect to real SSH and Mosh servers, handle Korean IME composition correctly, expose terminal special keys above the software keyboard, and support secure host and user authentication.

The working app name is **Android Shell** and its application ID is `dev.korellas.androidshell`. Source namespaces may remain aligned with upstream where changing them does not affect the application ID.

## Scope

The first usable build includes:

- SSH interactive shell sessions.
- Mosh sessions bootstrapped through the same SSH host-verification and authentication path.
- Password and keyboard-interactive authentication.
- Imported OpenSSH private keys.
- A non-exportable ECDSA P-256 SSH key generated in Android Keystore and gated by biometric or device-credential authentication.
- Explicit first-use host-key trust and persistent `known_hosts` verification.
- Korean composition input, wide-character terminal rendering, copy, paste, resize, and session persistence across configuration changes.
- A fixed-modifier, horizontally scrolling special-key bar.

The first build does not add a passkey-to-SSH-certificate backend, rewrite SSH/Mosh/terminal protocols, create a new SFTP experience, or redesign unrelated upstream screens. Existing upstream functionality may remain, but it is not part of this milestone's acceptance criteria.

## Foundation and licensing

Development starts from a pinned ConnectBot upstream commit so its integrated terminal, session lifecycle, SSH implementation, Mosh Android port, and authentication behavior stay together. The upstream base commit is recorded in Git rather than copied into prose.

The open-source build includes Mosh directly. The project will be published under GPLv3-compatible terms while preserving upstream copyright and license notices. Only the open-source product path is required for this milestone.

The project inherits the upstream Android SDK baseline and build-tool choices. It does not introduce an additional SSH library, terminal emulator, protocol parser, or dependency layer.

## Architecture

The Compose host editor, key manager, and terminal screen use the existing ConnectBot service and persistence boundaries. The terminal screen talks to a common session interface that exposes input bytes, output bytes, resize events, and connection state.

SSH and Mosh are separate transports behind that session boundary:

- SSH verifies the host, authenticates the user, requests a PTY, and opens an interactive shell.
- Mosh uses the same SSH verification and authentication path to start `mosh-server`, obtains the UDP endpoint and session secret, then transfers the interactive session to the native Mosh transport.

Both transports feed the same terminal emulator and consume the same committed input byte stream. No protocol-specific branches belong in the IME or special-key UI.

## Korean input and terminal behavior

The terminal uses full IME composition mode. Composing text stays local and is rendered at the terminal cursor as an overlay. Only committed text is encoded as UTF-8 and sent to the active session.

Backspace edits the local composing region while composition is active. After composition is committed, Backspace sends the configured terminal delete sequence. Session switching, disconnection, and IME detachment cancel stale composition without transmitting partial Jamo.

Remote output bytes are not Unicode-normalized or rewritten. The existing terminal library remains responsible for UTF-8 decoding, grapheme shaping, combining characters, East Asian cell width, cursor placement, and line wrapping.

Soft-keyboard input enters through `InputConnection`; hardware-keyboard input enters through Android key events. They converge only after composition and modifier handling.

## Special-key bar

`Ctrl` and `Alt` remain fixed at the left edge. The horizontally scrolling region contains `Esc`, `Tab`, arrow keys, `Home`, `End`, `PgUp`, `PgDn`, `Ins`, `Del`, and `F1` through `F12` in that order.

A single modifier tap latches it for the next applicable key. A double tap locks it. Tapping a locked modifier releases it. Latched and locked states are visually distinct and accessible to screen readers.

Special keys use the active terminal mode when producing escape sequences. Modifier state applies consistently to on-screen special keys, soft-keyboard commits where meaningful, and hardware-keyboard events. SSH and Mosh receive identical resulting bytes.

## Authentication and host trust

On first contact with an unknown host and port, the app shows the key algorithm and fingerprint and requires explicit confirmation before persistence. A matching saved key connects normally. A changed key blocks the connection; replacement requires an explicit host-settings action that shows both saved and presented fingerprints.

Imported OpenSSH keys use the existing upstream encrypted-key prompt and storage behavior. Key passphrases are not persisted by the new work.

The app can generate a P-256 signing key inside Android Keystore. The private key is non-exportable. The app exposes the corresponding OpenSSH public key for installation in `authorized_keys`, and signing requires biometric or device-credential approval according to platform capability. A signer adapter converts the Keystore ECDSA result to the SSH wire representation without exporting private material.

Passwords, key material, Mosh session secrets, and authentication payloads must not be written to logs.

## Connection lifecycle and errors

The existing upstream session service owns active connections so configuration changes do not tear them down. Explicit disconnect closes transport resources and clears transient authentication and composition state.

The UI distinguishes DNS/TCP failure, host-key rejection, authentication failure, missing `mosh-server`, malformed Mosh bootstrap output, and unreachable UDP transport. Errors retain enough context for the user to act but never include secrets.

## Validation

Existing upstream build and test suites remain the regression baseline. Focused tests cover composition replacement and commit, composing Backspace, modifier latch/lock transitions, special-key encoding, changed-host-key rejection, and the Android Keystore signer adapter.

Device-level acceptance uses Gboard and Samsung Keyboard with a real UTF-8 server. Korean input is exercised at a shell prompt and inside Vim and tmux, including mixed Korean/ASCII text, deletion, paste, line wrapping, session switching, and reconnect. The same terminal-input cases are exercised over SSH and Mosh.

Authentication acceptance covers password, keyboard-interactive, encrypted imported key, and Android Keystore key. Host verification covers unknown, matching, and changed keys.

## Done condition

The milestone is complete when the open-source debug build installs, the agreed SSH and Mosh authentication paths connect to real servers, Korean input behaves correctly in the acceptance environments, the selected special-key bar works for terminal applications, relevant automated checks pass, and any omitted device matrix is explicitly reported.
