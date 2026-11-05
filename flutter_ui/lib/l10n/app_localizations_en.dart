// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get terminal => 'Terminal';

  @override
  String files(String arg0) {
    return '$arg0 · Files';
  }

  @override
  String get newHost => 'New host';

  @override
  String edit(String arg0) {
    return 'Edit $arg0';
  }

  @override
  String get disconnectAndCloseTab => 'Disconnect and close tab';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return 'Disconnect from $arg0 and close this tab?';
  }

  @override
  String get disconnectAndClose => 'Disconnect and close';

  @override
  String get newTerminal => 'New terminal';

  @override
  String get fileTransfer => 'File transfer';

  @override
  String get edit2 => 'Edit';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get portForwarding => 'Port forwarding';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get delete => 'Delete';

  @override
  String get nameForDuplicateHost => 'Name for duplicate host';

  @override
  String copy(String arg0) {
    return '$arg0 copy';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return 'Disconnect all sessions for $arg0?';
  }

  @override
  String get searchHosts => 'Search hosts';

  @override
  String get searchHostsOrEnterSshAddressCtrlK =>
      'Search hosts or enter SSH address (Ctrl K)';

  @override
  String get addHost => 'Add host';

  @override
  String get noHostsYet => 'No hosts yet';

  @override
  String get openTerminals => 'Open terminals';

  @override
  String get openFiles => 'Open files';

  @override
  String menu(String arg0) {
    return '$arg0 menu';
  }

  @override
  String get settings => 'Settings';

  @override
  String get helpAndLogs => 'Help and logs';

  @override
  String get hostListCtrlB => 'Host list (Ctrl B)';

  @override
  String closeTab(String arg0) {
    return 'Close $arg0 tab';
  }

  @override
  String get newTabCtrlShiftT => 'New tab (Ctrl Shift T)';

  @override
  String get terminalMenu => 'Terminal menu';

  @override
  String get importSshKey => 'Import SSH key';

  @override
  String get openSessions => 'Open sessions';

  @override
  String session(String arg0) {
    return 'Session $arg0';
  }

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get open => 'Open';

  @override
  String get connect => 'Connect';

  @override
  String get address => 'Address';

  @override
  String get authentication => 'Authentication';

  @override
  String get tryAllAvailableKeys => 'Try all available keys';

  @override
  String get useServerSettings => 'Use server settings';

  @override
  String get terminalProfile => 'Terminal profile';

  @override
  String get appDefaultProfile => 'App default profile';

  @override
  String get manage => 'Manage';

  @override
  String get minimize => 'Minimize';

  @override
  String get restore => 'Restore';

  @override
  String get maximize => 'Maximize';

  @override
  String get closeWindow => 'Close window';

  @override
  String get host => 'Host';

  @override
  String get profile => 'Profile';

  @override
  String get sharedLoginAccount => 'Shared login account';

  @override
  String get sshKeys => 'SSH keys';

  @override
  String enter(String arg0) {
    return 'Enter $arg0.';
  }

  @override
  String get enterAWholeNumber => 'Enter a whole number.';

  @override
  String get checkThePortRange => 'Check the port range.';

  @override
  String currentValue(String arg0) {
    return '$arg0 (current value)';
  }

  @override
  String get select => 'Select';

  @override
  String get defaultValue => 'Default';

  @override
  String get dsaUnsupported => ' (DSA unsupported)';

  @override
  String get windowsDefaultKeysAndAddedKeys =>
      'Windows default keys and added keys';

  @override
  String get noKey => 'No key';

  @override
  String get passwordSaved => 'Password (saved)';

  @override
  String get password => 'Password';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      'Stored encrypted on this device. Enter it again after restoring to another device.';

  @override
  String get storedEncryptedOnThisDevice => 'Stored encrypted on this device.';

  @override
  String get deleteSavedPassword => 'Delete saved password';

  @override
  String get accountName => 'Account name';

  @override
  String get username => 'Username';

  @override
  String appliesToHosts(String arg0) {
    return 'Applies to $arg0 hosts';
  }

  @override
  String get display => 'Display';

  @override
  String get profileName => 'Profile name';

  @override
  String get colorTheme => 'Color theme';

  @override
  String get terminalFont => 'Terminal font';

  @override
  String get appDefault => 'App default';

  @override
  String get fontSize => 'Font size';

  @override
  String get characterEncoding => 'Character encoding';

  @override
  String get deleteKey => 'Delete key';

  @override
  String get columnsAutomatic => 'Columns · automatic';

  @override
  String get rowsAutomatic => 'Rows · automatic';

  @override
  String get forwarding => 'Forwarding';

  @override
  String get forwardingName => 'Forwarding name';

  @override
  String get type => 'Type';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remote';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      'Forward connections from a server port to an address on this device.';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      'Forward connections from a device port to an address on the server side.';

  @override
  String get openASocks5ProxyOnThisDevice =>
      'Open a SOCKS5 proxy on this device.';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      'SOCKS4 is unsupported. Change the type to SOCKS5 to use it.';

  @override
  String get listenAddressOnServer => 'Listen address on server';

  @override
  String get listenAddressOnThisDevice => 'Listen address on this device';

  @override
  String get text127001AccessibleOnlyOnThisDevice =>
      '127.0.0.1 · accessible only on this device';

  @override
  String get port => 'Port';

  @override
  String get destinationAddress => 'Destination address';

  @override
  String get publicKey => 'Public key';

  @override
  String get copyFingerprint => 'Copy fingerprint';

  @override
  String get copyPublicKey => 'Copy public key';

  @override
  String get keySettings => 'Key settings';

  @override
  String get keyName => 'Key name';

  @override
  String get confirmBeforeUse => 'Confirm before use';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      'Ask for permission before authenticating with this key';

  @override
  String get importedPrivateKey => 'Imported private key';

  @override
  String get androidKeystoreP256Key => 'Android Keystore P-256 key';

  @override
  String get authenticateWithAnImportedPrivateKeyFile =>
      'Authenticate with an imported private key file';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice =>
      'The private key cannot be exported from this device';

  @override
  String get disabledLegacyPrivateKey => 'Disabled legacy private key';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      'Replace it with a new Android Keystore key before deleting it.';

  @override
  String get connectionType => 'Connection type';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return '$arg0 connections are unsupported. Change to SSH or local.';
  }

  @override
  String get hostName => 'Host name';

  @override
  String get name => 'Name';

  @override
  String get serverAddress => 'Server address';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      'Paste user@host:port into the address field to fill in the details.';

  @override
  String get advanced => 'Advanced';

  @override
  String get ipAddress => 'IP address';

  @override
  String get automatic => 'Automatic';

  @override
  String get jumpHost => 'Jump host';

  @override
  String get directConnection => 'Direct connection';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      'This connection type does not use SSH authentication settings.';

  @override
  String get account => 'Account';

  @override
  String get doNotUse => 'Do not use';

  @override
  String usingAccount(String arg0) {
    return 'Using account $arg0';
  }

  @override
  String get loginKey => 'Login key';

  @override
  String get registerKeyOnThisServer => 'Register key on this server';

  @override
  String get logInOnceWithAPasswordToInstallThe =>
      'Log in once with a password to install the public key';

  @override
  String get hostColor => 'Host color';

  @override
  String get previewInTheHomeListTabsAndNotifications =>
      'Preview in the home list, tabs, and notifications';

  @override
  String get customHostColor => 'Custom host color';

  @override
  String appDefault2(String arg0) {
    return 'App default · $arg0';
  }

  @override
  String get manageProfiles => 'Manage profiles';

  @override
  String get keepConnectionAlive => 'Keep connection alive';

  @override
  String get reconnectAutomaticallyAfterAnIOError =>
      'Reconnect automatically after an I/O error';

  @override
  String get closeWithoutAsking => 'Close without asking';

  @override
  String get closeTheTabImmediatelyAfterExit =>
      'Close the tab immediately after exit';

  @override
  String get sshCompression => 'SSH compression';

  @override
  String get enableOnlyOnSlowConnections => 'Enable only on slow connections';

  @override
  String get openTerminal => 'Open terminal';

  @override
  String get whenOffOnlyPortForwardingIsEnabled =>
      'When off, only port forwarding is enabled';

  @override
  String get overrideForThisHost => 'Override for this host';

  @override
  String get scrollback => 'Scrollback';

  @override
  String linesDefault(String arg0) {
    return 'Lines · default $arg0';
  }

  @override
  String get useCtrlAltAsMeta => 'Use Ctrl+Alt as Meta';

  @override
  String get displayAndProfile => 'Display and profile';

  @override
  String get session2 => 'Session';

  @override
  String get editHost => 'Edit host';

  @override
  String get localShell => 'Local shell';

  @override
  String get selectKey => 'Select key';

  @override
  String get connectionSettings => 'Connection settings';

  @override
  String get trustedServerKeys => 'Trusted server keys';

  @override
  String get nameForDuplicate => 'Name for duplicate';

  @override
  String get couldNotSave => 'Could not save';

  @override
  String get details => 'Details';

  @override
  String get changedFields => 'Changed fields';

  @override
  String get changePassword => 'Change password';

  @override
  String get none => 'None';

  @override
  String get saving => 'Saving';

  @override
  String changed(String arg0) {
    return 'Changed $arg0';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0 and others';
  }

  @override
  String items(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'Saved';

  @override
  String get undo => 'Undo';

  @override
  String get save => 'Save';

  @override
  String get saveAndOpenNewTerminal => 'Save and open new terminal';

  @override
  String get deleteHost => 'Delete host';

  @override
  String get couldNotSaveChanges => 'Could not save changes';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get saving2 => 'Saving…';

  @override
  String get apply => 'Apply';

  @override
  String get back => 'Back';

  @override
  String get systemDefault => 'System default';

  @override
  String get appDefaultFont => 'App default font';

  @override
  String get newSshKey => 'New SSH key';

  @override
  String get enterAName => 'Enter a name.';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      'Create a P-256 private key in Android Keystore and require biometric authentication for each signature. The private key cannot be copied, exported, or backed up.';

  @override
  String get couldNotCreateKey => 'Could not create key';

  @override
  String get createKey => 'Create key';

  @override
  String get search => 'Search';

  @override
  String get saving3 => 'Saving';

  @override
  String changes(String arg0) {
    return '$arg0 changes';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return 'Enter a value between $arg0 and $arg1';
  }

  @override
  String decrease(String arg0) {
    return 'Decrease $arg0';
  }

  @override
  String increase(String arg0) {
    return 'Increase $arg0';
  }

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get unsavedChangesWillBeLost => 'Unsaved changes will be lost.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get selectColor => 'Select color';

  @override
  String get brightness => 'Brightness';

  @override
  String get hexColor => 'Hex color';

  @override
  String get enterASixDigitColor => 'Enter a six-digit color';

  @override
  String get menu2 => 'Menu';

  @override
  String get defaultProfile => 'Default profile';

  @override
  String get theSavedConnectionSettingsAreInvalid =>
      'The saved connection settings are invalid.';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return 'The saved $arg0 settings are invalid.';
  }

  @override
  String get theSavedColorThemeIsInvalid => 'The saved color theme is invalid.';

  @override
  String get checkTheSshAddress => 'Check the SSH address.';

  @override
  String get useAnSshHost => 'Use an SSH host.';

  @override
  String get thisTerminalUsesUtf8 => 'This terminal uses UTF-8.';

  @override
  String get colorThemeNotFound => 'Color theme not found.';

  @override
  String get enterAThemeName => 'Enter a theme name.';

  @override
  String get aThemeWithThisNameAlreadyExists =>
      'A theme with this name already exists.';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues =>
      'Colors must be three- or six-digit hex values.';

  @override
  String get invalidColorThemeFileFormat => 'Invalid color theme file format.';

  @override
  String get defaultColorIndicesMustBeBetween0And15 =>
      'Default color indices must be between 0 and 15.';

  @override
  String get ansiColorIndicesMustBeBetween0And15 =>
      'ANSI color indices must be between 0 and 15.';

  @override
  String get invalidThemeDescriptionFormat =>
      'Invalid theme description format.';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt =>
      'Duplicate the default theme before editing it.';

  @override
  String get checkTheColorRole => 'Check the color role.';

  @override
  String get unsupportedThemeOperation => 'Unsupported theme operation.';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      'Only explicitly confirmed new server keys can be saved.';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed =>
      'Only temporary transfer files can be processed.';

  @override
  String get checkTheSshJumpHostConnection =>
      'Check the SSH jump host connection.';

  @override
  String get enterAServerAddress => 'Enter a server address.';

  @override
  String get noHostToRestore => 'No host to restore.';

  @override
  String get thisProfileIsInUse => 'This profile is in use.';

  @override
  String get unsupportedLink => 'Unsupported link.';

  @override
  String get keyFile => 'Key file';

  @override
  String unsupportedOperation(String arg0) {
    return 'Unsupported operation: $arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable =>
      'Android Keystore key unavailable';

  @override
  String get legacyPrivateKeyDisabled => 'Legacy private key · disabled';

  @override
  String get toggleKeyboard => 'Toggle keyboard';

  @override
  String get endSession => 'End session';

  @override
  String disconnectFrom(String arg0) {
    return 'Disconnect from $arg0?';
  }

  @override
  String get end => 'End';

  @override
  String get couldNotCloseConnection => 'Could not close connection';

  @override
  String get noOpenSessions => 'No open sessions.';

  @override
  String disconnected2(String arg0) {
    return 'Disconnected$arg0';
  }

  @override
  String end2(String arg0) {
    return 'End $arg0';
  }

  @override
  String get newTab => 'New tab';

  @override
  String close(String arg0) {
    return 'Close $arg0';
  }

  @override
  String get image => 'Image';

  @override
  String get words => 'Words';

  @override
  String get firstConnectionToThisServer => 'First connection to this server';

  @override
  String get biometricAuthentication => 'Biometric authentication';

  @override
  String logInTo(String arg0) {
    return 'Log in to $arg0';
  }

  @override
  String get server => 'Server';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get saveOnThisDevice => 'Save on this device';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      'Check that this fingerprint matches the one provided by the server administrator.';

  @override
  String get fingerprintFormat => 'Fingerprint format';

  @override
  String authenticateWithKey(String arg0) {
    return 'Authenticate with key $arg0.';
  }

  @override
  String get cancelConnection => 'Cancel connection';

  @override
  String get reject => 'Reject';

  @override
  String get trustAndConnect => 'Trust and connect';

  @override
  String get logIn => 'Log in';

  @override
  String get continueAction => 'Continue';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0 waiting for login';
  }

  @override
  String get continueLogin => 'Continue login';

  @override
  String pasteLines(String arg0) {
    return 'Paste $arg0 lines?';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return 'Pasting $arg0 lines into the terminal may run commands immediately.';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      'Control characters may trigger terminal actions or command execution.';

  @override
  String get pasteWithoutTrailingEnter => 'Paste without trailing Enter';

  @override
  String pasteLines2(String arg0) {
    return 'Paste $arg0 lines';
  }

  @override
  String get editText => 'Edit text';

  @override
  String get textToSend => 'Text to send';

  @override
  String get send => 'Send';

  @override
  String get selectEntireLine => 'Select entire line';

  @override
  String get selectVisibleScreen => 'Select visible screen';

  @override
  String get selectAll => 'Select all';

  @override
  String get blockSelection => 'Block selection';

  @override
  String get share => 'Share';

  @override
  String get paste => 'Paste';

  @override
  String get copy2 => 'Copy';

  @override
  String get editAndSend => 'Edit and send';

  @override
  String get moreSelectionOptions => 'More selection options';

  @override
  String get selectionEnd => 'Selection end';

  @override
  String get selectionStart => 'Selection start';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String couldNotConnectTo(String arg0) {
    return 'Could not connect to $arg0';
  }

  @override
  String get couldNotCompleteOperation => 'Could not complete operation';

  @override
  String get couldNotFinishOperation => 'Could not finish operation';

  @override
  String checked(String arg0) {
    return 'Checked · $arg0';
  }

  @override
  String occurred(String arg0) {
    return 'Occurred · $arg0';
  }

  @override
  String get copyErrorLog => 'Copy error log';

  @override
  String get close2 => 'Close';

  @override
  String get saveElsewhere => 'Save elsewhere';

  @override
  String get retry => 'Retry';

  @override
  String deletedHost(String arg0) {
    return 'Deleted host $arg0';
  }

  @override
  String get ok => 'OK';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0 · Enter inserts a newline$arg1';
  }

  @override
  String get ctrlEnterSends => ', Ctrl Enter sends';

  @override
  String unsupported(String arg0) {
    return ' · $arg0 unsupported';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return 'Verify server key for $arg0';
  }

  @override
  String get trustServerKey => 'Trust server key';

  @override
  String authenticateWithKey2(String arg0) {
    return 'Authenticate with key $arg0.';
  }

  @override
  String get disconnectAll => 'Disconnect all';

  @override
  String get disconnectAllSessions => 'Disconnect all sessions?';

  @override
  String get disconnectAll2 => 'Disconnect all';

  @override
  String get removeServerKey => 'Remove server key?';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe =>
      'The server key will be verified again on the next connection.';

  @override
  String get deleteServerKey => 'Delete server key';

  @override
  String sessions(String arg0) {
    return ' · Sessions $arg0';
  }

  @override
  String get fileTransferSftp => 'File transfer (SFTP)';

  @override
  String get favorites => 'Favorites';

  @override
  String get quickConnect => 'Quick connect';

  @override
  String get createSshKeyOnThisDevice => 'Create SSH key on this device';

  @override
  String get sort => 'Sort';

  @override
  String get byColor => 'By color';

  @override
  String get byName => 'By name';

  @override
  String get help => 'Help';

  @override
  String get unlock => 'Unlock';

  @override
  String get couldNotPrepareAppData => 'Could not prepare app data';

  @override
  String get preparingTilde => 'Preparing Tilde';

  @override
  String get errorDetails => 'Error details';

  @override
  String get tildeHomeDirectory => 'Tilde home directory';

  @override
  String get inProgress => 'In progress';

  @override
  String get newOutput => 'New output';

  @override
  String get error => 'Error';

  @override
  String get notConnected => 'Not connected';

  @override
  String sessions2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '$count session',
    );
    return ' · $_temp0';
  }

  @override
  String get connectToYourFirstServer => 'Connect to your first server';

  @override
  String get saveAHostToConnectWithADoubleClick =>
      'Save a host to connect with a double-click next time.';

  @override
  String get saveAServerToConnectQuicklyNextTime =>
      'Save a server to connect quickly next time.';

  @override
  String get saveAddressUserAndAuthentication =>
      'Save address, user, and authentication';

  @override
  String get connectNow => 'Connect now';

  @override
  String get connectByAddress => 'Connect by address';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      'Enter ssh user@host in the search field and press Enter';

  @override
  String get privateKeyFileSuchAsIdEd25519 =>
      'Private key file such as id_ed25519';

  @override
  String connectingTo(String arg0, String arg1) {
    return 'Connecting to $arg0:$arg1';
  }

  @override
  String get negotiatingSshConnection => 'Negotiating SSH connection';

  @override
  String get verifyingServerKey => 'Verifying server key';

  @override
  String authenticating(String arg0) {
    return 'Authenticating $arg0';
  }

  @override
  String get authenticated => 'Authenticated';

  @override
  String get openingTerminalSession => 'Opening terminal session';

  @override
  String get confirmSshKeyUse => 'Confirm SSH key use';

  @override
  String get sshPrivateKeyPassphrase => 'SSH private key passphrase';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      'Connection blocked because the server key changed. Review and manually remove the saved server key.';

  @override
  String get preparingSshLogin => 'Preparing SSH login';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      'Logged in, but could not save the password. Save it again in the host editor.';

  @override
  String sendTo(String arg0) {
    return 'Send to $arg0';
  }

  @override
  String get send2 => 'Send';

  @override
  String get terminalSize => 'Terminal size';

  @override
  String get columns => 'Columns';

  @override
  String get rows => 'Rows';

  @override
  String get fullScreen => 'Full screen';

  @override
  String get autoHideTitleBar => 'Auto-hide title bar';

  @override
  String get terminalSizeColumnsRows => 'Terminal size · columns×rows';

  @override
  String get resize => 'Resize';

  @override
  String get text8024LeaveBlankForAutomaticSizing =>
      '80×24 · leave blank for automatic sizing';

  @override
  String get enterColumnsRowsSuchAs8024 => 'Enter columns×rows, such as 80×24.';

  @override
  String get terminalLinks => 'Terminal links';

  @override
  String get noLinksOnScreen => 'No links on screen.';

  @override
  String get enterText => 'Enter text';

  @override
  String get links => 'Links';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get couldNotVerifyServerKey => 'Could not verify server key';

  @override
  String get couldNotLogIn => 'Could not log in';

  @override
  String get couldNotOpenTerminal => 'Could not open terminal';

  @override
  String get couldNotConnectToServer => 'Could not connect to server';

  @override
  String connectingTo2(String arg0) {
    return 'Connecting to $arg0';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      'Check the saved server key and the fingerprint provided by the server administrator.';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      'Check your username and credentials. If using an SSH key, register the public key on the server.';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      'Check the server address, port, and network connection.';

  @override
  String get connectionLog => 'Connection log';

  @override
  String get deviceList => 'Device list';

  @override
  String get view => 'View';

  @override
  String get dismissBanner => 'Dismiss banner';

  @override
  String get connectionClosed => 'Connection closed';

  @override
  String get theServerEndedTheSession => 'The server ended the session';

  @override
  String get connectionEndedAfterAuthenticationFailed =>
      'Connection ended after authentication failed';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String ended(String arg0) {
    return 'Ended · $arg0';
  }

  @override
  String get copyOutput => 'Copy output';

  @override
  String sshKey(String arg0) {
    return '$arg0 SSH key';
  }

  @override
  String get couldNotPrepareRegistration => 'Could not prepare registration';

  @override
  String get keyToRegister => 'Key to register';

  @override
  String get newBiometricKey => 'New biometric key';

  @override
  String get createNewSshKey => 'Create new SSH key';

  @override
  String get registerSshKeyLogin => 'Register SSH key login';

  @override
  String keyRegistration(String arg0, String arg1) {
    return '$arg0 key registration$arg1';
  }

  @override
  String get anotherHost => 'Another host';

  @override
  String get isInProgress => ' is in progress';

  @override
  String get isComplete => ' is complete';

  @override
  String get registrationPreparationForThisHost =>
      'Registration preparation for this host';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      'Install the public key, then verify key login with a separate connection.';

  @override
  String get newKeyName => 'New key name';

  @override
  String get progress => 'Progress';

  @override
  String get installPublicKey => 'Install public key';

  @override
  String get verifyKeyLogin => 'Verify key login';

  @override
  String get applyToHost => 'Apply to host';

  @override
  String get theServerRejectedTheKey => 'The server rejected the key';

  @override
  String get theServerRequiresAdditionalAuthentication =>
      'The server requires additional authentication';

  @override
  String get couldNotCompleteThisStep => 'Could not complete this step';

  @override
  String get installedOnServer => 'Installed on server';

  @override
  String get keyAlreadyInstalled => 'Key already installed';

  @override
  String get keyLoginVerified => 'Key login verified';

  @override
  String get theServerRejectedThisKey => 'The server rejected this key';

  @override
  String get registrationComplete => 'Registration complete';

  @override
  String usingKey(String arg0) {
    return 'Using key $arg0';
  }

  @override
  String get removeSavedPasswordForThisHost =>
      'Remove saved password for this host';

  @override
  String get registerAndVerify => 'Register and verify';

  @override
  String get continueInBackground => 'Continue in background';

  @override
  String get previewColorThemeFontAndMargins =>
      'Preview color theme, font, and margins';

  @override
  String get srcBuildSampleMd => '\nsrc  build  sample.md';

  @override
  String get specialKeyBarPreview => 'Special key bar preview';

  @override
  String get fileTransferIsAvailableForSshHosts =>
      'File transfer is available for SSH hosts.';

  @override
  String get registerAKeyFromAConnectedSshSession =>
      'Register a key from a connected SSH session.';

  @override
  String get onlySshAndLocalConnectionsAreSupported =>
      'Only SSH and local connections are supported.';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      'The connection type changed. Open a new session from Home.';

  @override
  String get calculatingTimeRemaining => 'Calculating time remaining';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return '${arg0}m ${arg1}s remaining';
  }

  @override
  String secondsRemaining(String arg0) {
    return '${arg0}s remaining';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · Cancelling…';
  }

  @override
  String get checkingSize => 'Checking size';

  @override
  String get calculatingSpeed => 'Calculating speed';

  @override
  String active(String arg0) {
    return 'Active $arg0';
  }

  @override
  String queued(String arg0) {
    return 'Queued $arg0';
  }

  @override
  String failed(String arg0) {
    return 'Failed $arg0';
  }

  @override
  String completed(String arg0) {
    return 'Completed $arg0';
  }

  @override
  String cancelled(String arg0) {
    return 'Cancelled $arg0';
  }

  @override
  String get noTransfers => 'No transfers';

  @override
  String get queued2 => 'Queued';

  @override
  String get paused => 'Paused';

  @override
  String get completed2 => 'Completed';

  @override
  String get failed2 => 'Failed';

  @override
  String get cancelOperation => 'Cancel operation';

  @override
  String get openFolder => 'Open folder';

  @override
  String couldNotComplete(String arg0) {
    return 'Could not complete $arg0';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return '$arg0 / $arg1 items$arg2';
  }

  @override
  String transfer(String arg0) {
    return 'Transfer · $arg0';
  }

  @override
  String get transferQueue => 'Transfer queue';

  @override
  String get clearCompleted => 'Clear completed';

  @override
  String get collapseTransferQueue => 'Collapse transfer queue';

  @override
  String get expandTransferQueue => 'Expand transfer queue';

  @override
  String get all => 'All';

  @override
  String get selectARegularFile => 'Select a regular file.';

  @override
  String get aFileWithTheSameNameAlreadyExists =>
      'A file with the same name already exists.';

  @override
  String get theSourceFileSizeChangedDuringTransfer =>
      'The source file size changed during transfer.';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer =>
      'A file with the same name appeared during transfer.';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return 'Could not remove the temporary upload file. Check the server. $arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return 'Could not inspect the temporary upload file. Check the server. $arg0';
  }

  @override
  String get changePermissions => 'Change permissions';

  @override
  String get read => 'Read';

  @override
  String get write => 'Write';

  @override
  String get execute => 'Execute';

  @override
  String get owner => 'Owner';

  @override
  String get group => 'Group';

  @override
  String get other => 'Other';

  @override
  String get octalPermissions => 'Octal permissions';

  @override
  String get enterThreeOrFourDigitsFrom0To7 =>
      'Enter three or four digits from 0 to 7.';

  @override
  String get changePermissions2 => 'Change permissions';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return 'Could not open folder. Check the path and permissions.\n$arg0';
  }

  @override
  String get newFolder => 'New folder';

  @override
  String get create => 'Create';

  @override
  String get destinationFolder => 'Destination folder';

  @override
  String move(String arg0) {
    return 'Move $arg0';
  }

  @override
  String moveItems(String arg0) {
    return 'Move $arg0 items';
  }

  @override
  String get parentFolder => 'Parent folder';

  @override
  String get folderPath => 'Folder path';

  @override
  String get editPath => 'Edit path';

  @override
  String get moveHere => 'Move here';

  @override
  String permanentlyDeleteItems(String arg0) {
    return 'Permanently delete $arg0 items?';
  }

  @override
  String childItems(String arg0) {
    return '$arg0 child items';
  }

  @override
  String get checkingContents => 'Checking contents…';

  @override
  String get couldNotInspectFolderContentsTryAgain =>
      'Could not inspect folder contents. Try again.';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return 'Delete all $arg0 items, including folder contents. This cannot be undone.';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      'Delete immediately without using Trash. This cannot be undone.';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get unknownModificationDate => 'Unknown modification date';

  @override
  String get aFileWithTheSameNameExists => 'A file with the same name exists';

  @override
  String transferringItems(String arg0, String arg1) {
    return 'Transferring $arg0 / $arg1 items';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict =>
      'Choose which file to keep for each conflict.';

  @override
  String get fileBeingUploaded => 'File being uploaded';

  @override
  String get fileBeingDownloaded => 'File being downloaded';

  @override
  String get existingFileOnServer => 'Existing file on server';

  @override
  String get existingFileOnDevice => 'Existing file on device';

  @override
  String get unknownSize => 'Unknown size';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile =>
      'Keep the existing file and skip copying this file.';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      'Keep both. Add the first available number, starting at (1), before the copied file extension.';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      'Overwrite the existing file with the copied file. This cannot be undone.';

  @override
  String get cancelCopyingKeepTheExistingFile =>
      'Cancel this copy job, including its remaining files. Keep the existing files.';

  @override
  String applyToRemainingItems(String arg0) {
    return 'Apply to $arg0 remaining items';
  }

  @override
  String get cancelTransfer => 'Cancel transfer';

  @override
  String get cancelCopy => 'Cancel copy';

  @override
  String get loggingInForFileTransfer => 'Logging in for file transfer';

  @override
  String get couldNotLogInForFileTransfer =>
      'Could not log in for file transfer.';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      'Preview supports files up to 4 MiB. Download the file to open it.';

  @override
  String get saveFile => 'Save file';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      'The editor cannot overwrite folders or symbolic links.';

  @override
  String get serverFileChanged => 'Server file changed';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\nThe server file changed after editing began. Overwrite it?';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\nOverwrite the existing file?';
  }

  @override
  String get overwrite => 'Overwrite';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      'Could not reconnect to the server. Check authentication in the file browser.';

  @override
  String get saveACopyElsewhere => 'Save a copy elsewhere';

  @override
  String get saveCopy => 'Save copy';

  @override
  String get enterAnAbsolutePathIncludingTheFileName =>
      'Enter an absolute path including the file name.';

  @override
  String get enterAPathDifferentFromTheOriginal =>
      'Enter a path different from the original.';

  @override
  String get newFile => 'New file';

  @override
  String get anItemWithTheSameNameAlreadyExists =>
      'An item with the same name already exists.';

  @override
  String get thisItemIsBeingTransferred => 'This item is being transferred.';

  @override
  String get rename => 'Rename';

  @override
  String get change => 'Change';

  @override
  String get creatingFolder => 'Creating folder';

  @override
  String get folderCreated => 'Folder created.';

  @override
  String get deleting => 'Deleting';

  @override
  String deletingItems(String arg0) {
    return 'Deleting $arg0 items';
  }

  @override
  String deletedItems(String arg0) {
    return 'Deleted $arg0 items.';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · $arg0 items were deleted.';
  }

  @override
  String get changingPermissions => 'Changing permissions';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged =>
      'Symbolic link permissions will not be changed.';

  @override
  String get permissionsChanged => 'Permissions changed.';

  @override
  String operationCancelled(String arg0) {
    return 'Operation cancelled.$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return 'Could not complete operation.$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return '$arg0 items: $arg1 · Paste in the destination folder.';
  }

  @override
  String get cut => 'Cut';

  @override
  String get noFilesToPaste => 'No files to paste.';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr =>
      'Cannot move or copy to the same location or inside the source folder.';

  @override
  String get move2 => 'Move';

  @override
  String get copyTemporaryDownloadAndUpload =>
      'Copy (temporary download and upload)';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      'Choosing a folder destination is unsupported on this platform.';

  @override
  String get connectionClosed2 => 'Connection closed.';

  @override
  String get downloadToFileManager => 'Download to file manager';

  @override
  String get theTemporaryExportPathAlreadyExists =>
      'The temporary export path already exists.';

  @override
  String get cancelTransfersAndClose => 'Cancel transfers and close';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      'Cancel active transfers and queued operations in this tab?';

  @override
  String get uploadFolder => 'Upload folder';

  @override
  String get connectionCancelled => 'Connection cancelled';

  @override
  String get couldNotOpenFileList => 'Could not open file list';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · File transfer';
  }

  @override
  String get fileList => 'File list';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      'Check the folder path and permissions, then try again.';

  @override
  String get bookmarkCurrentFolder => 'Bookmark current folder';

  @override
  String get recentLocations => 'Recent locations';

  @override
  String selected(String arg0) {
    return '$arg0 selected';
  }

  @override
  String get forward => 'Forward';

  @override
  String get remoteFolderPath => 'Remote folder path';

  @override
  String get bookmarksAndRecentLocations => 'Bookmarks and recent locations';

  @override
  String get refresh => 'Refresh';

  @override
  String get findInCurrentFolder => 'Find in current folder';

  @override
  String get readOnly => 'Read only';

  @override
  String get discardChanges2 => 'Discard changes';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\nDiscard unsaved changes?';
  }

  @override
  String get doNotSave => 'Do not save';

  @override
  String get editing => 'Editing';

  @override
  String get saveCopyKeepOriginalUnchanged =>
      'Save copy · keep original unchanged';

  @override
  String savedACopyTo(String arg0) {
    return 'Saved a copy to $arg0.';
  }

  @override
  String get saved2 => 'Saved.';

  @override
  String get couldNotOpenFile => 'Could not open file';

  @override
  String couldNotOpen(String arg0) {
    return 'Could not open $arg0';
  }

  @override
  String get previewIsUnsupportedForThisFileType =>
      'Preview is unsupported for this file type.';

  @override
  String get couldNotSaveYourChangesHaveBeenKept =>
      'Could not save. Your changes have been kept.';

  @override
  String couldNotSave2(String arg0) {
    return 'Could not save $arg0';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · $arg1 lines · $arg2 B';
  }

  @override
  String get unsupportedFileType => 'Unsupported file type.';

  @override
  String get unsupportedRemoteFileType => 'Unsupported remote file type.';

  @override
  String get theTransferSourceChangedStartANewTransfer =>
      'The transfer source changed. Start a new transfer.';

  @override
  String get anItemWithThisNameExistsAndIsNot =>
      'An item with this name exists and is not a folder.';

  @override
  String get cannotOverwriteAFolderWithAFile =>
      'Cannot overwrite a folder with a file.';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      'Names cannot contain path separators or be . or ...';

  @override
  String get aFileOrFolderWithTheSameNameAlready =>
      'A file or folder with the same name already exists.';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      'Cannot move a folder into itself or its descendants.';

  @override
  String get cannotDeleteTheRootFolder => 'Cannot delete the root folder.';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      'The server denied access. Check the destination path permissions.';

  @override
  String get theFileOrFolderNoLongerExists =>
      'The file or folder no longer exists.';

  @override
  String get serverConnectionLost => 'Server connection lost.';

  @override
  String get theServerCouldNotCompleteTheOperation =>
      'The server could not complete the operation.';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd =>
      'The server is not responding. Check the address and network.';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      'The server did not authenticate you. Check your username, key, and password.';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return 'The server refused the connection $arg0. Check SSH and port settings.';
  }

  @override
  String onPort(String arg0) {
    return ' on port $arg0';
  }

  @override
  String get checkTheServerConnection =>
      'Could not communicate with the server. Check your network connection.';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      'Unexpected error. Copy the details below and contact support.';

  @override
  String get transferCancelled => 'Transfer cancelled.';

  @override
  String get invalidFileName => 'Invalid file name.';

  @override
  String get theFileWasNotReceivedCompletely =>
      'The file was not received completely.';

  @override
  String get size => 'Size';

  @override
  String get modified => 'Modified';

  @override
  String get permissions => 'Permissions';

  @override
  String get ownerUid => 'Owner UID';

  @override
  String get groupGid => 'Group GID';

  @override
  String get showHiddenFilesAndFolders => 'Show hidden files and folders';

  @override
  String get descending => 'Descending';

  @override
  String get visibleColumns => 'Visible columns';

  @override
  String get preview => 'Preview';

  @override
  String get move3 => 'Move…';

  @override
  String get copyPath => 'Copy path';

  @override
  String get info => 'Info';

  @override
  String get changePermissions3 => 'Change permissions…';

  @override
  String get fileInformation => 'File information';

  @override
  String get path => 'Path';

  @override
  String get type2 => 'Type';

  @override
  String get folder => 'Folder';

  @override
  String get symbolicLink => 'Symbolic link';

  @override
  String get file => 'File';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get location => 'Location';

  @override
  String selected2(String arg0, String arg1) {
    return '$arg0 selected · $arg1';
  }

  @override
  String get parentFolderBackspace => 'Parent folder (Backspace)';

  @override
  String get loading => 'Loading…';

  @override
  String get noFilesToDisplay => 'No files to display.';

  @override
  String get noMatchingFiles => 'No matching files.';

  @override
  String get applyNewName => 'Apply new name';

  @override
  String actions(String arg0) {
    return '$arg0 actions';
  }

  @override
  String items3(String arg0, String arg1) {
    return '$arg0 items$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · $arg0 hidden/filtered';
  }

  @override
  String copy3(String arg0) {
    return '$arg0 copy';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return '$arg0 hosts will use the app default profile.';
  }

  @override
  String get deleteThisProfile => 'Delete this profile.';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return 'Connections for $arg0 hosts will remain, but the shared password will be deleted.';
  }

  @override
  String delete2(String arg0) {
    return 'Delete $arg0';
  }

  @override
  String get setAsDefault => 'Set as default';

  @override
  String add2(String arg0) {
    return 'Add $arg0';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      'Share a username, key, and password across multiple hosts.';

  @override
  String get default2 => ' · Default';

  @override
  String get noHostsUsingThis => 'No hosts using this';

  @override
  String hosts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts',
      one: '$count host',
    );
    return '$_temp0';
  }

  @override
  String get privateKeyPassphrase => 'Private key passphrase';

  @override
  String get leaveBlankIfThereIsNoPassphrase =>
      'Leave blank if there is no passphrase.';

  @override
  String get deleteKey2 => 'Delete key';

  @override
  String deleteKey3(String arg0) {
    return 'Delete key $arg0?';
  }

  @override
  String get savePublicKeyFile => 'Save public key file';

  @override
  String get addKeyFile => 'Add key file';

  @override
  String get newKey => 'New key';

  @override
  String get couldNotCompleteKeyOperation => 'Could not complete key operation';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      'Imported private keys are used from protected app storage. Saved passphrases are protected by iOS Keychain.';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      'Private key files are used from their original location. Saved passphrases are protected by your Windows account.';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      'Private keys are created in Android Keystore and cannot be exported. Legacy private keys are preserved in a disabled state.';

  @override
  String get disabled => 'Disabled';

  @override
  String options(String arg0) {
    return '$arg0 options';
  }

  @override
  String get deleteForwarding => 'Delete forwarding';

  @override
  String deleteSettingsFor(String arg0) {
    return 'Delete settings for $arg0?';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · Forwarding';
  }

  @override
  String get addForwarding => 'Add forwarding';

  @override
  String get sessionToControl => 'Session to control';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · Switch changes apply immediately';
  }

  @override
  String get defaultOnConnection => 'Default on connection';

  @override
  String get couldNotLoadForwarding => 'Could not load forwarding';

  @override
  String get socks4UnsupportedChangeToSocks5 =>
      'SOCKS4 unsupported · Change to SOCKS5';

  @override
  String get removeServerKeyTrust => 'Remove server key trust';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\nThe server key will be verified on the next connection.';
  }

  @override
  String get noTrustedServerKeys => 'No trusted server keys.';

  @override
  String get use => 'Use';

  @override
  String get editPalette => 'Edit palette';

  @override
  String get export => 'Export';

  @override
  String get defaultTheme => 'Default theme';

  @override
  String get customTheme => 'Custom theme';

  @override
  String get nameForDuplicateTheme => 'Name for duplicate theme';

  @override
  String get themeName => 'Theme name';

  @override
  String get deleteTheme => 'Delete theme';

  @override
  String deleteTheme2(String arg0) {
    return 'Delete theme $arg0?';
  }

  @override
  String get newThemeName => 'New theme name';

  @override
  String get newTheme => 'New theme';

  @override
  String get import => 'Import';

  @override
  String get textColor => 'Text color';

  @override
  String get backgroundColor => 'Background color';

  @override
  String get cursorAndAppAccent => 'Cursor and app accent';

  @override
  String get couldNotLoadColorTheme => 'Could not load color theme';

  @override
  String get makeACopyToEditTheColors => 'Make a copy to edit the colors.';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  sample.md\n';

  @override
  String get defaultColors => 'Default colors';

  @override
  String get lowContrastAgainstBackground => 'Low contrast against background';

  @override
  String get ansiPalette => 'ANSI palette';

  @override
  String ansiColor(String arg0) {
    return 'ANSI color $arg0';
  }

  @override
  String get findServer => 'Find server';

  @override
  String get verifyServerKey => 'Verify server key';

  @override
  String seconds(String arg0) {
    return '${arg0}s';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain =>
      'Could not open ad privacy settings. Try again.';

  @override
  String get ad => 'Ad';

  @override
  String get adPrivacySettings => 'Ad privacy settings';

  @override
  String get googleFontsMonospace => 'Google Fonts · Monospace';

  @override
  String get searchSettings => 'Search settings';

  @override
  String get keyboard => 'Keyboard';

  @override
  String get gestures => 'Gestures';

  @override
  String get connectionsAndNotifications => 'Connections and notifications';

  @override
  String get securityAndBackup => 'Security and backup';

  @override
  String get manageFonts => 'Manage fonts';

  @override
  String get specialKeyBar => 'Special key bar';

  @override
  String specialKeys(String arg0) {
    return '$arg0 special keys';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return 'Two-finger horizontal swipe · $arg0';
  }

  @override
  String get tmuxWindows => 'tmux windows';

  @override
  String get disabled2 => 'Disabled';

  @override
  String get defaultTerminal => 'Default terminal';

  @override
  String get notificationsAndBell => 'Notifications and bell';

  @override
  String sshKeys2(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SSH keys',
      one: '$count SSH key',
    );
    return '$_temp0';
  }

  @override
  String get helpAndLogs2 => 'Help and logs';

  @override
  String get horizontalMargins => 'Horizontal margins';

  @override
  String get lines => 'lines';

  @override
  String get appTheme => 'App theme';

  @override
  String get systemTheme => 'System theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get font => 'Font';

  @override
  String get orientation => 'Orientation';

  @override
  String get alwaysRotate => 'Always rotate';

  @override
  String get portrait => 'Portrait';

  @override
  String get landscape => 'Landscape';

  @override
  String get hideStatusBar => 'Hide status bar';

  @override
  String get specialKeyLayout => 'Special key layout';

  @override
  String get showWhenKeyboardIsClosed => 'Show when keyboard is closed';

  @override
  String get whenPressingCtrlOrAlt => 'When pressing Ctrl or Alt';

  @override
  String get once => 'Once';

  @override
  String get sticky => 'Sticky';

  @override
  String get stickyAltOnly => 'Sticky Alt only';

  @override
  String get keyboardToggleButton => 'Keyboard toggle button';

  @override
  String get twoFingerHorizontalSwipe2 => 'Two-finger horizontal swipe';

  @override
  String get doNothing => 'Do nothing';

  @override
  String get switchSessions => 'Switch sessions';

  @override
  String get switchTmuxWindows => 'Switch tmux windows';

  @override
  String get prefixKey => 'Prefix key';

  @override
  String get twoFingerVerticalSwipe => 'Two-finger vertical swipe';

  @override
  String get scroll => 'Scroll';

  @override
  String get volumeButtonsChangeFontSize => 'Volume buttons change font size';

  @override
  String get specialKeyVibration => 'Special key vibration';

  @override
  String get defaultTerminalProfile => 'Default terminal profile';

  @override
  String get manageTerminalProfiles => 'Manage terminal profiles';

  @override
  String itemCount(String arg0) {
    return '$arg0';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get terminalTypeTerm => 'Terminal type (TERM)';

  @override
  String get addTerminalType => 'Add terminal type';

  @override
  String get terminalType => 'Terminal type';

  @override
  String get keepScreenAwakeWhileConnected =>
      'Keep screen awake while connected';

  @override
  String get theTerminalScreenWillStayAwake =>
      'The terminal screen will stay awake';

  @override
  String get preventWiFiSleep => 'Prevent Wi-Fi sleep';

  @override
  String get usesMoreBattery => 'Uses more battery';

  @override
  String get backgroundConnectionNotification =>
      'Background connection notification';

  @override
  String get pinnedWhileConnected => 'Pinned while connected';

  @override
  String get terminalBell => 'Terminal bell';

  @override
  String get whenTheBellRings => 'When the bell rings';

  @override
  String get ignore => 'Ignore';

  @override
  String get sound => 'Sound';

  @override
  String get vibration => 'Vibration';

  @override
  String get soundAndVibration => 'Sound and vibration';

  @override
  String get volume => 'Volume';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationPermissionRequired =>
      'Notification permission required';

  @override
  String get allow => 'Allow';

  @override
  String get enableConnectionNotifications => 'Enable connection notifications';

  @override
  String get allowBellAndDisconnectionNotifications =>
      'Allow bell and disconnection notifications';

  @override
  String get bellInBackground => 'Bell in background';

  @override
  String get onDisconnect => 'On disconnect';

  @override
  String get androidNotificationSettings => 'Android notification settings';

  @override
  String get notificationsOff => 'Notifications off';

  @override
  String get notificationsAllowed => 'Notifications allowed';

  @override
  String get lock => 'Lock';

  @override
  String get unlockWhenStartingTheApp => 'Unlock when starting the app';

  @override
  String get setUpAScreenLockFirst => 'Set up a screen lock first';

  @override
  String get fingerprintOrScreenLock => 'Fingerprint or screen lock';

  @override
  String get keysAndServers => 'Keys and servers';

  @override
  String get configurationFile => 'Configuration file';

  @override
  String get exportHosts => 'Export hosts';

  @override
  String get importHosts => 'Import hosts';

  @override
  String get selectDefaultFont => 'Select default font';

  @override
  String fontSample(String arg0) {
    return '$arg0 Aa';
  }

  @override
  String get bundledWithApp => 'Bundled with app';

  @override
  String get monospaceFont => 'Monospace font';

  @override
  String get deleteFont => 'Delete font';

  @override
  String get deleteThisFontFile => 'Delete this font file?';

  @override
  String get removeFont => 'Remove font';

  @override
  String get preparingFont => 'Preparing font';

  @override
  String get importFontFile => 'Import font file';

  @override
  String get findOnGoogleFonts => 'Find on Google Fonts';

  @override
  String get onlyMonospaceFontsAreShown => 'Only monospace fonts are shown';

  @override
  String settings2(String arg0) {
    return 'Settings › $arg0';
  }

  @override
  String get couldNotSaveSettings => 'Could not save settings';

  @override
  String get resetSpecialKeyBar => 'Reset special key bar?';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      'Restore the default height, key order, and visibility.';

  @override
  String get longPressToDragTapToHide => 'Long-press to drag · Tap to hide';

  @override
  String get hiddenKeys => 'Hidden keys';

  @override
  String get tapAKeyToMoveItHere => 'Tap a key to move it here';

  @override
  String get combineF1F12IntoFn => 'Combine F1–F12 into Fn';

  @override
  String get height => 'Height';

  @override
  String get small => 'Small';

  @override
  String get large => 'Large';

  @override
  String get default3 => 'Default';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc and Ctrl stay on the left; keyboard, Fn, and Tab stay on the right.';

  @override
  String get flutterLibraryLicenses => 'Flutter library licenses';

  @override
  String get tips => 'Tips';

  @override
  String get licensesAndTerms => 'Licenses and terms';

  @override
  String get projectAndContact => 'Project and contact';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticLogs => 'Diagnostic logs';

  @override
  String get searchLogs => 'Search logs';

  @override
  String get saveNativeCrashLog => 'Save native crash log';

  @override
  String get warning => 'Warning';

  @override
  String get couldNotLoadLogs => 'Could not load logs';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      'Only Android Keystore SSH keys are supported';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      'Only P-256 Android Keystore keys are supported';

  @override
  String get invalidEcdsaSignature => 'Invalid ECDSA signature';

  @override
  String get invalidEcdsaSignatureValues => 'Invalid ECDSA signature values';

  @override
  String get invalidX509PublicKey => 'Invalid X509 public key';

  @override
  String get invalidPublicKeyBitString => 'Invalid public key bit string';

  @override
  String get invalidRsaPublicKey => 'Invalid RSA public key';

  @override
  String get invalidEcCurve => 'Invalid EC curve';

  @override
  String get invalidUncompressedEcPoint => 'Invalid uncompressed EC point';

  @override
  String get invalidEd25519PublicKey => 'Invalid Ed25519 public key';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return 'Unsupported SSH public key algorithm: $arg0';
  }

  @override
  String get unsupportedSshEcCurve => 'Unsupported SSH EC curve';

  @override
  String get invalidDerSequence => 'Invalid DER sequence';

  @override
  String get privateKeyExportIsNotSupported =>
      'Private key export is not supported';

  @override
  String get publicKeyIsUnavailable => 'Public key is unavailable';

  @override
  String unsupportedTerminalKey(String arg0) {
    return 'Unsupported terminal key: $arg0';
  }

  @override
  String get disconnectBeforeReconnecting => 'Disconnect before reconnecting';

  @override
  String get localShellIsNotOpen => 'Local shell is not open';

  @override
  String get unknownModifier => 'Unknown modifier';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return 'Unsupported local terminal operation: $arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'Invalid SSH public-key line';

  @override
  String get serverDidNotConfirmPublicKeyRegistration =>
      'Server did not confirm public-key registration.';

  @override
  String get logInToASavedSshHostBeforeRegistering =>
      'Log in to a saved SSH host before registering a key.';

  @override
  String get theSelectedSshKeyNoLongerExists =>
      'The selected SSH key no longer exists.';

  @override
  String get aUniqueBiometricKeyNameIsRequired =>
      'A unique biometric key name is required.';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      'The original SSH connection is no longer authenticated.';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      'Key-only login was not completed. The server may require additional authentication. Login settings were not changed.';

  @override
  String get theSavedHostNoLongerExists => 'The saved host no longer exists.';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      'The host address changed during registration. Its login settings were not changed.';

  @override
  String get invalidPtyDimensions => 'Invalid PTY dimensions';

  @override
  String get sshTargetIsRequired => 'SSH target is required';

  @override
  String get sshSessionWasClosed => 'SSH session was closed';

  @override
  String get sshSessionIsNotConnected => 'SSH session is not connected';

  @override
  String get sshSessionsCannotBeReused => 'SSH sessions cannot be reused';

  @override
  String get noAddressForRequestedIpVersion =>
      'No address for requested IP version';

  @override
  String get sshHopConnectionTimedOut => 'SSH hop connection timed out';

  @override
  String get sshSessionHasNoShell => 'SSH session has no shell';

  @override
  String get sshSessionRequestTimedOut => 'SSH session request timed out';

  @override
  String get invalidForwardBindPort => 'Invalid forward bind port';

  @override
  String get invalidForwardDestination => 'Invalid forward destination';

  @override
  String get remoteForwardingRequestTimedOut =>
      'Remote forwarding request timed out';

  @override
  String get remoteForwardingWasRefused => 'Remote forwarding was refused';

  @override
  String get forwardConnectionTimedOut => 'Forward connection timed out';

  @override
  String get remoteForwardDestinationTimedOut =>
      'Remote forward destination timed out';

  @override
  String get remoteForwardingCancellationWasRefused =>
      'Remote forwarding cancellation was refused';

  @override
  String get sshAuthenticationCancelled => 'SSH authentication cancelled';

  @override
  String get concurrentSshAuthenticationPrompt =>
      'Concurrent SSH authentication prompt';

  @override
  String get sessionDisposed => 'Session disposed';

  @override
  String get disconnectBeforeRefreshingSshConfiguration =>
      'Disconnect before refreshing SSH configuration';

  @override
  String get couldNotUnlockTheSelectedKey =>
      'Could not unlock the selected key.';

  @override
  String get logInToThisServerBeforeRegisteringAKey =>
      'Log in to this server before registering a key.';

  @override
  String get sshShellIsNotOpen => 'SSH shell is not open';

  @override
  String get sshIsNotConnected => 'SSH is not connected';

  @override
  String get portForwardIsMissing => 'Port forward is missing';

  @override
  String get unsupportedSshForwardType => 'Unsupported SSH forward type';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return 'Unsupported app SSH operation: $arg0';
  }

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get timedOutReadingWindowsSshSettings =>
      'Timed out reading Windows SSH settings.';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return 'Could not read Windows SSH settings. $arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable =>
      'Windows user profile path is unavailable.';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return 'Unsupported SSH key path variable: $arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return 'Could not import files: $arg0';
  }

  @override
  String uploadTo(String arg0) {
    return 'Upload to $arg0';
  }

  @override
  String get currentFolder => 'Current folder';

  @override
  String get windowsUserDataFolderIsUnavailable =>
      'Windows user data folder is unavailable.';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return 'Could not protect credentials with the Windows account. $arg0';
  }

  @override
  String get altDrag => 'Alt drag';

  @override
  String get keyUp => 'Up';

  @override
  String get keyDown => 'Down';

  @override
  String get keyHome => 'Home';

  @override
  String get keyEnd => 'End';

  @override
  String get keyPageUp => 'Page up';

  @override
  String get keyPageDown => 'Page down';

  @override
  String get keyInsert => 'Insert';

  @override
  String get keyDelete => 'Delete';

  @override
  String get skipCopy => 'Skip';

  @override
  String get keepBothFiles => 'Keep both';

  @override
  String get cancelJobNoApplyAll =>
      'Apply to remaining files is unavailable when cancelling the job.';

  @override
  String get editAuthentication => 'Edit authentication';

  @override
  String get serverMessage => 'Server message';

  @override
  String get cancellingOperation => 'Cancelling…';

  @override
  String get transferHeading => 'Transfers';

  @override
  String get newPasskey => 'New passkey';

  @override
  String get createPasskey => 'Create passkey';

  @override
  String get restorePasskey => 'Restore passkey connection';

  @override
  String get exportPasskey => 'Save passkey credential file';

  @override
  String get passkeyStorageNote =>
      'New SSH keys are encrypted using your passkey. Keep the encrypted credential backup and the passkey to restore after reinstalling or switching devices.';

  @override
  String get passkeyRestoreNote =>
      'Open the encrypted credential backup and authorize its passkey to restore. Historical connection files contain public metadata only.';

  @override
  String get passkeyUnavailable =>
      'Passkeys require Android 9 or later and a compatible credential provider.';

  @override
  String get passkeyCancelled => 'Passkey operation cancelled.';

  @override
  String get invalidPasskey => 'Invalid passkey response or connection file.';

  @override
  String get passkeyPrfTest => 'Passkey decryption test';

  @override
  String get passkeyPrfTestNote =>
      'Create a test passkey and save an encrypted test file. Open the file here, then in Tilde on another Android device using the same passkey. This test does not register an SSH key.';

  @override
  String get passkeyPrfCreate => 'Create test file';

  @override
  String get passkeyPrfOpen => 'Open test file';

  @override
  String get passkeyPrfSaved =>
      'Test file saved. Open it to check decryption on this device and another device.';

  @override
  String get passkeyPrfVerified =>
      'Decryption succeeded. This environment recovered the same passkey PRF value.';

  @override
  String get passkeyPrfUnsupported =>
      'The selected passkey provider does not support PRF in this environment.';

  @override
  String get passkeyPrfMismatch =>
      'Decryption failed. The file may be damaged or the PRF value may differ.';

  @override
  String get credentialKind => 'Credential type';

  @override
  String get passkeySshKeyMode => 'Create and protect an SSH key';

  @override
  String get passkeyPasswordMode => 'Protect an SSH password';

  @override
  String get passkeyPasswordNote =>
      'Unlocks only for the specified server and account. SSH encrypts transport, but the server receives the password. Keep the encrypted backup and the passkey.';

  @override
  String get passkeyPasswordSelectNote =>
      'Choose a passkey-protected credential above. Creating passwords with the previous device storage is disabled.';

  @override
  String get legacyCredential => 'Deprecated · migration recommended';

  @override
  String get credentialFieldRequired => 'This field is required.';

  @override
  String get credentialPortInvalid => 'Enter a valid SSH port.';
}
