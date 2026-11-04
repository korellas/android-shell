// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// Tilde app: Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Tilde app: Terminal
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// Tilde app: {arg0} · Files
  ///
  /// In en, this message translates to:
  /// **'{arg0} · Files'**
  String files(String arg0);

  /// Tilde app: New host
  ///
  /// In en, this message translates to:
  /// **'New host'**
  String get newHost;

  /// Tilde app: Edit {arg0}
  ///
  /// In en, this message translates to:
  /// **'Edit {arg0}'**
  String edit(String arg0);

  /// Tilde app: Disconnect and close tab
  ///
  /// In en, this message translates to:
  /// **'Disconnect and close tab'**
  String get disconnectAndCloseTab;

  /// Tilde app: Disconnect from {arg0} and close this tab?
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {arg0} and close this tab?'**
  String disconnectFromAndCloseThisTab(String arg0);

  /// Tilde app: Disconnect and close
  ///
  /// In en, this message translates to:
  /// **'Disconnect and close'**
  String get disconnectAndClose;

  /// Tilde app: New terminal
  ///
  /// In en, this message translates to:
  /// **'New terminal'**
  String get newTerminal;

  /// Tilde app: File transfer
  ///
  /// In en, this message translates to:
  /// **'File transfer'**
  String get fileTransfer;

  /// Tilde app: Edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit2;

  /// Tilde app: Remove from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// Tilde app: Add to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// Tilde app: Duplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// Tilde app: Port forwarding
  ///
  /// In en, this message translates to:
  /// **'Port forwarding'**
  String get portForwarding;

  /// Tilde app: Disconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Tilde app: Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Tilde app: Name for duplicate host
  ///
  /// In en, this message translates to:
  /// **'Name for duplicate host'**
  String get nameForDuplicateHost;

  /// Tilde app: {arg0} copy
  ///
  /// In en, this message translates to:
  /// **'{arg0} copy'**
  String copy(String arg0);

  /// Tilde app: Disconnect all sessions for {arg0}?
  ///
  /// In en, this message translates to:
  /// **'Disconnect all sessions for {arg0}?'**
  String disconnectAllSessionsFor(String arg0);

  /// Tilde app: Search hosts
  ///
  /// In en, this message translates to:
  /// **'Search hosts'**
  String get searchHosts;

  /// Tilde app: Search hosts or enter SSH address (Ctrl K)
  ///
  /// In en, this message translates to:
  /// **'Search hosts or enter SSH address (Ctrl K)'**
  String get searchHostsOrEnterSshAddressCtrlK;

  /// Tilde app: Add host
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get addHost;

  /// Tilde app: No hosts yet
  ///
  /// In en, this message translates to:
  /// **'No hosts yet'**
  String get noHostsYet;

  /// Tilde app: Open terminals
  ///
  /// In en, this message translates to:
  /// **'Open terminals'**
  String get openTerminals;

  /// Tilde app: Open files
  ///
  /// In en, this message translates to:
  /// **'Open files'**
  String get openFiles;

  /// Tilde app: {arg0} menu
  ///
  /// In en, this message translates to:
  /// **'{arg0} menu'**
  String menu(String arg0);

  /// Tilde app: Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Tilde app: Help and logs
  ///
  /// In en, this message translates to:
  /// **'Help and logs'**
  String get helpAndLogs;

  /// Tilde app: Host list (Ctrl B)
  ///
  /// In en, this message translates to:
  /// **'Host list (Ctrl B)'**
  String get hostListCtrlB;

  /// Tilde app: Close {arg0} tab
  ///
  /// In en, this message translates to:
  /// **'Close {arg0} tab'**
  String closeTab(String arg0);

  /// Tilde app: New tab (Ctrl Shift T)
  ///
  /// In en, this message translates to:
  /// **'New tab (Ctrl Shift T)'**
  String get newTabCtrlShiftT;

  /// Tilde app: Terminal menu
  ///
  /// In en, this message translates to:
  /// **'Terminal menu'**
  String get terminalMenu;

  /// Tilde app: Import SSH key
  ///
  /// In en, this message translates to:
  /// **'Import SSH key'**
  String get importSshKey;

  /// Tilde app: Open sessions
  ///
  /// In en, this message translates to:
  /// **'Open sessions'**
  String get openSessions;

  /// Tilde app: Session {arg0}
  ///
  /// In en, this message translates to:
  /// **'Session {arg0}'**
  String session(String arg0);

  /// Tilde app: Connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Tilde app: Connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// Tilde app: Disconnected
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Tilde app: Open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Tilde app: Connect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Tilde app: Address
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Tilde app: Authentication
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authentication;

  /// Tilde app: Try all available keys
  ///
  /// In en, this message translates to:
  /// **'Try all available keys'**
  String get tryAllAvailableKeys;

  /// Tilde app: Use server settings
  ///
  /// In en, this message translates to:
  /// **'Use server settings'**
  String get useServerSettings;

  /// Tilde app: Terminal profile
  ///
  /// In en, this message translates to:
  /// **'Terminal profile'**
  String get terminalProfile;

  /// Tilde app: App default profile
  ///
  /// In en, this message translates to:
  /// **'App default profile'**
  String get appDefaultProfile;

  /// Tilde app: Manage
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// Tilde app: Minimize
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// Tilde app: Restore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Tilde app: Maximize
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// Tilde app: Close window
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// Tilde app: Host
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// Tilde app: Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Tilde app: Shared login account
  ///
  /// In en, this message translates to:
  /// **'Shared login account'**
  String get sharedLoginAccount;

  /// Tilde app: SSH keys
  ///
  /// In en, this message translates to:
  /// **'SSH keys'**
  String get sshKeys;

  /// Tilde app: Enter {arg0}.
  ///
  /// In en, this message translates to:
  /// **'Enter {arg0}.'**
  String enter(String arg0);

  /// Tilde app: Enter a whole number.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number.'**
  String get enterAWholeNumber;

  /// Tilde app: Check the port range.
  ///
  /// In en, this message translates to:
  /// **'Check the port range.'**
  String get checkThePortRange;

  /// Tilde app: {arg0} (current value)
  ///
  /// In en, this message translates to:
  /// **'{arg0} (current value)'**
  String currentValue(String arg0);

  /// Tilde app: Select
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// Tilde app: Default
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultValue;

  /// Tilde app:  (DSA unsupported)
  ///
  /// In en, this message translates to:
  /// **' (DSA unsupported)'**
  String get dsaUnsupported;

  /// Tilde app: Windows default keys and added keys
  ///
  /// In en, this message translates to:
  /// **'Windows default keys and added keys'**
  String get windowsDefaultKeysAndAddedKeys;

  /// Tilde app: No key
  ///
  /// In en, this message translates to:
  /// **'No key'**
  String get noKey;

  /// Tilde app: Password (saved)
  ///
  /// In en, this message translates to:
  /// **'Password (saved)'**
  String get passwordSaved;

  /// Tilde app: Password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Tilde app: Stored encrypted on this device. Enter it again after restoring to another device.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device. Enter it again after restoring to another device.'**
  String get storedEncryptedOnThisDeviceEnterItAgainAfter;

  /// Tilde app: Stored encrypted on this device.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device.'**
  String get storedEncryptedOnThisDevice;

  /// Tilde app: Delete saved password
  ///
  /// In en, this message translates to:
  /// **'Delete saved password'**
  String get deleteSavedPassword;

  /// Tilde app: Account name
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// Tilde app: Username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Tilde app: Applies to {arg0} hosts
  ///
  /// In en, this message translates to:
  /// **'Applies to {arg0} hosts'**
  String appliesToHosts(String arg0);

  /// Tilde app: Display
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get display;

  /// Tilde app: Profile name
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// Tilde app: Color theme
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get colorTheme;

  /// Tilde app: Terminal font
  ///
  /// In en, this message translates to:
  /// **'Terminal font'**
  String get terminalFont;

  /// Tilde app: App default
  ///
  /// In en, this message translates to:
  /// **'App default'**
  String get appDefault;

  /// Tilde app: Font size
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// Tilde app: Character encoding
  ///
  /// In en, this message translates to:
  /// **'Character encoding'**
  String get characterEncoding;

  /// Tilde app: Delete key
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get deleteKey;

  /// Tilde app: Columns · automatic
  ///
  /// In en, this message translates to:
  /// **'Columns · automatic'**
  String get columnsAutomatic;

  /// Tilde app: Rows · automatic
  ///
  /// In en, this message translates to:
  /// **'Rows · automatic'**
  String get rowsAutomatic;

  /// Tilde app: Forwarding
  ///
  /// In en, this message translates to:
  /// **'Forwarding'**
  String get forwarding;

  /// Tilde app: Forwarding name
  ///
  /// In en, this message translates to:
  /// **'Forwarding name'**
  String get forwardingName;

  /// Tilde app: Type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// Tilde app: Local
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// Tilde app: Remote
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remote;

  /// Tilde app: Forward connections from a server port to an address on this device.
  ///
  /// In en, this message translates to:
  /// **'Forward connections from a server port to an address on this device.'**
  String get forwardConnectionsFromAServerPortToAnAddress;

  /// Tilde app: Forward connections from a device port to an address on the server side.
  ///
  /// In en, this message translates to:
  /// **'Forward connections from a device port to an address on the server side.'**
  String get forwardConnectionsFromADevicePortToAnAddress;

  /// Tilde app: Open a SOCKS5 proxy on this device.
  ///
  /// In en, this message translates to:
  /// **'Open a SOCKS5 proxy on this device.'**
  String get openASocks5ProxyOnThisDevice;

  /// Tilde app: SOCKS4 is unsupported. Change the type to SOCKS5 to use it.
  ///
  /// In en, this message translates to:
  /// **'SOCKS4 is unsupported. Change the type to SOCKS5 to use it.'**
  String get socks4IsUnsupportedChangeTheTypeToSocks5To;

  /// Tilde app: Listen address on server
  ///
  /// In en, this message translates to:
  /// **'Listen address on server'**
  String get listenAddressOnServer;

  /// Tilde app: Listen address on this device
  ///
  /// In en, this message translates to:
  /// **'Listen address on this device'**
  String get listenAddressOnThisDevice;

  /// Tilde app: 127.0.0.1 · accessible only on this device
  ///
  /// In en, this message translates to:
  /// **'127.0.0.1 · accessible only on this device'**
  String get text127001AccessibleOnlyOnThisDevice;

  /// Tilde app: Port
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// Tilde app: Destination address
  ///
  /// In en, this message translates to:
  /// **'Destination address'**
  String get destinationAddress;

  /// Tilde app: Public key
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// Tilde app: Copy fingerprint
  ///
  /// In en, this message translates to:
  /// **'Copy fingerprint'**
  String get copyFingerprint;

  /// Tilde app: Copy public key
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get copyPublicKey;

  /// Tilde app: Key settings
  ///
  /// In en, this message translates to:
  /// **'Key settings'**
  String get keySettings;

  /// Tilde app: Key name
  ///
  /// In en, this message translates to:
  /// **'Key name'**
  String get keyName;

  /// Tilde app: Confirm before use
  ///
  /// In en, this message translates to:
  /// **'Confirm before use'**
  String get confirmBeforeUse;

  /// Tilde app: Ask for permission before authenticating with this key
  ///
  /// In en, this message translates to:
  /// **'Ask for permission before authenticating with this key'**
  String get askForPermissionBeforeAuthenticatingWithThisKey;

  /// Tilde app: Imported private key
  ///
  /// In en, this message translates to:
  /// **'Imported private key'**
  String get importedPrivateKey;

  /// Tilde app: Android Keystore P-256 key
  ///
  /// In en, this message translates to:
  /// **'Android Keystore P-256 key'**
  String get androidKeystoreP256Key;

  /// Tilde app: Authenticate with an imported private key file
  ///
  /// In en, this message translates to:
  /// **'Authenticate with an imported private key file'**
  String get authenticateWithAnImportedPrivateKeyFile;

  /// Tilde app: The private key cannot be exported from this device
  ///
  /// In en, this message translates to:
  /// **'The private key cannot be exported from this device'**
  String get thePrivateKeyCannotBeExportedFromThisDevice;

  /// Tilde app: Disabled legacy private key
  ///
  /// In en, this message translates to:
  /// **'Disabled legacy private key'**
  String get disabledLegacyPrivateKey;

  /// Tilde app: Replace it with a new Android Keystore key before deleting it.
  ///
  /// In en, this message translates to:
  /// **'Replace it with a new Android Keystore key before deleting it.'**
  String get replaceItWithANewAndroidKeystoreKeyBefore;

  /// Tilde app: Connection type
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get connectionType;

  /// Tilde app: {arg0} connections are unsupported. Change to SSH or local.
  ///
  /// In en, this message translates to:
  /// **'{arg0} connections are unsupported. Change to SSH or local.'**
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0);

  /// Tilde app: Host name
  ///
  /// In en, this message translates to:
  /// **'Host name'**
  String get hostName;

  /// Tilde app: Name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Tilde app: Server address
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// Tilde app: Paste user@host:port into the address field to fill in the details.
  ///
  /// In en, this message translates to:
  /// **'Paste user@host:port into the address field to fill in the details.'**
  String get pasteUserHostPortIntoTheAddressFieldTo;

  /// Tilde app: Advanced
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// Tilde app: IP address
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddress;

  /// Tilde app: Automatic
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// Tilde app: Jump host
  ///
  /// In en, this message translates to:
  /// **'Jump host'**
  String get jumpHost;

  /// Tilde app: Direct connection
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get directConnection;

  /// Tilde app: This connection type does not use SSH authentication settings.
  ///
  /// In en, this message translates to:
  /// **'This connection type does not use SSH authentication settings.'**
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings;

  /// Tilde app: Account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Tilde app: Do not use
  ///
  /// In en, this message translates to:
  /// **'Do not use'**
  String get doNotUse;

  /// Tilde app: Using account {arg0}
  ///
  /// In en, this message translates to:
  /// **'Using account {arg0}'**
  String usingAccount(String arg0);

  /// Tilde app: Login key
  ///
  /// In en, this message translates to:
  /// **'Login key'**
  String get loginKey;

  /// Tilde app: Register key on this server
  ///
  /// In en, this message translates to:
  /// **'Register key on this server'**
  String get registerKeyOnThisServer;

  /// Tilde app: Log in once with a password to install the public key
  ///
  /// In en, this message translates to:
  /// **'Log in once with a password to install the public key'**
  String get logInOnceWithAPasswordToInstallThe;

  /// Tilde app: Host color
  ///
  /// In en, this message translates to:
  /// **'Host color'**
  String get hostColor;

  /// Tilde app: Preview in the home list, tabs, and notifications
  ///
  /// In en, this message translates to:
  /// **'Preview in the home list, tabs, and notifications'**
  String get previewInTheHomeListTabsAndNotifications;

  /// Tilde app: Custom host color
  ///
  /// In en, this message translates to:
  /// **'Custom host color'**
  String get customHostColor;

  /// Tilde app: App default · {arg0}
  ///
  /// In en, this message translates to:
  /// **'App default · {arg0}'**
  String appDefault2(String arg0);

  /// Tilde app: Manage profiles
  ///
  /// In en, this message translates to:
  /// **'Manage profiles'**
  String get manageProfiles;

  /// Tilde app: Keep connection alive
  ///
  /// In en, this message translates to:
  /// **'Keep connection alive'**
  String get keepConnectionAlive;

  /// Tilde app: Reconnect automatically after an I/O error
  ///
  /// In en, this message translates to:
  /// **'Reconnect automatically after an I/O error'**
  String get reconnectAutomaticallyAfterAnIOError;

  /// Tilde app: Close without asking
  ///
  /// In en, this message translates to:
  /// **'Close without asking'**
  String get closeWithoutAsking;

  /// Tilde app: Close the tab immediately after exit
  ///
  /// In en, this message translates to:
  /// **'Close the tab immediately after exit'**
  String get closeTheTabImmediatelyAfterExit;

  /// Tilde app: SSH compression
  ///
  /// In en, this message translates to:
  /// **'SSH compression'**
  String get sshCompression;

  /// Tilde app: Enable only on slow connections
  ///
  /// In en, this message translates to:
  /// **'Enable only on slow connections'**
  String get enableOnlyOnSlowConnections;

  /// Tilde app: Open terminal
  ///
  /// In en, this message translates to:
  /// **'Open terminal'**
  String get openTerminal;

  /// Tilde app: When off, only port forwarding is enabled
  ///
  /// In en, this message translates to:
  /// **'When off, only port forwarding is enabled'**
  String get whenOffOnlyPortForwardingIsEnabled;

  /// Tilde app: Override for this host
  ///
  /// In en, this message translates to:
  /// **'Override for this host'**
  String get overrideForThisHost;

  /// Tilde app: Scrollback
  ///
  /// In en, this message translates to:
  /// **'Scrollback'**
  String get scrollback;

  /// Tilde app: Lines · default {arg0}
  ///
  /// In en, this message translates to:
  /// **'Lines · default {arg0}'**
  String linesDefault(String arg0);

  /// Tilde app: Use Ctrl+Alt as Meta
  ///
  /// In en, this message translates to:
  /// **'Use Ctrl+Alt as Meta'**
  String get useCtrlAltAsMeta;

  /// Tilde app: Display and profile
  ///
  /// In en, this message translates to:
  /// **'Display and profile'**
  String get displayAndProfile;

  /// Tilde app: Session
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session2;

  /// Tilde app: Edit host
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get editHost;

  /// Tilde app: Local shell
  ///
  /// In en, this message translates to:
  /// **'Local shell'**
  String get localShell;

  /// Tilde app: Select key
  ///
  /// In en, this message translates to:
  /// **'Select key'**
  String get selectKey;

  /// Tilde app: Connection settings
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get connectionSettings;

  /// Tilde app: Trusted server keys
  ///
  /// In en, this message translates to:
  /// **'Trusted server keys'**
  String get trustedServerKeys;

  /// Tilde app: Name for duplicate
  ///
  /// In en, this message translates to:
  /// **'Name for duplicate'**
  String get nameForDuplicate;

  /// Tilde app: Could not save
  ///
  /// In en, this message translates to:
  /// **'Could not save'**
  String get couldNotSave;

  /// Tilde app: Details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Tilde app: Changed fields
  ///
  /// In en, this message translates to:
  /// **'Changed fields'**
  String get changedFields;

  /// Tilde app: Change password
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// Tilde app: None
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// Tilde app: Saving
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get saving;

  /// Tilde app: Changed {arg0}
  ///
  /// In en, this message translates to:
  /// **'Changed {arg0}'**
  String changed(String arg0);

  /// Tilde app: {arg0} and others
  ///
  /// In en, this message translates to:
  /// **'{arg0} and others'**
  String andOthers(String arg0);

  /// Tilde app: {arg0} items
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String items(num count);

  /// Tilde app: Saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Tilde app: Undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Tilde app: Save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Tilde app: Save and open new terminal
  ///
  /// In en, this message translates to:
  /// **'Save and open new terminal'**
  String get saveAndOpenNewTerminal;

  /// Tilde app: Delete host
  ///
  /// In en, this message translates to:
  /// **'Delete host'**
  String get deleteHost;

  /// Tilde app: Could not save changes
  ///
  /// In en, this message translates to:
  /// **'Could not save changes'**
  String get couldNotSaveChanges;

  /// Tilde app: Add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Tilde app: Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Tilde app: Saving…
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving2;

  /// Tilde app: Apply
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Tilde app: Back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Tilde app: System default
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// Tilde app: App default font
  ///
  /// In en, this message translates to:
  /// **'App default font'**
  String get appDefaultFont;

  /// Tilde app: New SSH key
  ///
  /// In en, this message translates to:
  /// **'New SSH key'**
  String get newSshKey;

  /// Tilde app: Enter a name.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get enterAName;

  /// Tilde app: Create a P-256 private key in Android Keystore and require biometric authentication for each signature. The private key cannot be
  ///
  /// In en, this message translates to:
  /// **'Create a P-256 private key in Android Keystore and require biometric authentication for each signature. The private key cannot be copied, exported, or backed up.'**
  String get createAP256PrivateKeyInAndroidKeystore;

  /// Tilde app: Could not create key
  ///
  /// In en, this message translates to:
  /// **'Could not create key'**
  String get couldNotCreateKey;

  /// Tilde app: Create key
  ///
  /// In en, this message translates to:
  /// **'Create key'**
  String get createKey;

  /// Tilde app: Search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Tilde app: Saving
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get saving3;

  /// Tilde app: {arg0} changes
  ///
  /// In en, this message translates to:
  /// **'{arg0} changes'**
  String changes(String arg0);

  /// Tilde app: Enter a value between {arg0} and {arg1}
  ///
  /// In en, this message translates to:
  /// **'Enter a value between {arg0} and {arg1}'**
  String enterAValueBetweenAnd(String arg0, String arg1);

  /// Tilde app: Decrease {arg0}
  ///
  /// In en, this message translates to:
  /// **'Decrease {arg0}'**
  String decrease(String arg0);

  /// Tilde app: Increase {arg0}
  ///
  /// In en, this message translates to:
  /// **'Increase {arg0}'**
  String increase(String arg0);

  /// Tilde app: Discard changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Tilde app: Unsaved changes will be lost.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes will be lost.'**
  String get unsavedChangesWillBeLost;

  /// Tilde app: Keep editing
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// Tilde app: Discard
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Tilde app: Select color
  ///
  /// In en, this message translates to:
  /// **'Select color'**
  String get selectColor;

  /// Tilde app: Brightness
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// Tilde app: Hex color
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get hexColor;

  /// Tilde app: Enter a six-digit color
  ///
  /// In en, this message translates to:
  /// **'Enter a six-digit color'**
  String get enterASixDigitColor;

  /// Tilde app: Menu
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu2;

  /// Tilde app: Default profile
  ///
  /// In en, this message translates to:
  /// **'Default profile'**
  String get defaultProfile;

  /// Tilde app: The saved connection settings are invalid.
  ///
  /// In en, this message translates to:
  /// **'The saved connection settings are invalid.'**
  String get theSavedConnectionSettingsAreInvalid;

  /// Tilde app: The saved {arg0} settings are invalid.
  ///
  /// In en, this message translates to:
  /// **'The saved {arg0} settings are invalid.'**
  String theSavedSettingsAreInvalid(String arg0);

  /// Tilde app: The saved color theme is invalid.
  ///
  /// In en, this message translates to:
  /// **'The saved color theme is invalid.'**
  String get theSavedColorThemeIsInvalid;

  /// Tilde app: Check the SSH address.
  ///
  /// In en, this message translates to:
  /// **'Check the SSH address.'**
  String get checkTheSshAddress;

  /// Tilde app: Use an SSH host.
  ///
  /// In en, this message translates to:
  /// **'Use an SSH host.'**
  String get useAnSshHost;

  /// Tilde app: This terminal uses UTF-8.
  ///
  /// In en, this message translates to:
  /// **'This terminal uses UTF-8.'**
  String get thisTerminalUsesUtf8;

  /// Tilde app: Color theme not found.
  ///
  /// In en, this message translates to:
  /// **'Color theme not found.'**
  String get colorThemeNotFound;

  /// Tilde app: Enter a theme name.
  ///
  /// In en, this message translates to:
  /// **'Enter a theme name.'**
  String get enterAThemeName;

  /// Tilde app: A theme with this name already exists.
  ///
  /// In en, this message translates to:
  /// **'A theme with this name already exists.'**
  String get aThemeWithThisNameAlreadyExists;

  /// Tilde app: Colors must be three- or six-digit hex values.
  ///
  /// In en, this message translates to:
  /// **'Colors must be three- or six-digit hex values.'**
  String get colorsMustBeThreeOrSixDigitHexValues;

  /// Tilde app: Invalid color theme file format.
  ///
  /// In en, this message translates to:
  /// **'Invalid color theme file format.'**
  String get invalidColorThemeFileFormat;

  /// Tilde app: Default color indices must be between 0 and 15.
  ///
  /// In en, this message translates to:
  /// **'Default color indices must be between 0 and 15.'**
  String get defaultColorIndicesMustBeBetween0And15;

  /// Tilde app: ANSI color indices must be between 0 and 15.
  ///
  /// In en, this message translates to:
  /// **'ANSI color indices must be between 0 and 15.'**
  String get ansiColorIndicesMustBeBetween0And15;

  /// Tilde app: Invalid theme description format.
  ///
  /// In en, this message translates to:
  /// **'Invalid theme description format.'**
  String get invalidThemeDescriptionFormat;

  /// Tilde app: Duplicate the default theme before editing it.
  ///
  /// In en, this message translates to:
  /// **'Duplicate the default theme before editing it.'**
  String get duplicateTheDefaultThemeBeforeEditingIt;

  /// Tilde app: Check the color role.
  ///
  /// In en, this message translates to:
  /// **'Check the color role.'**
  String get checkTheColorRole;

  /// Tilde app: Unsupported theme operation.
  ///
  /// In en, this message translates to:
  /// **'Unsupported theme operation.'**
  String get unsupportedThemeOperation;

  /// Tilde app: Only explicitly confirmed new server keys can be saved.
  ///
  /// In en, this message translates to:
  /// **'Only explicitly confirmed new server keys can be saved.'**
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved;

  /// Tilde app: Only temporary transfer files can be processed.
  ///
  /// In en, this message translates to:
  /// **'Only temporary transfer files can be processed.'**
  String get onlyTemporaryTransferFilesCanBeProcessed;

  /// Tilde app: Check the SSH jump host connection.
  ///
  /// In en, this message translates to:
  /// **'Check the SSH jump host connection.'**
  String get checkTheSshJumpHostConnection;

  /// Tilde app: Enter a server address.
  ///
  /// In en, this message translates to:
  /// **'Enter a server address.'**
  String get enterAServerAddress;

  /// Tilde app: No host to restore.
  ///
  /// In en, this message translates to:
  /// **'No host to restore.'**
  String get noHostToRestore;

  /// Tilde app: This profile is in use.
  ///
  /// In en, this message translates to:
  /// **'This profile is in use.'**
  String get thisProfileIsInUse;

  /// Tilde app: Unsupported link.
  ///
  /// In en, this message translates to:
  /// **'Unsupported link.'**
  String get unsupportedLink;

  /// Tilde app: Key file
  ///
  /// In en, this message translates to:
  /// **'Key file'**
  String get keyFile;

  /// Tilde app: Unsupported operation: {arg0}
  ///
  /// In en, this message translates to:
  /// **'Unsupported operation: {arg0}'**
  String unsupportedOperation(String arg0);

  /// Tilde app: Android Keystore key unavailable
  ///
  /// In en, this message translates to:
  /// **'Android Keystore key unavailable'**
  String get androidKeystoreKeyUnavailable;

  /// Tilde app: Legacy private key · disabled
  ///
  /// In en, this message translates to:
  /// **'Legacy private key · disabled'**
  String get legacyPrivateKeyDisabled;

  /// Tilde app: Toggle keyboard
  ///
  /// In en, this message translates to:
  /// **'Toggle keyboard'**
  String get toggleKeyboard;

  /// Tilde app: End session
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get endSession;

  /// Tilde app: Disconnect from {arg0}?
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {arg0}?'**
  String disconnectFrom(String arg0);

  /// Tilde app: End
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Tilde app: Could not close connection
  ///
  /// In en, this message translates to:
  /// **'Could not close connection'**
  String get couldNotCloseConnection;

  /// Tilde app: No open sessions.
  ///
  /// In en, this message translates to:
  /// **'No open sessions.'**
  String get noOpenSessions;

  /// Tilde app: Disconnected{arg0}
  ///
  /// In en, this message translates to:
  /// **'Disconnected{arg0}'**
  String disconnected2(String arg0);

  /// Tilde app: End {arg0}
  ///
  /// In en, this message translates to:
  /// **'End {arg0}'**
  String end2(String arg0);

  /// Tilde app: New tab
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// Tilde app: Close {arg0}
  ///
  /// In en, this message translates to:
  /// **'Close {arg0}'**
  String close(String arg0);

  /// Tilde app: Image
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// Tilde app: Words
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get words;

  /// Tilde app: First connection to this server
  ///
  /// In en, this message translates to:
  /// **'First connection to this server'**
  String get firstConnectionToThisServer;

  /// Tilde app: Biometric authentication
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication'**
  String get biometricAuthentication;

  /// Tilde app: Log in to {arg0}
  ///
  /// In en, this message translates to:
  /// **'Log in to {arg0}'**
  String logInTo(String arg0);

  /// Tilde app: Server
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// Tilde app: Hide password
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Tilde app: Show password
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tilde app: Save on this device
  ///
  /// In en, this message translates to:
  /// **'Save on this device'**
  String get saveOnThisDevice;

  /// Tilde app: Check that this fingerprint matches the one provided by the server administrator.
  ///
  /// In en, this message translates to:
  /// **'Check that this fingerprint matches the one provided by the server administrator.'**
  String get checkThatThisFingerprintMatchesTheOneProvidedBy;

  /// Tilde app: Fingerprint format
  ///
  /// In en, this message translates to:
  /// **'Fingerprint format'**
  String get fingerprintFormat;

  /// Tilde app: Authenticate with key {arg0}.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with key {arg0}.'**
  String authenticateWithKey(String arg0);

  /// Tilde app: Cancel connection
  ///
  /// In en, this message translates to:
  /// **'Cancel connection'**
  String get cancelConnection;

  /// Tilde app: Reject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Tilde app: Trust and connect
  ///
  /// In en, this message translates to:
  /// **'Trust and connect'**
  String get trustAndConnect;

  /// Tilde app: Log in
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// Tilde app: Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Tilde app: {arg0} waiting for login
  ///
  /// In en, this message translates to:
  /// **'{arg0} waiting for login'**
  String waitingForLogin(String arg0);

  /// Tilde app: Continue login
  ///
  /// In en, this message translates to:
  /// **'Continue login'**
  String get continueLogin;

  /// Tilde app: Paste {arg0} lines?
  ///
  /// In en, this message translates to:
  /// **'Paste {arg0} lines?'**
  String pasteLines(String arg0);

  /// Tilde app: Pasting {arg0} lines into the terminal may run commands immediately.
  ///
  /// In en, this message translates to:
  /// **'Pasting {arg0} lines into the terminal may run commands immediately.'**
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0);

  /// Tilde app: Control characters may trigger terminal actions or command execution.
  ///
  /// In en, this message translates to:
  /// **'Control characters may trigger terminal actions or command execution.'**
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution;

  /// Tilde app: Paste without trailing Enter
  ///
  /// In en, this message translates to:
  /// **'Paste without trailing Enter'**
  String get pasteWithoutTrailingEnter;

  /// Tilde app: Paste {arg0} lines
  ///
  /// In en, this message translates to:
  /// **'Paste {arg0} lines'**
  String pasteLines2(String arg0);

  /// Tilde app: Edit text
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get editText;

  /// Tilde app: Text to send
  ///
  /// In en, this message translates to:
  /// **'Text to send'**
  String get textToSend;

  /// Tilde app: Send
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Tilde app: Select entire line
  ///
  /// In en, this message translates to:
  /// **'Select entire line'**
  String get selectEntireLine;

  /// Tilde app: Select visible screen
  ///
  /// In en, this message translates to:
  /// **'Select visible screen'**
  String get selectVisibleScreen;

  /// Tilde app: Select all
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// Tilde app: Block selection
  ///
  /// In en, this message translates to:
  /// **'Block selection'**
  String get blockSelection;

  /// Tilde app: Share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Tilde app: Paste
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// Tilde app: Copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy2;

  /// Tilde app: Edit and send
  ///
  /// In en, this message translates to:
  /// **'Edit and send'**
  String get editAndSend;

  /// Tilde app: More selection options
  ///
  /// In en, this message translates to:
  /// **'More selection options'**
  String get moreSelectionOptions;

  /// Tilde app: Selection end
  ///
  /// In en, this message translates to:
  /// **'Selection end'**
  String get selectionEnd;

  /// Tilde app: Selection start
  ///
  /// In en, this message translates to:
  /// **'Selection start'**
  String get selectionStart;

  /// Tilde app: Clear selection
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// Tilde app: Could not connect to {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {arg0}'**
  String couldNotConnectTo(String arg0);

  /// Tilde app: Could not complete operation
  ///
  /// In en, this message translates to:
  /// **'Could not complete operation'**
  String get couldNotCompleteOperation;

  /// Tilde app: Could not finish operation
  ///
  /// In en, this message translates to:
  /// **'Could not finish operation'**
  String get couldNotFinishOperation;

  /// Tilde app: Checked · {arg0}
  ///
  /// In en, this message translates to:
  /// **'Checked · {arg0}'**
  String checked(String arg0);

  /// Tilde app: Occurred · {arg0}
  ///
  /// In en, this message translates to:
  /// **'Occurred · {arg0}'**
  String occurred(String arg0);

  /// Tilde app: Copy error log
  ///
  /// In en, this message translates to:
  /// **'Copy error log'**
  String get copyErrorLog;

  /// Tilde app: Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close2;

  /// Tilde app: Save elsewhere
  ///
  /// In en, this message translates to:
  /// **'Save elsewhere'**
  String get saveElsewhere;

  /// Tilde app: Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Tilde app: Deleted host {arg0}
  ///
  /// In en, this message translates to:
  /// **'Deleted host {arg0}'**
  String deletedHost(String arg0);

  /// Tilde app: OK
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Tilde app: {arg0} lines · Enter inserts a newline{arg1}
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} line} other{{count} lines}} · Enter inserts a newline{arg1}'**
  String linesEnterInsertsANewline(num count, String arg1);

  /// Tilde app: , Ctrl Enter sends
  ///
  /// In en, this message translates to:
  /// **', Ctrl Enter sends'**
  String get ctrlEnterSends;

  /// Tilde app:  · {arg0} unsupported
  ///
  /// In en, this message translates to:
  /// **' · {arg0} unsupported'**
  String unsupported(String arg0);

  /// Tilde app: Verify server key for {arg0}
  ///
  /// In en, this message translates to:
  /// **'Verify server key for {arg0}'**
  String verifyServerKeyFor(String arg0);

  /// Tilde app: Trust server key
  ///
  /// In en, this message translates to:
  /// **'Trust server key'**
  String get trustServerKey;

  /// Tilde app: Authenticate with key {arg0}.
  ///
  /// In en, this message translates to:
  /// **'Authenticate with key {arg0}.'**
  String authenticateWithKey2(String arg0);

  /// Tilde app: Disconnect all
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll;

  /// Tilde app: Disconnect all sessions?
  ///
  /// In en, this message translates to:
  /// **'Disconnect all sessions?'**
  String get disconnectAllSessions;

  /// Tilde app: Disconnect all
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll2;

  /// Tilde app: Remove server key?
  ///
  /// In en, this message translates to:
  /// **'Remove server key?'**
  String get removeServerKey;

  /// Tilde app: The server key will be verified again on the next connection.
  ///
  /// In en, this message translates to:
  /// **'The server key will be verified again on the next connection.'**
  String get theServerKeyWillBeVerifiedAgainOnThe;

  /// Tilde app: Delete server key
  ///
  /// In en, this message translates to:
  /// **'Delete server key'**
  String get deleteServerKey;

  /// Tilde app:  · Sessions {arg0}
  ///
  /// In en, this message translates to:
  /// **' · Sessions {arg0}'**
  String sessions(String arg0);

  /// Tilde app: File transfer (SFTP)
  ///
  /// In en, this message translates to:
  /// **'File transfer (SFTP)'**
  String get fileTransferSftp;

  /// Tilde app: Favorites
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Tilde app: Quick connect
  ///
  /// In en, this message translates to:
  /// **'Quick connect'**
  String get quickConnect;

  /// Tilde app: Create SSH key on this device
  ///
  /// In en, this message translates to:
  /// **'Create SSH key on this device'**
  String get createSshKeyOnThisDevice;

  /// Tilde app: Sort
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Tilde app: By color
  ///
  /// In en, this message translates to:
  /// **'By color'**
  String get byColor;

  /// Tilde app: By name
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get byName;

  /// Tilde app: Help
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Tilde app: Unlock
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// Tilde app: Could not prepare app data
  ///
  /// In en, this message translates to:
  /// **'Could not prepare app data'**
  String get couldNotPrepareAppData;

  /// Tilde app: Preparing Tilde
  ///
  /// In en, this message translates to:
  /// **'Preparing Tilde'**
  String get preparingTilde;

  /// Tilde app: Error details
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get errorDetails;

  /// Tilde app: Tilde home directory
  ///
  /// In en, this message translates to:
  /// **'Tilde home directory'**
  String get tildeHomeDirectory;

  /// Tilde app: In progress
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// Tilde app: New output
  ///
  /// In en, this message translates to:
  /// **'New output'**
  String get newOutput;

  /// Tilde app: Error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Tilde app: Not connected
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// Tilde app:  · {arg0} sessions
  ///
  /// In en, this message translates to:
  /// **' · {count, plural, one{{count} session} other{{count} sessions}}'**
  String sessions2(num count);

  /// Tilde app: Connect to your first server
  ///
  /// In en, this message translates to:
  /// **'Connect to your first server'**
  String get connectToYourFirstServer;

  /// Tilde app: Save a host to connect with a double-click next time.
  ///
  /// In en, this message translates to:
  /// **'Save a host to connect with a double-click next time.'**
  String get saveAHostToConnectWithADoubleClick;

  /// Tilde app: Save a server to connect quickly next time.
  ///
  /// In en, this message translates to:
  /// **'Save a server to connect quickly next time.'**
  String get saveAServerToConnectQuicklyNextTime;

  /// Tilde app: Save address, user, and authentication
  ///
  /// In en, this message translates to:
  /// **'Save address, user, and authentication'**
  String get saveAddressUserAndAuthentication;

  /// Tilde app: Connect now
  ///
  /// In en, this message translates to:
  /// **'Connect now'**
  String get connectNow;

  /// Tilde app: Connect by address
  ///
  /// In en, this message translates to:
  /// **'Connect by address'**
  String get connectByAddress;

  /// Tilde app: Enter ssh user@host in the search field and press Enter
  ///
  /// In en, this message translates to:
  /// **'Enter ssh user@host in the search field and press Enter'**
  String get enterSshUserHostInTheSearchFieldAnd;

  /// Tilde app: Private key file such as id_ed25519
  ///
  /// In en, this message translates to:
  /// **'Private key file such as id_ed25519'**
  String get privateKeyFileSuchAsIdEd25519;

  /// Tilde app: Connecting to {arg0}:{arg1}
  ///
  /// In en, this message translates to:
  /// **'Connecting to {arg0}:{arg1}'**
  String connectingTo(String arg0, String arg1);

  /// Tilde app: Negotiating SSH connection
  ///
  /// In en, this message translates to:
  /// **'Negotiating SSH connection'**
  String get negotiatingSshConnection;

  /// Tilde app: Verifying server key
  ///
  /// In en, this message translates to:
  /// **'Verifying server key'**
  String get verifyingServerKey;

  /// Tilde app: Authenticating {arg0}
  ///
  /// In en, this message translates to:
  /// **'Authenticating {arg0}'**
  String authenticating(String arg0);

  /// Tilde app: Authenticated
  ///
  /// In en, this message translates to:
  /// **'Authenticated'**
  String get authenticated;

  /// Tilde app: Opening terminal session
  ///
  /// In en, this message translates to:
  /// **'Opening terminal session'**
  String get openingTerminalSession;

  /// Tilde app: Confirm SSH key use
  ///
  /// In en, this message translates to:
  /// **'Confirm SSH key use'**
  String get confirmSshKeyUse;

  /// Tilde app: SSH private key passphrase
  ///
  /// In en, this message translates to:
  /// **'SSH private key passphrase'**
  String get sshPrivateKeyPassphrase;

  /// Tilde app: Connection blocked because the server key changed. Review and manually remove the saved server key.
  ///
  /// In en, this message translates to:
  /// **'Connection blocked because the server key changed. Review and manually remove the saved server key.'**
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd;

  /// Tilde app: Preparing SSH login
  ///
  /// In en, this message translates to:
  /// **'Preparing SSH login'**
  String get preparingSshLogin;

  /// Tilde app: Logged in, but could not save the password. Save it again in the host editor.
  ///
  /// In en, this message translates to:
  /// **'Logged in, but could not save the password. Save it again in the host editor.'**
  String get loggedInButCouldNotSaveThePasswordSave;

  /// Tilde app: Send to {arg0}
  ///
  /// In en, this message translates to:
  /// **'Send to {arg0}'**
  String sendTo(String arg0);

  /// Tilde app: Send
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send2;

  /// Tilde app: Terminal size
  ///
  /// In en, this message translates to:
  /// **'Terminal size'**
  String get terminalSize;

  /// Tilde app: Columns
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// Tilde app: Rows
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rows;

  /// Tilde app: Full screen
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// Tilde app: Auto-hide title bar
  ///
  /// In en, this message translates to:
  /// **'Auto-hide title bar'**
  String get autoHideTitleBar;

  /// Tilde app: Terminal size · columns×rows
  ///
  /// In en, this message translates to:
  /// **'Terminal size · columns×rows'**
  String get terminalSizeColumnsRows;

  /// Tilde app: Resize
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resize;

  /// Tilde app: 80×24 · leave blank for automatic sizing
  ///
  /// In en, this message translates to:
  /// **'80×24 · leave blank for automatic sizing'**
  String get text8024LeaveBlankForAutomaticSizing;

  /// Tilde app: Enter columns×rows, such as 80×24.
  ///
  /// In en, this message translates to:
  /// **'Enter columns×rows, such as 80×24.'**
  String get enterColumnsRowsSuchAs8024;

  /// Tilde app: Terminal links
  ///
  /// In en, this message translates to:
  /// **'Terminal links'**
  String get terminalLinks;

  /// Tilde app: No links on screen.
  ///
  /// In en, this message translates to:
  /// **'No links on screen.'**
  String get noLinksOnScreen;

  /// Tilde app: Enter text
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get enterText;

  /// Tilde app: Links
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// Tilde app: Reconnect
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// Tilde app: Could not verify server key
  ///
  /// In en, this message translates to:
  /// **'Could not verify server key'**
  String get couldNotVerifyServerKey;

  /// Tilde app: Could not log in
  ///
  /// In en, this message translates to:
  /// **'Could not log in'**
  String get couldNotLogIn;

  /// Tilde app: Could not open terminal
  ///
  /// In en, this message translates to:
  /// **'Could not open terminal'**
  String get couldNotOpenTerminal;

  /// Tilde app: Could not connect to server
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server'**
  String get couldNotConnectToServer;

  /// Tilde app: Connecting to {arg0}
  ///
  /// In en, this message translates to:
  /// **'Connecting to {arg0}'**
  String connectingTo2(String arg0);

  /// Tilde app: Check the saved server key and the fingerprint provided by the server administrator.
  ///
  /// In en, this message translates to:
  /// **'Check the saved server key and the fingerprint provided by the server administrator.'**
  String get checkTheSavedServerKeyAndTheFingerprintProvided;

  /// Tilde app: Check your username and credentials. If using an SSH key, register the public key on the server.
  ///
  /// In en, this message translates to:
  /// **'Check your username and credentials. If using an SSH key, register the public key on the server.'**
  String get checkYourUsernameAndCredentialsIfUsingAnSsh;

  /// Tilde app: Check the server address, port, and network connection.
  ///
  /// In en, this message translates to:
  /// **'Check the server address, port, and network connection.'**
  String get checkTheServerAddressPortAndNetworkConnection;

  /// Tilde app: Connection log
  ///
  /// In en, this message translates to:
  /// **'Connection log'**
  String get connectionLog;

  /// Tilde app: Device list
  ///
  /// In en, this message translates to:
  /// **'Device list'**
  String get deviceList;

  /// Tilde app: View
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Tilde app: Dismiss banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss banner'**
  String get dismissBanner;

  /// Tilde app: Connection closed
  ///
  /// In en, this message translates to:
  /// **'Connection closed'**
  String get connectionClosed;

  /// Tilde app: The server ended the session
  ///
  /// In en, this message translates to:
  /// **'The server ended the session'**
  String get theServerEndedTheSession;

  /// Tilde app: Connection ended after authentication failed
  ///
  /// In en, this message translates to:
  /// **'Connection ended after authentication failed'**
  String get connectionEndedAfterAuthenticationFailed;

  /// Tilde app: Connection lost
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// Tilde app: Ended · {arg0}
  ///
  /// In en, this message translates to:
  /// **'Ended · {arg0}'**
  String ended(String arg0);

  /// Tilde app: Copy output
  ///
  /// In en, this message translates to:
  /// **'Copy output'**
  String get copyOutput;

  /// Tilde app: {arg0} SSH key
  ///
  /// In en, this message translates to:
  /// **'{arg0} SSH key'**
  String sshKey(String arg0);

  /// Tilde app: Could not prepare registration
  ///
  /// In en, this message translates to:
  /// **'Could not prepare registration'**
  String get couldNotPrepareRegistration;

  /// Tilde app: Key to register
  ///
  /// In en, this message translates to:
  /// **'Key to register'**
  String get keyToRegister;

  /// Tilde app: New biometric key
  ///
  /// In en, this message translates to:
  /// **'New biometric key'**
  String get newBiometricKey;

  /// Tilde app: Create new SSH key
  ///
  /// In en, this message translates to:
  /// **'Create new SSH key'**
  String get createNewSshKey;

  /// Tilde app: Register SSH key login
  ///
  /// In en, this message translates to:
  /// **'Register SSH key login'**
  String get registerSshKeyLogin;

  /// Tilde app: {arg0} key registration{arg1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} key registration{arg1}'**
  String keyRegistration(String arg0, String arg1);

  /// Tilde app: Another host
  ///
  /// In en, this message translates to:
  /// **'Another host'**
  String get anotherHost;

  /// Tilde app:  is in progress
  ///
  /// In en, this message translates to:
  /// **' is in progress'**
  String get isInProgress;

  /// Tilde app:  is complete
  ///
  /// In en, this message translates to:
  /// **' is complete'**
  String get isComplete;

  /// Tilde app: Registration preparation for this host
  ///
  /// In en, this message translates to:
  /// **'Registration preparation for this host'**
  String get registrationPreparationForThisHost;

  /// Tilde app: Install the public key, then verify key login with a separate connection.
  ///
  /// In en, this message translates to:
  /// **'Install the public key, then verify key login with a separate connection.'**
  String get installThePublicKeyThenVerifyKeyLoginWith;

  /// Tilde app: New key name
  ///
  /// In en, this message translates to:
  /// **'New key name'**
  String get newKeyName;

  /// Tilde app: Progress
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Tilde app: Install public key
  ///
  /// In en, this message translates to:
  /// **'Install public key'**
  String get installPublicKey;

  /// Tilde app: Verify key login
  ///
  /// In en, this message translates to:
  /// **'Verify key login'**
  String get verifyKeyLogin;

  /// Tilde app: Apply to host
  ///
  /// In en, this message translates to:
  /// **'Apply to host'**
  String get applyToHost;

  /// Tilde app: The server rejected the key
  ///
  /// In en, this message translates to:
  /// **'The server rejected the key'**
  String get theServerRejectedTheKey;

  /// Tilde app: The server requires additional authentication
  ///
  /// In en, this message translates to:
  /// **'The server requires additional authentication'**
  String get theServerRequiresAdditionalAuthentication;

  /// Tilde app: Could not complete this step
  ///
  /// In en, this message translates to:
  /// **'Could not complete this step'**
  String get couldNotCompleteThisStep;

  /// Tilde app: Installed on server
  ///
  /// In en, this message translates to:
  /// **'Installed on server'**
  String get installedOnServer;

  /// Tilde app: Key already installed
  ///
  /// In en, this message translates to:
  /// **'Key already installed'**
  String get keyAlreadyInstalled;

  /// Tilde app: Key login verified
  ///
  /// In en, this message translates to:
  /// **'Key login verified'**
  String get keyLoginVerified;

  /// Tilde app: The server rejected this key
  ///
  /// In en, this message translates to:
  /// **'The server rejected this key'**
  String get theServerRejectedThisKey;

  /// Tilde app: Registration complete
  ///
  /// In en, this message translates to:
  /// **'Registration complete'**
  String get registrationComplete;

  /// Tilde app: Using key {arg0}
  ///
  /// In en, this message translates to:
  /// **'Using key {arg0}'**
  String usingKey(String arg0);

  /// Tilde app: Remove saved password for this host
  ///
  /// In en, this message translates to:
  /// **'Remove saved password for this host'**
  String get removeSavedPasswordForThisHost;

  /// Tilde app: Register and verify
  ///
  /// In en, this message translates to:
  /// **'Register and verify'**
  String get registerAndVerify;

  /// Tilde app: Continue in background
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get continueInBackground;

  /// Tilde app: Preview color theme, font, and margins
  ///
  /// In en, this message translates to:
  /// **'Preview color theme, font, and margins'**
  String get previewColorThemeFontAndMargins;

  /// Tilde app:  src  build  sample.md
  ///
  /// In en, this message translates to:
  /// **'\nsrc  build  sample.md'**
  String get srcBuildSampleMd;

  /// Tilde app: Special key bar preview
  ///
  /// In en, this message translates to:
  /// **'Special key bar preview'**
  String get specialKeyBarPreview;

  /// Tilde app: File transfer is available for SSH hosts.
  ///
  /// In en, this message translates to:
  /// **'File transfer is available for SSH hosts.'**
  String get fileTransferIsAvailableForSshHosts;

  /// Tilde app: Register a key from a connected SSH session.
  ///
  /// In en, this message translates to:
  /// **'Register a key from a connected SSH session.'**
  String get registerAKeyFromAConnectedSshSession;

  /// Tilde app: Only SSH and local connections are supported.
  ///
  /// In en, this message translates to:
  /// **'Only SSH and local connections are supported.'**
  String get onlySshAndLocalConnectionsAreSupported;

  /// Tilde app: The connection type changed. Open a new session from Home.
  ///
  /// In en, this message translates to:
  /// **'The connection type changed. Open a new session from Home.'**
  String get theConnectionTypeChangedOpenANewSessionFrom;

  /// Tilde app: Calculating time remaining
  ///
  /// In en, this message translates to:
  /// **'Calculating time remaining'**
  String get calculatingTimeRemaining;

  /// Tilde app: {arg0}m {arg1}s remaining
  ///
  /// In en, this message translates to:
  /// **'{arg0}m {arg1}s remaining'**
  String minutesSecondsRemaining(String arg0, String arg1);

  /// Tilde app: {arg0}s remaining
  ///
  /// In en, this message translates to:
  /// **'{arg0}s remaining'**
  String secondsRemaining(String arg0);

  /// Tilde app: {arg0} · Cancelling…
  ///
  /// In en, this message translates to:
  /// **'{arg0} · Cancelling…'**
  String cancelling(String arg0);

  /// Tilde app: Checking size
  ///
  /// In en, this message translates to:
  /// **'Checking size'**
  String get checkingSize;

  /// Tilde app: Calculating speed
  ///
  /// In en, this message translates to:
  /// **'Calculating speed'**
  String get calculatingSpeed;

  /// Tilde app: Active {arg0}
  ///
  /// In en, this message translates to:
  /// **'Active {arg0}'**
  String active(String arg0);

  /// Tilde app: Queued {arg0}
  ///
  /// In en, this message translates to:
  /// **'Queued {arg0}'**
  String queued(String arg0);

  /// Tilde app: Failed {arg0}
  ///
  /// In en, this message translates to:
  /// **'Failed {arg0}'**
  String failed(String arg0);

  /// Tilde app: Completed {arg0}
  ///
  /// In en, this message translates to:
  /// **'Completed {arg0}'**
  String completed(String arg0);

  /// Tilde app: Cancelled {arg0}
  ///
  /// In en, this message translates to:
  /// **'Cancelled {arg0}'**
  String cancelled(String arg0);

  /// Tilde app: No transfers
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get noTransfers;

  /// Tilde app: Queued
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued2;

  /// Tilde app: Paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// Tilde app: Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed2;

  /// Tilde app: Failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed2;

  /// Tilde app: Cancel operation
  ///
  /// In en, this message translates to:
  /// **'Cancel operation'**
  String get cancelOperation;

  /// Tilde app: Open folder
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// Tilde app: Could not complete {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not complete {arg0}'**
  String couldNotComplete(String arg0);

  /// Tilde app: {arg0} / {arg1} items{arg2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} items{arg2}'**
  String items2(String arg0, String arg1, String arg2);

  /// Tilde app: Transfer · {arg0}
  ///
  /// In en, this message translates to:
  /// **'Transfer · {arg0}'**
  String transfer(String arg0);

  /// Tilde app: Transfer queue
  ///
  /// In en, this message translates to:
  /// **'Transfer queue'**
  String get transferQueue;

  /// Tilde app: Clear completed
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompleted;

  /// Tilde app: Collapse transfer queue
  ///
  /// In en, this message translates to:
  /// **'Collapse transfer queue'**
  String get collapseTransferQueue;

  /// Tilde app: Expand transfer queue
  ///
  /// In en, this message translates to:
  /// **'Expand transfer queue'**
  String get expandTransferQueue;

  /// Tilde app: All
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Tilde app: Select a regular file.
  ///
  /// In en, this message translates to:
  /// **'Select a regular file.'**
  String get selectARegularFile;

  /// Tilde app: A file with the same name already exists.
  ///
  /// In en, this message translates to:
  /// **'A file with the same name already exists.'**
  String get aFileWithTheSameNameAlreadyExists;

  /// Tilde app: The source file size changed during transfer.
  ///
  /// In en, this message translates to:
  /// **'The source file size changed during transfer.'**
  String get theSourceFileSizeChangedDuringTransfer;

  /// Tilde app: A file with the same name appeared during transfer.
  ///
  /// In en, this message translates to:
  /// **'A file with the same name appeared during transfer.'**
  String get aFileWithTheSameNameAppearedDuringTransfer;

  /// Tilde app: Could not remove the temporary upload file. Check the server. {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not remove the temporary upload file. Check the server. {arg0}'**
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0);

  /// Tilde app: Could not inspect the temporary upload file. Check the server. {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not inspect the temporary upload file. Check the server. {arg0}'**
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0);

  /// Tilde app: Change permissions
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get changePermissions;

  /// Tilde app: Read
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// Tilde app: Write
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get write;

  /// Tilde app: Execute
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get execute;

  /// Tilde app: Owner
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// Tilde app: Group
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// Tilde app: Other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// Tilde app: Octal permissions
  ///
  /// In en, this message translates to:
  /// **'Octal permissions'**
  String get octalPermissions;

  /// Tilde app: Enter three or four digits from 0 to 7.
  ///
  /// In en, this message translates to:
  /// **'Enter three or four digits from 0 to 7.'**
  String get enterThreeOrFourDigitsFrom0To7;

  /// Tilde app: Change permissions
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get changePermissions2;

  /// Tilde app: Could not open folder. Check the path and permissions. {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not open folder. Check the path and permissions.\n{arg0}'**
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0);

  /// Tilde app: New folder
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// Tilde app: Create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Tilde app: Destination folder
  ///
  /// In en, this message translates to:
  /// **'Destination folder'**
  String get destinationFolder;

  /// Tilde app: Move {arg0}
  ///
  /// In en, this message translates to:
  /// **'Move {arg0}'**
  String move(String arg0);

  /// Tilde app: Move {arg0} items
  ///
  /// In en, this message translates to:
  /// **'Move {arg0} items'**
  String moveItems(String arg0);

  /// Tilde app: Parent folder
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get parentFolder;

  /// Tilde app: Folder path
  ///
  /// In en, this message translates to:
  /// **'Folder path'**
  String get folderPath;

  /// Tilde app: Edit path
  ///
  /// In en, this message translates to:
  /// **'Edit path'**
  String get editPath;

  /// Tilde app: Move here
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get moveHere;

  /// Tilde app: Permanently delete {arg0} items?
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {arg0} items?'**
  String permanentlyDeleteItems(String arg0);

  /// Tilde app: {arg0} child items
  ///
  /// In en, this message translates to:
  /// **'{arg0} child items'**
  String childItems(String arg0);

  /// Tilde app: Checking contents…
  ///
  /// In en, this message translates to:
  /// **'Checking contents…'**
  String get checkingContents;

  /// Tilde app: Could not inspect folder contents. Try again.
  ///
  /// In en, this message translates to:
  /// **'Could not inspect folder contents. Try again.'**
  String get couldNotInspectFolderContentsTryAgain;

  /// Tilde app: Delete all {arg0} items, including folder contents. This cannot be undone.
  ///
  /// In en, this message translates to:
  /// **'Delete all {arg0} items, including folder contents. This cannot be undone.'**
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0);

  /// Tilde app: Delete immediately without using Trash. This cannot be undone.
  ///
  /// In en, this message translates to:
  /// **'Delete immediately without using Trash. This cannot be undone.'**
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone;

  /// Tilde app: Delete permanently
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// Tilde app: Unknown modification date
  ///
  /// In en, this message translates to:
  /// **'Unknown modification date'**
  String get unknownModificationDate;

  /// Tilde app: A file with the same name exists
  ///
  /// In en, this message translates to:
  /// **'A file with the same name exists'**
  String get aFileWithTheSameNameExists;

  /// Tilde app: Transferring {arg0} / {arg1} items
  ///
  /// In en, this message translates to:
  /// **'Transferring {arg0} / {arg1} items'**
  String transferringItems(String arg0, String arg1);

  /// Tilde app: Choose which file to keep for each conflict.
  ///
  /// In en, this message translates to:
  /// **'Choose which file to keep for each conflict.'**
  String get chooseWhichFileToKeepForEachConflict;

  /// Tilde app: File being uploaded
  ///
  /// In en, this message translates to:
  /// **'File being uploaded'**
  String get fileBeingUploaded;

  /// Tilde app: File being downloaded
  ///
  /// In en, this message translates to:
  /// **'File being downloaded'**
  String get fileBeingDownloaded;

  /// Tilde app: Existing file on server
  ///
  /// In en, this message translates to:
  /// **'Existing file on server'**
  String get existingFileOnServer;

  /// Tilde app: Existing file on device
  ///
  /// In en, this message translates to:
  /// **'Existing file on device'**
  String get existingFileOnDevice;

  /// Tilde app: Unknown size
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get unknownSize;

  /// Tilde app: Keep the existing file and skip copying this file.
  ///
  /// In en, this message translates to:
  /// **'Keep the existing file and skip copying this file.'**
  String get keepTheExistingFileAndSkipCopyingThisFile;

  /// Tilde app: Keep both. Add the first available number, starting at (1), before the copied file extension.
  ///
  /// In en, this message translates to:
  /// **'Keep both. Add the first available number, starting at (1), before the copied file extension.'**
  String get keepBothAddTheFirstAvailableNumberStartingAt;

  /// Tilde app: Overwrite the existing file with the copied file. This cannot be undone.
  ///
  /// In en, this message translates to:
  /// **'Overwrite the existing file with the copied file. This cannot be undone.'**
  String get overwriteTheExistingFileWithTheCopiedFileThis;

  /// Tilde app: Cancel copying. Keep the existing file.
  ///
  /// In en, this message translates to:
  /// **'Cancel this copy job, including its remaining files. Keep the existing files.'**
  String get cancelCopyingKeepTheExistingFile;

  /// Tilde app: Apply to {arg0} remaining items
  ///
  /// In en, this message translates to:
  /// **'Apply to {arg0} remaining items'**
  String applyToRemainingItems(String arg0);

  /// Tilde app: Cancel transfer
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get cancelTransfer;

  /// Tilde app: Cancel copy
  ///
  /// In en, this message translates to:
  /// **'Cancel copy'**
  String get cancelCopy;

  /// Tilde app: Logging in for file transfer
  ///
  /// In en, this message translates to:
  /// **'Logging in for file transfer'**
  String get loggingInForFileTransfer;

  /// Tilde app: Could not log in for file transfer.
  ///
  /// In en, this message translates to:
  /// **'Could not log in for file transfer.'**
  String get couldNotLogInForFileTransfer;

  /// Tilde app: Preview supports files up to 4 MiB. Download the file to open it.
  ///
  /// In en, this message translates to:
  /// **'Preview supports files up to 4 MiB. Download the file to open it.'**
  String get previewSupportsFilesUpTo4MibDownloadThe;

  /// Tilde app: Save file
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get saveFile;

  /// Tilde app: The editor cannot overwrite folders or symbolic links.
  ///
  /// In en, this message translates to:
  /// **'The editor cannot overwrite folders or symbolic links.'**
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks;

  /// Tilde app: Server file changed
  ///
  /// In en, this message translates to:
  /// **'Server file changed'**
  String get serverFileChanged;

  /// Tilde app: {arg0} The server file changed after editing began. Overwrite it?
  ///
  /// In en, this message translates to:
  /// **'{arg0}\nThe server file changed after editing began. Overwrite it?'**
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0);

  /// Tilde app: {arg0} Overwrite the existing file?
  ///
  /// In en, this message translates to:
  /// **'{arg0}\nOverwrite the existing file?'**
  String overwriteTheExistingFile(String arg0);

  /// Tilde app: Overwrite
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// Tilde app: Could not reconnect to the server. Check authentication in the file browser.
  ///
  /// In en, this message translates to:
  /// **'Could not reconnect to the server. Check authentication in the file browser.'**
  String get couldNotReconnectToTheServerCheckAuthenticationIn;

  /// Tilde app: Save a copy elsewhere
  ///
  /// In en, this message translates to:
  /// **'Save a copy elsewhere'**
  String get saveACopyElsewhere;

  /// Tilde app: Save copy
  ///
  /// In en, this message translates to:
  /// **'Save copy'**
  String get saveCopy;

  /// Tilde app: Enter an absolute path including the file name.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute path including the file name.'**
  String get enterAnAbsolutePathIncludingTheFileName;

  /// Tilde app: Enter a path different from the original.
  ///
  /// In en, this message translates to:
  /// **'Enter a path different from the original.'**
  String get enterAPathDifferentFromTheOriginal;

  /// Tilde app: New file
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFile;

  /// Tilde app: An item with the same name already exists.
  ///
  /// In en, this message translates to:
  /// **'An item with the same name already exists.'**
  String get anItemWithTheSameNameAlreadyExists;

  /// Tilde app: This item is being transferred.
  ///
  /// In en, this message translates to:
  /// **'This item is being transferred.'**
  String get thisItemIsBeingTransferred;

  /// Tilde app: Rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Tilde app: Change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Tilde app: Creating folder
  ///
  /// In en, this message translates to:
  /// **'Creating folder'**
  String get creatingFolder;

  /// Tilde app: Folder created.
  ///
  /// In en, this message translates to:
  /// **'Folder created.'**
  String get folderCreated;

  /// Tilde app: Deleting
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get deleting;

  /// Tilde app: Deleting {arg0} items
  ///
  /// In en, this message translates to:
  /// **'Deleting {arg0} items'**
  String deletingItems(String arg0);

  /// Tilde app: Deleted {arg0} items.
  ///
  /// In en, this message translates to:
  /// **'Deleted {arg0} items.'**
  String deletedItems(String arg0);

  /// Tilde app:  · {arg0} items were deleted.
  ///
  /// In en, this message translates to:
  /// **' · {arg0} items were deleted.'**
  String itemsWereDeleted(String arg0);

  /// Tilde app: Changing permissions
  ///
  /// In en, this message translates to:
  /// **'Changing permissions'**
  String get changingPermissions;

  /// Tilde app: Symbolic link permissions will not be changed.
  ///
  /// In en, this message translates to:
  /// **'Symbolic link permissions will not be changed.'**
  String get symbolicLinkPermissionsWillNotBeChanged;

  /// Tilde app: Permissions changed.
  ///
  /// In en, this message translates to:
  /// **'Permissions changed.'**
  String get permissionsChanged;

  /// Tilde app: Operation cancelled.{arg0}
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled.{arg0}'**
  String operationCancelled(String arg0);

  /// Tilde app: Could not complete operation.{arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not complete operation.{arg0}'**
  String couldNotCompleteOperation2(String arg0);

  /// Tilde app: {arg0} items: {arg1} · Paste in the destination folder.
  ///
  /// In en, this message translates to:
  /// **'{arg0} items: {arg1} · Paste in the destination folder.'**
  String itemsPasteInTheDestinationFolder(String arg0, String arg1);

  /// Tilde app: Cut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// Tilde app: No files to paste.
  ///
  /// In en, this message translates to:
  /// **'No files to paste.'**
  String get noFilesToPaste;

  /// Tilde app: Cannot move or copy to the same location or inside the source folder.
  ///
  /// In en, this message translates to:
  /// **'Cannot move or copy to the same location or inside the source folder.'**
  String get cannotMoveOrCopyToTheSameLocationOr;

  /// Tilde app: Move
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move2;

  /// Tilde app: Copy (temporary download and upload)
  ///
  /// In en, this message translates to:
  /// **'Copy (temporary download and upload)'**
  String get copyTemporaryDownloadAndUpload;

  /// Tilde app: Upload
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// Tilde app: Download
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Tilde app: Choosing a folder destination is unsupported on this platform.
  ///
  /// In en, this message translates to:
  /// **'Choosing a folder destination is unsupported on this platform.'**
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform;

  /// Tilde app: Connection closed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed.'**
  String get connectionClosed2;

  /// Tilde app: Download to file manager
  ///
  /// In en, this message translates to:
  /// **'Download to file manager'**
  String get downloadToFileManager;

  /// Tilde app: The temporary export path already exists.
  ///
  /// In en, this message translates to:
  /// **'The temporary export path already exists.'**
  String get theTemporaryExportPathAlreadyExists;

  /// Tilde app: Cancel transfers and close
  ///
  /// In en, this message translates to:
  /// **'Cancel transfers and close'**
  String get cancelTransfersAndClose;

  /// Tilde app: Cancel active transfers and queued operations in this tab?
  ///
  /// In en, this message translates to:
  /// **'Cancel active transfers and queued operations in this tab?'**
  String get cancelActiveTransfersAndQueuedOperationsInThisTab;

  /// Tilde app: Upload folder
  ///
  /// In en, this message translates to:
  /// **'Upload folder'**
  String get uploadFolder;

  /// Tilde app: Connection cancelled
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled'**
  String get connectionCancelled;

  /// Tilde app: Could not open file list
  ///
  /// In en, this message translates to:
  /// **'Could not open file list'**
  String get couldNotOpenFileList;

  /// Tilde app: {arg0} · File transfer
  ///
  /// In en, this message translates to:
  /// **'{arg0} · File transfer'**
  String fileTransfer2(String arg0);

  /// Tilde app: File list
  ///
  /// In en, this message translates to:
  /// **'File list'**
  String get fileList;

  /// Tilde app: Check the folder path and permissions, then try again.
  ///
  /// In en, this message translates to:
  /// **'Check the folder path and permissions, then try again.'**
  String get checkTheFolderPathAndPermissionsThenTryAgain;

  /// Tilde app: Bookmark current folder
  ///
  /// In en, this message translates to:
  /// **'Bookmark current folder'**
  String get bookmarkCurrentFolder;

  /// Tilde app: Recent locations
  ///
  /// In en, this message translates to:
  /// **'Recent locations'**
  String get recentLocations;

  /// Tilde app: {arg0} selected
  ///
  /// In en, this message translates to:
  /// **'{arg0} selected'**
  String selected(String arg0);

  /// Tilde app: Forward
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// Tilde app: Remote folder path
  ///
  /// In en, this message translates to:
  /// **'Remote folder path'**
  String get remoteFolderPath;

  /// Tilde app: Bookmarks and recent locations
  ///
  /// In en, this message translates to:
  /// **'Bookmarks and recent locations'**
  String get bookmarksAndRecentLocations;

  /// Tilde app: Refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Tilde app: Find in current folder
  ///
  /// In en, this message translates to:
  /// **'Find in current folder'**
  String get findInCurrentFolder;

  /// Tilde app: Read only
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get readOnly;

  /// Tilde app: Discard changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges2;

  /// Tilde app: {arg0} Discard unsaved changes?
  ///
  /// In en, this message translates to:
  /// **'{arg0}\nDiscard unsaved changes?'**
  String discardUnsavedChanges(String arg0);

  /// Tilde app: Do not save
  ///
  /// In en, this message translates to:
  /// **'Do not save'**
  String get doNotSave;

  /// Tilde app: Editing
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get editing;

  /// Tilde app: Save copy · keep original unchanged
  ///
  /// In en, this message translates to:
  /// **'Save copy · keep original unchanged'**
  String get saveCopyKeepOriginalUnchanged;

  /// Tilde app: Saved a copy to {arg0}.
  ///
  /// In en, this message translates to:
  /// **'Saved a copy to {arg0}.'**
  String savedACopyTo(String arg0);

  /// Tilde app: Saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved2;

  /// Tilde app: Could not open file
  ///
  /// In en, this message translates to:
  /// **'Could not open file'**
  String get couldNotOpenFile;

  /// Tilde app: Could not open {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not open {arg0}'**
  String couldNotOpen(String arg0);

  /// Tilde app: Preview is unsupported for this file type.
  ///
  /// In en, this message translates to:
  /// **'Preview is unsupported for this file type.'**
  String get previewIsUnsupportedForThisFileType;

  /// Tilde app: Could not save. Your changes have been kept.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Your changes have been kept.'**
  String get couldNotSaveYourChangesHaveBeenKept;

  /// Tilde app: Could not save {arg0}
  ///
  /// In en, this message translates to:
  /// **'Could not save {arg0}'**
  String couldNotSave2(String arg0);

  /// Tilde app:  · UTF-8{arg0} · {arg1} lines · {arg2} B
  ///
  /// In en, this message translates to:
  /// **' · UTF-8{arg0} · {arg1} lines · {arg2} B'**
  String utf8LineBytes(String arg0, String arg1, String arg2);

  /// Tilde app: Unsupported file type.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type.'**
  String get unsupportedFileType;

  /// Tilde app: Unsupported remote file type.
  ///
  /// In en, this message translates to:
  /// **'Unsupported remote file type.'**
  String get unsupportedRemoteFileType;

  /// Tilde app: The transfer source changed. Start a new transfer.
  ///
  /// In en, this message translates to:
  /// **'The transfer source changed. Start a new transfer.'**
  String get theTransferSourceChangedStartANewTransfer;

  /// Tilde app: An item with this name exists and is not a folder.
  ///
  /// In en, this message translates to:
  /// **'An item with this name exists and is not a folder.'**
  String get anItemWithThisNameExistsAndIsNot;

  /// Tilde app: Cannot overwrite a folder with a file.
  ///
  /// In en, this message translates to:
  /// **'Cannot overwrite a folder with a file.'**
  String get cannotOverwriteAFolderWithAFile;

  /// Tilde app: Names cannot contain path separators or be . or ...
  ///
  /// In en, this message translates to:
  /// **'Names cannot contain path separators or be . or ...'**
  String get namesCannotContainPathSeparatorsOrBeOr;

  /// Tilde app: A file or folder with the same name already exists.
  ///
  /// In en, this message translates to:
  /// **'A file or folder with the same name already exists.'**
  String get aFileOrFolderWithTheSameNameAlready;

  /// Tilde app: Cannot move a folder into itself or its descendants.
  ///
  /// In en, this message translates to:
  /// **'Cannot move a folder into itself or its descendants.'**
  String get cannotMoveAFolderIntoItselfOrItsDescendants;

  /// Tilde app: Cannot delete the root folder.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the root folder.'**
  String get cannotDeleteTheRootFolder;

  /// Tilde app: The server denied access. Check the destination path permissions.
  ///
  /// In en, this message translates to:
  /// **'The server denied access. Check the destination path permissions.'**
  String get theServerDeniedAccessCheckTheDestinationPathPermissions;

  /// Tilde app: The file or folder no longer exists.
  ///
  /// In en, this message translates to:
  /// **'The file or folder no longer exists.'**
  String get theFileOrFolderNoLongerExists;

  /// Tilde app: Server connection lost.
  ///
  /// In en, this message translates to:
  /// **'Server connection lost.'**
  String get serverConnectionLost;

  /// Tilde app: The server could not complete the operation.
  ///
  /// In en, this message translates to:
  /// **'The server could not complete the operation.'**
  String get theServerCouldNotCompleteTheOperation;

  /// Tilde app: The server is not responding. Check the address and network.
  ///
  /// In en, this message translates to:
  /// **'The server is not responding. Check the address and network.'**
  String get theServerIsNotRespondingCheckTheAddressAnd;

  /// Tilde app: The server did not authenticate you. Check your username, key, and password.
  ///
  /// In en, this message translates to:
  /// **'The server did not authenticate you. Check your username, key, and password.'**
  String get theServerDidNotAuthenticateYouCheckYourUsername;

  /// Tilde app: The server refused the connection {arg0}. Check SSH and port settings.
  ///
  /// In en, this message translates to:
  /// **'The server refused the connection {arg0}. Check SSH and port settings.'**
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0);

  /// Tilde app:  on port {arg0}
  ///
  /// In en, this message translates to:
  /// **' on port {arg0}'**
  String onPort(String arg0);

  /// Tilde app: Check the server connection.
  ///
  /// In en, this message translates to:
  /// **'Could not communicate with the server. Check your network connection.'**
  String get checkTheServerConnection;

  /// Tilde app: Unexpected error. Copy the details below and contact support.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Copy the details below and contact support.'**
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport;

  /// Tilde app: Transfer cancelled.
  ///
  /// In en, this message translates to:
  /// **'Transfer cancelled.'**
  String get transferCancelled;

  /// Tilde app: Invalid file name.
  ///
  /// In en, this message translates to:
  /// **'Invalid file name.'**
  String get invalidFileName;

  /// Tilde app: The file was not received completely.
  ///
  /// In en, this message translates to:
  /// **'The file was not received completely.'**
  String get theFileWasNotReceivedCompletely;

  /// Tilde app: Size
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// Tilde app: Modified
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modified;

  /// Tilde app: Permissions
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// Tilde app: Owner UID
  ///
  /// In en, this message translates to:
  /// **'Owner UID'**
  String get ownerUid;

  /// Tilde app: Group GID
  ///
  /// In en, this message translates to:
  /// **'Group GID'**
  String get groupGid;

  /// Tilde app: Show hidden files and folders
  ///
  /// In en, this message translates to:
  /// **'Show hidden files and folders'**
  String get showHiddenFilesAndFolders;

  /// Tilde app: Descending
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// Tilde app: Visible columns
  ///
  /// In en, this message translates to:
  /// **'Visible columns'**
  String get visibleColumns;

  /// Tilde app: Preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// Tilde app: Move…
  ///
  /// In en, this message translates to:
  /// **'Move…'**
  String get move3;

  /// Tilde app: Copy path
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// Tilde app: Info
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// Tilde app: Change permissions…
  ///
  /// In en, this message translates to:
  /// **'Change permissions…'**
  String get changePermissions3;

  /// Tilde app: File information
  ///
  /// In en, this message translates to:
  /// **'File information'**
  String get fileInformation;

  /// Tilde app: Path
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// Tilde app: Type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type2;

  /// Tilde app: Folder
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// Tilde app: Symbolic link
  ///
  /// In en, this message translates to:
  /// **'Symbolic link'**
  String get symbolicLink;

  /// Tilde app: File
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Tilde app: Clear search
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Tilde app: Location
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Tilde app: {arg0} selected · {arg1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} selected · {arg1}'**
  String selected2(String arg0, String arg1);

  /// Tilde app: Parent folder (Backspace)
  ///
  /// In en, this message translates to:
  /// **'Parent folder (Backspace)'**
  String get parentFolderBackspace;

  /// Tilde app: Loading…
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Tilde app: No files to display.
  ///
  /// In en, this message translates to:
  /// **'No files to display.'**
  String get noFilesToDisplay;

  /// Tilde app: No matching files.
  ///
  /// In en, this message translates to:
  /// **'No matching files.'**
  String get noMatchingFiles;

  /// Tilde app: Apply new name
  ///
  /// In en, this message translates to:
  /// **'Apply new name'**
  String get applyNewName;

  /// Tilde app: {arg0} actions
  ///
  /// In en, this message translates to:
  /// **'{arg0} actions'**
  String actions(String arg0);

  /// Tilde app: {arg0} items{arg1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} items{arg1}'**
  String items3(String arg0, String arg1);

  /// Tilde app:  · {arg0} hidden/filtered
  ///
  /// In en, this message translates to:
  /// **' · {arg0} hidden/filtered'**
  String hiddenFiltered(String arg0);

  /// Tilde app: {arg0} copy
  ///
  /// In en, this message translates to:
  /// **'{arg0} copy'**
  String copy3(String arg0);

  /// Tilde app: {arg0} hosts will use the app default profile.
  ///
  /// In en, this message translates to:
  /// **'{arg0} hosts will use the app default profile.'**
  String hostsWillUseTheAppDefaultProfile(String arg0);

  /// Tilde app: Delete this profile.
  ///
  /// In en, this message translates to:
  /// **'Delete this profile.'**
  String get deleteThisProfile;

  /// Tilde app: Connections for {arg0} hosts will remain, but the shared password will be deleted.
  ///
  /// In en, this message translates to:
  /// **'Connections for {arg0} hosts will remain, but the shared password will be deleted.'**
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0);

  /// Tilde app: Delete {arg0}
  ///
  /// In en, this message translates to:
  /// **'Delete {arg0}'**
  String delete2(String arg0);

  /// Tilde app: Set as default
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// Tilde app: Add {arg0}
  ///
  /// In en, this message translates to:
  /// **'Add {arg0}'**
  String add2(String arg0);

  /// Tilde app: Share a username, key, and password across multiple hosts.
  ///
  /// In en, this message translates to:
  /// **'Share a username, key, and password across multiple hosts.'**
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts;

  /// Tilde app:  · Default
  ///
  /// In en, this message translates to:
  /// **' · Default'**
  String get default2;

  /// Tilde app: No hosts using this
  ///
  /// In en, this message translates to:
  /// **'No hosts using this'**
  String get noHostsUsingThis;

  /// Tilde app: {arg0} hosts
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} host} other{{count} hosts}}'**
  String hosts(num count);

  /// Tilde app: Private key passphrase
  ///
  /// In en, this message translates to:
  /// **'Private key passphrase'**
  String get privateKeyPassphrase;

  /// Tilde app: Leave blank if there is no passphrase.
  ///
  /// In en, this message translates to:
  /// **'Leave blank if there is no passphrase.'**
  String get leaveBlankIfThereIsNoPassphrase;

  /// Tilde app: Delete key
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get deleteKey2;

  /// Tilde app: Delete key {arg0}?
  ///
  /// In en, this message translates to:
  /// **'Delete key {arg0}?'**
  String deleteKey3(String arg0);

  /// Tilde app: Save public key file
  ///
  /// In en, this message translates to:
  /// **'Save public key file'**
  String get savePublicKeyFile;

  /// Tilde app: Add key file
  ///
  /// In en, this message translates to:
  /// **'Add key file'**
  String get addKeyFile;

  /// Tilde app: New key
  ///
  /// In en, this message translates to:
  /// **'New key'**
  String get newKey;

  /// Tilde app: Could not complete key operation
  ///
  /// In en, this message translates to:
  /// **'Could not complete key operation'**
  String get couldNotCompleteKeyOperation;

  /// Tilde app: Imported private keys are used from protected app storage. Saved passphrases are protected by iOS Keychain.
  ///
  /// In en, this message translates to:
  /// **'Imported private keys are used from protected app storage. Saved passphrases are protected by iOS Keychain.'**
  String get importedPrivateKeysAreUsedFromProtectedAppStorage;

  /// Tilde app: Private key files are used from their original location. Saved passphrases are protected by your Windows account.
  ///
  /// In en, this message translates to:
  /// **'Private key files are used from their original location. Saved passphrases are protected by your Windows account.'**
  String get privateKeyFilesAreUsedFromTheirOriginalLocation;

  /// Tilde app: Private keys are created in Android Keystore and cannot be exported. Legacy private keys are preserved in a disabled state.
  ///
  /// In en, this message translates to:
  /// **'Private keys are created in Android Keystore and cannot be exported. Legacy private keys are preserved in a disabled state.'**
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot;

  /// Tilde app: Disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// Tilde app: {arg0} options
  ///
  /// In en, this message translates to:
  /// **'{arg0} options'**
  String options(String arg0);

  /// Tilde app: Delete forwarding
  ///
  /// In en, this message translates to:
  /// **'Delete forwarding'**
  String get deleteForwarding;

  /// Tilde app: Delete settings for {arg0}?
  ///
  /// In en, this message translates to:
  /// **'Delete settings for {arg0}?'**
  String deleteSettingsFor(String arg0);

  /// Tilde app: {arg0} · Forwarding
  ///
  /// In en, this message translates to:
  /// **'{arg0} · Forwarding'**
  String forwarding2(String arg0);

  /// Tilde app: Add forwarding
  ///
  /// In en, this message translates to:
  /// **'Add forwarding'**
  String get addForwarding;

  /// Tilde app: Session to control
  ///
  /// In en, this message translates to:
  /// **'Session to control'**
  String get sessionToControl;

  /// Tilde app: {arg0} · Switch changes apply immediately
  ///
  /// In en, this message translates to:
  /// **'{arg0} · Switch changes apply immediately'**
  String switchChangesApplyImmediately(String arg0);

  /// Tilde app: Default on connection
  ///
  /// In en, this message translates to:
  /// **'Default on connection'**
  String get defaultOnConnection;

  /// Tilde app: Could not load forwarding
  ///
  /// In en, this message translates to:
  /// **'Could not load forwarding'**
  String get couldNotLoadForwarding;

  /// Tilde app: SOCKS4 unsupported · Change to SOCKS5
  ///
  /// In en, this message translates to:
  /// **'SOCKS4 unsupported · Change to SOCKS5'**
  String get socks4UnsupportedChangeToSocks5;

  /// Tilde app: Remove server key trust
  ///
  /// In en, this message translates to:
  /// **'Remove server key trust'**
  String get removeServerKeyTrust;

  /// Tilde app: {arg0}:{arg1} The server key will be verified on the next connection.
  ///
  /// In en, this message translates to:
  /// **'{arg0}:{arg1}\nThe server key will be verified on the next connection.'**
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1);

  /// Tilde app: No trusted server keys.
  ///
  /// In en, this message translates to:
  /// **'No trusted server keys.'**
  String get noTrustedServerKeys;

  /// Tilde app: Use
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// Tilde app: Edit palette
  ///
  /// In en, this message translates to:
  /// **'Edit palette'**
  String get editPalette;

  /// Tilde app: Export
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Tilde app: Default theme
  ///
  /// In en, this message translates to:
  /// **'Default theme'**
  String get defaultTheme;

  /// Tilde app: Custom theme
  ///
  /// In en, this message translates to:
  /// **'Custom theme'**
  String get customTheme;

  /// Tilde app: Name for duplicate theme
  ///
  /// In en, this message translates to:
  /// **'Name for duplicate theme'**
  String get nameForDuplicateTheme;

  /// Tilde app: Theme name
  ///
  /// In en, this message translates to:
  /// **'Theme name'**
  String get themeName;

  /// Tilde app: Delete theme
  ///
  /// In en, this message translates to:
  /// **'Delete theme'**
  String get deleteTheme;

  /// Tilde app: Delete theme {arg0}?
  ///
  /// In en, this message translates to:
  /// **'Delete theme {arg0}?'**
  String deleteTheme2(String arg0);

  /// Tilde app: New theme name
  ///
  /// In en, this message translates to:
  /// **'New theme name'**
  String get newThemeName;

  /// Tilde app: New theme
  ///
  /// In en, this message translates to:
  /// **'New theme'**
  String get newTheme;

  /// Tilde app: Import
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Tilde app: Text color
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textColor;

  /// Tilde app: Background color
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get backgroundColor;

  /// Tilde app: Cursor and app accent
  ///
  /// In en, this message translates to:
  /// **'Cursor and app accent'**
  String get cursorAndAppAccent;

  /// Tilde app: Could not load color theme
  ///
  /// In en, this message translates to:
  /// **'Could not load color theme'**
  String get couldNotLoadColorTheme;

  /// Tilde app: Make a copy to edit the colors.
  ///
  /// In en, this message translates to:
  /// **'Make a copy to edit the colors.'**
  String get makeACopyToEditTheColors;

  /// Tilde app: ~ $ ls src  build  sample.md
  ///
  /// In en, this message translates to:
  /// **'~ \$ ls\nsrc  build  sample.md\n'**
  String get lsSrcBuildSampleMd;

  /// Tilde app: Default colors
  ///
  /// In en, this message translates to:
  /// **'Default colors'**
  String get defaultColors;

  /// Tilde app: Low contrast against background
  ///
  /// In en, this message translates to:
  /// **'Low contrast against background'**
  String get lowContrastAgainstBackground;

  /// Tilde app: ANSI palette
  ///
  /// In en, this message translates to:
  /// **'ANSI palette'**
  String get ansiPalette;

  /// Tilde app: ANSI color {arg0}
  ///
  /// In en, this message translates to:
  /// **'ANSI color {arg0}'**
  String ansiColor(String arg0);

  /// Tilde app: Find server
  ///
  /// In en, this message translates to:
  /// **'Find server'**
  String get findServer;

  /// Tilde app: Verify server key
  ///
  /// In en, this message translates to:
  /// **'Verify server key'**
  String get verifyServerKey;

  /// Tilde app: {arg0}s
  ///
  /// In en, this message translates to:
  /// **'{arg0}s'**
  String seconds(String arg0);

  /// Tilde app: Could not open ad privacy settings. Try again.
  ///
  /// In en, this message translates to:
  /// **'Could not open ad privacy settings. Try again.'**
  String get couldNotOpenAdPrivacySettingsTryAgain;

  /// Tilde app: Ad
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get ad;

  /// Tilde app: Ad privacy settings
  ///
  /// In en, this message translates to:
  /// **'Ad privacy settings'**
  String get adPrivacySettings;

  /// Tilde app: Google Fonts · Monospace
  ///
  /// In en, this message translates to:
  /// **'Google Fonts · Monospace'**
  String get googleFontsMonospace;

  /// Tilde app: Search settings
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// Tilde app: Keyboard
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboard;

  /// Tilde app: Gestures
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get gestures;

  /// Tilde app: Connections and notifications
  ///
  /// In en, this message translates to:
  /// **'Connections and notifications'**
  String get connectionsAndNotifications;

  /// Tilde app: Security and backup
  ///
  /// In en, this message translates to:
  /// **'Security and backup'**
  String get securityAndBackup;

  /// Tilde app: Manage fonts
  ///
  /// In en, this message translates to:
  /// **'Manage fonts'**
  String get manageFonts;

  /// Tilde app: Special key bar
  ///
  /// In en, this message translates to:
  /// **'Special key bar'**
  String get specialKeyBar;

  /// Tilde app: {arg0} special keys
  ///
  /// In en, this message translates to:
  /// **'{arg0} special keys'**
  String specialKeys(String arg0);

  /// Tilde app: Two-finger horizontal swipe · {arg0}
  ///
  /// In en, this message translates to:
  /// **'Two-finger horizontal swipe · {arg0}'**
  String twoFingerHorizontalSwipe(String arg0);

  /// Tilde app: tmux windows
  ///
  /// In en, this message translates to:
  /// **'tmux windows'**
  String get tmuxWindows;

  /// Tilde app: Disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled2;

  /// Tilde app: Default terminal
  ///
  /// In en, this message translates to:
  /// **'Default terminal'**
  String get defaultTerminal;

  /// Tilde app: Notifications and bell
  ///
  /// In en, this message translates to:
  /// **'Notifications and bell'**
  String get notificationsAndBell;

  /// Tilde app: {arg0} SSH keys
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} SSH key} other{{count} SSH keys}}'**
  String sshKeys2(num count);

  /// Tilde app: Help and logs
  ///
  /// In en, this message translates to:
  /// **'Help and logs'**
  String get helpAndLogs2;

  /// Tilde app: Horizontal margins
  ///
  /// In en, this message translates to:
  /// **'Horizontal margins'**
  String get horizontalMargins;

  /// Tilde app: lines
  ///
  /// In en, this message translates to:
  /// **'lines'**
  String get lines;

  /// Tilde app: App theme
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get appTheme;

  /// Tilde app: System theme
  ///
  /// In en, this message translates to:
  /// **'System theme'**
  String get systemTheme;

  /// Tilde app: Light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Tilde app: Dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Tilde app: Font
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// Tilde app: Orientation
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get orientation;

  /// Tilde app: Always rotate
  ///
  /// In en, this message translates to:
  /// **'Always rotate'**
  String get alwaysRotate;

  /// Tilde app: Portrait
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portrait;

  /// Tilde app: Landscape
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscape;

  /// Tilde app: Hide status bar
  ///
  /// In en, this message translates to:
  /// **'Hide status bar'**
  String get hideStatusBar;

  /// Tilde app: Special key layout
  ///
  /// In en, this message translates to:
  /// **'Special key layout'**
  String get specialKeyLayout;

  /// Tilde app: Show when keyboard is closed
  ///
  /// In en, this message translates to:
  /// **'Show when keyboard is closed'**
  String get showWhenKeyboardIsClosed;

  /// Tilde app: When pressing Ctrl or Alt
  ///
  /// In en, this message translates to:
  /// **'When pressing Ctrl or Alt'**
  String get whenPressingCtrlOrAlt;

  /// Tilde app: Once
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// Tilde app: Sticky
  ///
  /// In en, this message translates to:
  /// **'Sticky'**
  String get sticky;

  /// Tilde app: Sticky Alt only
  ///
  /// In en, this message translates to:
  /// **'Sticky Alt only'**
  String get stickyAltOnly;

  /// Tilde app: Keyboard toggle button
  ///
  /// In en, this message translates to:
  /// **'Keyboard toggle button'**
  String get keyboardToggleButton;

  /// Tilde app: Two-finger horizontal swipe
  ///
  /// In en, this message translates to:
  /// **'Two-finger horizontal swipe'**
  String get twoFingerHorizontalSwipe2;

  /// Tilde app: Do nothing
  ///
  /// In en, this message translates to:
  /// **'Do nothing'**
  String get doNothing;

  /// Tilde app: Switch sessions
  ///
  /// In en, this message translates to:
  /// **'Switch sessions'**
  String get switchSessions;

  /// Tilde app: Switch tmux windows
  ///
  /// In en, this message translates to:
  /// **'Switch tmux windows'**
  String get switchTmuxWindows;

  /// Tilde app: Prefix key
  ///
  /// In en, this message translates to:
  /// **'Prefix key'**
  String get prefixKey;

  /// Tilde app: Two-finger vertical swipe
  ///
  /// In en, this message translates to:
  /// **'Two-finger vertical swipe'**
  String get twoFingerVerticalSwipe;

  /// Tilde app: Scroll
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get scroll;

  /// Tilde app: Volume buttons change font size
  ///
  /// In en, this message translates to:
  /// **'Volume buttons change font size'**
  String get volumeButtonsChangeFontSize;

  /// Tilde app: Special key vibration
  ///
  /// In en, this message translates to:
  /// **'Special key vibration'**
  String get specialKeyVibration;

  /// Tilde app: Default terminal profile
  ///
  /// In en, this message translates to:
  /// **'Default terminal profile'**
  String get defaultTerminalProfile;

  /// Tilde app: Manage terminal profiles
  ///
  /// In en, this message translates to:
  /// **'Manage terminal profiles'**
  String get manageTerminalProfiles;

  /// Tilde app: {arg0}
  ///
  /// In en, this message translates to:
  /// **'{arg0}'**
  String itemCount(String arg0);

  /// Tilde app: Appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Tilde app: Terminal type (TERM)
  ///
  /// In en, this message translates to:
  /// **'Terminal type (TERM)'**
  String get terminalTypeTerm;

  /// Tilde app: Add terminal type
  ///
  /// In en, this message translates to:
  /// **'Add terminal type'**
  String get addTerminalType;

  /// Tilde app: Terminal type
  ///
  /// In en, this message translates to:
  /// **'Terminal type'**
  String get terminalType;

  /// Tilde app: Keep screen awake while connected
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake while connected'**
  String get keepScreenAwakeWhileConnected;

  /// Tilde app: The terminal screen will stay awake
  ///
  /// In en, this message translates to:
  /// **'The terminal screen will stay awake'**
  String get theTerminalScreenWillStayAwake;

  /// Tilde app: Prevent Wi-Fi sleep
  ///
  /// In en, this message translates to:
  /// **'Prevent Wi-Fi sleep'**
  String get preventWiFiSleep;

  /// Tilde app: Uses more battery
  ///
  /// In en, this message translates to:
  /// **'Uses more battery'**
  String get usesMoreBattery;

  /// Tilde app: Background connection notification
  ///
  /// In en, this message translates to:
  /// **'Background connection notification'**
  String get backgroundConnectionNotification;

  /// Tilde app: Pinned while connected
  ///
  /// In en, this message translates to:
  /// **'Pinned while connected'**
  String get pinnedWhileConnected;

  /// Tilde app: Terminal bell
  ///
  /// In en, this message translates to:
  /// **'Terminal bell'**
  String get terminalBell;

  /// Tilde app: When the bell rings
  ///
  /// In en, this message translates to:
  /// **'When the bell rings'**
  String get whenTheBellRings;

  /// Tilde app: Ignore
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// Tilde app: Sound
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// Tilde app: Vibration
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// Tilde app: Sound and vibration
  ///
  /// In en, this message translates to:
  /// **'Sound and vibration'**
  String get soundAndVibration;

  /// Tilde app: Volume
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// Tilde app: Notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Tilde app: Notification permission required
  ///
  /// In en, this message translates to:
  /// **'Notification permission required'**
  String get notificationPermissionRequired;

  /// Tilde app: Allow
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// Tilde app: Enable connection notifications
  ///
  /// In en, this message translates to:
  /// **'Enable connection notifications'**
  String get enableConnectionNotifications;

  /// Tilde app: Allow bell and disconnection notifications
  ///
  /// In en, this message translates to:
  /// **'Allow bell and disconnection notifications'**
  String get allowBellAndDisconnectionNotifications;

  /// Tilde app: Bell in background
  ///
  /// In en, this message translates to:
  /// **'Bell in background'**
  String get bellInBackground;

  /// Tilde app: On disconnect
  ///
  /// In en, this message translates to:
  /// **'On disconnect'**
  String get onDisconnect;

  /// Tilde app: Android notification settings
  ///
  /// In en, this message translates to:
  /// **'Android notification settings'**
  String get androidNotificationSettings;

  /// Tilde app: Notifications off
  ///
  /// In en, this message translates to:
  /// **'Notifications off'**
  String get notificationsOff;

  /// Tilde app: Notifications allowed
  ///
  /// In en, this message translates to:
  /// **'Notifications allowed'**
  String get notificationsAllowed;

  /// Tilde app: Lock
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// Tilde app: Unlock when starting the app
  ///
  /// In en, this message translates to:
  /// **'Unlock when starting the app'**
  String get unlockWhenStartingTheApp;

  /// Tilde app: Set up a screen lock first
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock first'**
  String get setUpAScreenLockFirst;

  /// Tilde app: Fingerprint or screen lock
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or screen lock'**
  String get fingerprintOrScreenLock;

  /// Tilde app: Keys and servers
  ///
  /// In en, this message translates to:
  /// **'Keys and servers'**
  String get keysAndServers;

  /// Tilde app: Configuration file
  ///
  /// In en, this message translates to:
  /// **'Configuration file'**
  String get configurationFile;

  /// Tilde app: Export hosts
  ///
  /// In en, this message translates to:
  /// **'Export hosts'**
  String get exportHosts;

  /// Tilde app: Import hosts
  ///
  /// In en, this message translates to:
  /// **'Import hosts'**
  String get importHosts;

  /// Tilde app: Select default font
  ///
  /// In en, this message translates to:
  /// **'Select default font'**
  String get selectDefaultFont;

  /// Tilde app: {arg0} Aa
  ///
  /// In en, this message translates to:
  /// **'{arg0} Aa'**
  String fontSample(String arg0);

  /// Tilde app: Bundled with app
  ///
  /// In en, this message translates to:
  /// **'Bundled with app'**
  String get bundledWithApp;

  /// Tilde app: Monospace font
  ///
  /// In en, this message translates to:
  /// **'Monospace font'**
  String get monospaceFont;

  /// Tilde app: Delete font
  ///
  /// In en, this message translates to:
  /// **'Delete font'**
  String get deleteFont;

  /// Tilde app: Delete this font file?
  ///
  /// In en, this message translates to:
  /// **'Delete this font file?'**
  String get deleteThisFontFile;

  /// Tilde app: Remove font
  ///
  /// In en, this message translates to:
  /// **'Remove font'**
  String get removeFont;

  /// Tilde app: Preparing font
  ///
  /// In en, this message translates to:
  /// **'Preparing font'**
  String get preparingFont;

  /// Tilde app: Import font file
  ///
  /// In en, this message translates to:
  /// **'Import font file'**
  String get importFontFile;

  /// Tilde app: Find on Google Fonts
  ///
  /// In en, this message translates to:
  /// **'Find on Google Fonts'**
  String get findOnGoogleFonts;

  /// Tilde app: Only monospace fonts are shown
  ///
  /// In en, this message translates to:
  /// **'Only monospace fonts are shown'**
  String get onlyMonospaceFontsAreShown;

  /// Tilde app: Settings › {arg0}
  ///
  /// In en, this message translates to:
  /// **'Settings › {arg0}'**
  String settings2(String arg0);

  /// Tilde app: Could not save settings
  ///
  /// In en, this message translates to:
  /// **'Could not save settings'**
  String get couldNotSaveSettings;

  /// Tilde app: Reset special key bar?
  ///
  /// In en, this message translates to:
  /// **'Reset special key bar?'**
  String get resetSpecialKeyBar;

  /// Tilde app: Restore the default height, key order, and visibility.
  ///
  /// In en, this message translates to:
  /// **'Restore the default height, key order, and visibility.'**
  String get restoreTheDefaultHeightKeyOrderAndVisibility;

  /// Tilde app: Long-press to drag · Tap to hide
  ///
  /// In en, this message translates to:
  /// **'Long-press to drag · Tap to hide'**
  String get longPressToDragTapToHide;

  /// Tilde app: Hidden keys
  ///
  /// In en, this message translates to:
  /// **'Hidden keys'**
  String get hiddenKeys;

  /// Tilde app: Tap a key to move it here
  ///
  /// In en, this message translates to:
  /// **'Tap a key to move it here'**
  String get tapAKeyToMoveItHere;

  /// Tilde app: Combine F1–F12 into Fn
  ///
  /// In en, this message translates to:
  /// **'Combine F1–F12 into Fn'**
  String get combineF1F12IntoFn;

  /// Tilde app: Height
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// Tilde app: Small
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// Tilde app: Large
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// Tilde app: Default
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default3;

  /// Tilde app: Esc and Ctrl stay on the left; keyboard, Fn, and Tab stay on the right.
  ///
  /// In en, this message translates to:
  /// **'Esc and Ctrl stay on the left; keyboard, Fn, and Tab stay on the right.'**
  String get escAndCtrlStayOnTheLeftKeyboardFn;

  /// Tilde app: Flutter library licenses
  ///
  /// In en, this message translates to:
  /// **'Flutter library licenses'**
  String get flutterLibraryLicenses;

  /// Tilde app: Tips
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// Tilde app: Licenses and terms
  ///
  /// In en, this message translates to:
  /// **'Licenses and terms'**
  String get licensesAndTerms;

  /// Tilde app: Project and contact
  ///
  /// In en, this message translates to:
  /// **'Project and contact'**
  String get projectAndContact;

  /// Tilde app: Diagnostics
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// Tilde app: Diagnostic logs
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs'**
  String get diagnosticLogs;

  /// Tilde app: Search logs
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get searchLogs;

  /// Tilde app: Save native crash log
  ///
  /// In en, this message translates to:
  /// **'Save native crash log'**
  String get saveNativeCrashLog;

  /// Tilde app: Warning
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// Tilde app: Could not load logs
  ///
  /// In en, this message translates to:
  /// **'Could not load logs'**
  String get couldNotLoadLogs;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Only Android Keystore SSH keys are supported'**
  String get onlyAndroidKeystoreSshKeysAreSupported;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Only P-256 Android Keystore keys are supported'**
  String get onlyP256AndroidKeystoreKeysAreSupported;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid ECDSA signature'**
  String get invalidEcdsaSignature;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid ECDSA signature values'**
  String get invalidEcdsaSignatureValues;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid X509 public key'**
  String get invalidX509PublicKey;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid public key bit string'**
  String get invalidPublicKeyBitString;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid RSA public key'**
  String get invalidRsaPublicKey;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid EC curve'**
  String get invalidEcCurve;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid uncompressed EC point'**
  String get invalidUncompressedEcPoint;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid Ed25519 public key'**
  String get invalidEd25519PublicKey;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported SSH public key algorithm: {arg0}'**
  String unsupportedSshPublicKeyAlgorithm(String arg0);

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported SSH EC curve'**
  String get unsupportedSshEcCurve;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid DER sequence'**
  String get invalidDerSequence;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Private key export is not supported'**
  String get privateKeyExportIsNotSupported;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Public key is unavailable'**
  String get publicKeyIsUnavailable;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported terminal key: {arg0}'**
  String unsupportedTerminalKey(String arg0);

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before reconnecting'**
  String get disconnectBeforeReconnecting;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Local shell is not open'**
  String get localShellIsNotOpen;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unknown modifier'**
  String get unknownModifier;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported local terminal operation: {arg0}'**
  String unsupportedLocalTerminalOperation(String arg0);

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid SSH public-key line'**
  String get invalidSshPublicKeyLine;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Server did not confirm public-key registration.'**
  String get serverDidNotConfirmPublicKeyRegistration;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to a saved SSH host before registering a key.'**
  String get logInToASavedSshHostBeforeRegistering;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'The selected SSH key no longer exists.'**
  String get theSelectedSshKeyNoLongerExists;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'A unique biometric key name is required.'**
  String get aUniqueBiometricKeyNameIsRequired;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'The original SSH connection is no longer authenticated.'**
  String get theOriginalSshConnectionIsNoLongerAuthenticated;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Key-only login was not completed. The server may require additional authentication. Login settings were not changed.'**
  String get keyOnlyLoginWasNotCompletedTheServerMay;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'The saved host no longer exists.'**
  String get theSavedHostNoLongerExists;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'The host address changed during registration. Its login settings were not changed.'**
  String get theHostAddressChangedDuringRegistrationItsLoginSettings;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid PTY dimensions'**
  String get invalidPtyDimensions;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH target is required'**
  String get sshTargetIsRequired;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH session was closed'**
  String get sshSessionWasClosed;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH session is not connected'**
  String get sshSessionIsNotConnected;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH sessions cannot be reused'**
  String get sshSessionsCannotBeReused;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'No address for requested IP version'**
  String get noAddressForRequestedIpVersion;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH hop connection timed out'**
  String get sshHopConnectionTimedOut;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH session has no shell'**
  String get sshSessionHasNoShell;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH session request timed out'**
  String get sshSessionRequestTimedOut;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid forward bind port'**
  String get invalidForwardBindPort;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid forward destination'**
  String get invalidForwardDestination;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Remote forwarding request timed out'**
  String get remoteForwardingRequestTimedOut;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Remote forwarding was refused'**
  String get remoteForwardingWasRefused;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Forward connection timed out'**
  String get forwardConnectionTimedOut;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Remote forward destination timed out'**
  String get remoteForwardDestinationTimedOut;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Remote forwarding cancellation was refused'**
  String get remoteForwardingCancellationWasRefused;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH authentication cancelled'**
  String get sshAuthenticationCancelled;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Concurrent SSH authentication prompt'**
  String get concurrentSshAuthenticationPrompt;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Session disposed'**
  String get sessionDisposed;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before refreshing SSH configuration'**
  String get disconnectBeforeRefreshingSshConfiguration;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the selected key.'**
  String get couldNotUnlockTheSelectedKey;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to this server before registering a key.'**
  String get logInToThisServerBeforeRegisteringAKey;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH shell is not open'**
  String get sshShellIsNotOpen;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'SSH is not connected'**
  String get sshIsNotConnected;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Port forward is missing'**
  String get portForwardIsMissing;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported SSH forward type'**
  String get unsupportedSshForwardType;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Unsupported app SSH operation: {arg0}'**
  String unsupportedAppSshOperation(String arg0);

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// Tilde app error or authentication prompt.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Timed out reading Windows SSH settings.'**
  String get timedOutReadingWindowsSshSettings;

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Could not read Windows SSH settings. {arg0}'**
  String couldNotReadWindowsSshSettings(String arg0);

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Windows user profile path is unavailable.'**
  String get windowsUserProfilePathIsUnavailable;

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Unsupported SSH key path variable: {arg0}'**
  String unsupportedSshKeyPathVariable(String arg0);

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Could not import files: {arg0}'**
  String couldNotImportFiles(String arg0);

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Upload to {arg0}'**
  String uploadTo(String arg0);

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Current folder'**
  String get currentFolder;

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Windows user data folder is unavailable.'**
  String get windowsUserDataFolderIsUnavailable;

  /// Tilde Windows host message.
  ///
  /// In en, this message translates to:
  /// **'Could not protect credentials with the Windows account. {arg0}'**
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0);

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Alt drag'**
  String get altDrag;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get keyUp;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get keyDown;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get keyHome;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get keyEnd;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Page up'**
  String get keyPageUp;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Page down'**
  String get keyPageDown;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get keyInsert;

  /// Terminal action or navigation key tooltip; keycap labels remain unchanged.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keyDelete;

  /// Tilde additional design review: Skip
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipCopy;

  /// Tilde additional design review: Keep both
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBothFiles;

  /// Tilde additional design review: Apply to remaining files is unavailable when cancelling the job.
  ///
  /// In en, this message translates to:
  /// **'Apply to remaining files is unavailable when cancelling the job.'**
  String get cancelJobNoApplyAll;

  /// Tilde additional design review: Edit authentication
  ///
  /// In en, this message translates to:
  /// **'Edit authentication'**
  String get editAuthentication;

  /// Tilde additional design review: Server message
  ///
  /// In en, this message translates to:
  /// **'Server message'**
  String get serverMessage;

  /// Tilde additional design review: Cancelling…
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get cancellingOperation;

  /// Tilde additional design review: Transfers
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transferHeading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
