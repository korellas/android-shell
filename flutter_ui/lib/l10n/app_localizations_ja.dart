// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get home => 'ホーム';

  @override
  String get terminal => 'ターミナル';

  @override
  String files(String arg0) {
    return '$arg0 · ファイル';
  }

  @override
  String get newHost => '新しいホスト';

  @override
  String edit(String arg0) {
    return '$arg0を編集';
  }

  @override
  String get disconnectAndCloseTab => '切断してタブを閉じる';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return '$arg0への接続を切断し、このタブを閉じますか？';
  }

  @override
  String get disconnectAndClose => '切断して閉じる';

  @override
  String get newTerminal => '新しいターミナル';

  @override
  String get fileTransfer => 'ファイル転送';

  @override
  String get edit2 => '編集';

  @override
  String get removeFromFavorites => 'お気に入りから削除';

  @override
  String get addToFavorites => 'お気に入りに追加';

  @override
  String get duplicate => '複製';

  @override
  String get portForwarding => 'ポート転送';

  @override
  String get disconnect => '切断';

  @override
  String get delete => '削除';

  @override
  String get nameForDuplicateHost => '複製するホストの名前';

  @override
  String copy(String arg0) {
    return '$arg0のコピー';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return '$arg0のすべてのセッションを切断しますか？';
  }

  @override
  String get searchHosts => 'ホストを検索';

  @override
  String get searchHostsOrEnterSshAddressCtrlK =>
      'ホストを検索、またはSSHアドレスを入力（Ctrl K）';

  @override
  String get addHost => 'ホストを追加';

  @override
  String get noHostsYet => 'ホストはまだありません';

  @override
  String get openTerminals => '開いているターミナル';

  @override
  String get openFiles => '開いているファイル';

  @override
  String menu(String arg0) {
    return '$arg0のメニュー';
  }

  @override
  String get settings => '設定';

  @override
  String get helpAndLogs => 'ヘルプとログ';

  @override
  String get hostListCtrlB => 'ホスト一覧（Ctrl B）';

  @override
  String closeTab(String arg0) {
    return '$arg0のタブを閉じる';
  }

  @override
  String get newTabCtrlShiftT => '新しいタブ（Ctrl Shift T）';

  @override
  String get terminalMenu => 'ターミナルメニュー';

  @override
  String get importSshKey => 'SSH鍵をインポート';

  @override
  String get openSessions => '開いているセッション';

  @override
  String session(String arg0) {
    return 'セッション$arg0';
  }

  @override
  String get connected => '接続済み';

  @override
  String get connecting => '接続中';

  @override
  String get disconnected => '切断済み';

  @override
  String get open => '開く';

  @override
  String get connect => '接続';

  @override
  String get address => 'アドレス';

  @override
  String get authentication => '認証';

  @override
  String get tryAllAvailableKeys => '利用可能なすべての鍵を試す';

  @override
  String get useServerSettings => 'サーバーの設定に従う';

  @override
  String get terminalProfile => 'ターミナルプロファイル';

  @override
  String get appDefaultProfile => 'アプリの既定プロファイル';

  @override
  String get manage => '管理';

  @override
  String get minimize => '最小化';

  @override
  String get restore => '元のサイズに戻す';

  @override
  String get maximize => '最大化';

  @override
  String get closeWindow => 'ウィンドウを閉じる';

  @override
  String get host => 'ホスト';

  @override
  String get profile => 'プロファイル';

  @override
  String get sharedLoginAccount => '共通ログインアカウント';

  @override
  String get sshKeys => 'SSH鍵';

  @override
  String enter(String arg0) {
    return '$arg0を入力してください。';
  }

  @override
  String get enterAWholeNumber => '整数を入力してください。';

  @override
  String get checkThePortRange => 'ポートの範囲を確認してください。';

  @override
  String currentValue(String arg0) {
    return '$arg0（現在の値）';
  }

  @override
  String get select => '選択';

  @override
  String get defaultValue => '既定値';

  @override
  String get dsaUnsupported => '（DSA非対応）';

  @override
  String get windowsDefaultKeysAndAddedKeys => 'Windowsの既定の鍵と追加した鍵';

  @override
  String get noKey => '鍵を使用しない';

  @override
  String get passwordSaved => 'パスワード（保存済み）';

  @override
  String get password => 'パスワード';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      'このデバイスに暗号化して保存します。別のデバイスに復元した場合は再入力が必要です。';

  @override
  String get storedEncryptedOnThisDevice => 'このデバイスに暗号化して保存します。';

  @override
  String get deleteSavedPassword => '保存したパスワードを削除';

  @override
  String get accountName => 'アカウント名';

  @override
  String get username => 'ユーザー名';

  @override
  String appliesToHosts(String arg0) {
    return '$arg0台のホストに適用されます';
  }

  @override
  String get display => '表示';

  @override
  String get profileName => 'プロファイル名';

  @override
  String get colorTheme => 'カラーテーマ';

  @override
  String get terminalFont => 'ターミナルのフォント';

  @override
  String get appDefault => 'アプリの既定値';

  @override
  String get fontSize => '文字サイズ';

  @override
  String get characterEncoding => '文字コード';

  @override
  String get deleteKey => '削除キー';

  @override
  String get columnsAutomatic => '列数 · 自動';

  @override
  String get rowsAutomatic => '行数 · 自動';

  @override
  String get forwarding => '転送';

  @override
  String get forwardingName => '転送名';

  @override
  String get type => '種類';

  @override
  String get local => 'ローカル';

  @override
  String get remote => 'リモート';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      'サーバーのポートに届いた接続を、このデバイスのアドレスへ転送します。';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      'このデバイスのポートに届いた接続を、サーバー側のアドレスへ転送します。';

  @override
  String get openASocks5ProxyOnThisDevice => 'このデバイスでSOCKS5プロキシを開きます。';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      'SOCKS4には対応していません。種類をSOCKS5に変更してください。';

  @override
  String get listenAddressOnServer => 'サーバーの待受アドレス';

  @override
  String get listenAddressOnThisDevice => 'このデバイスの待受アドレス';

  @override
  String get text127001AccessibleOnlyOnThisDevice =>
      '127.0.0.1 · このデバイスからのみアクセス可能';

  @override
  String get port => 'ポート';

  @override
  String get destinationAddress => '転送先アドレス';

  @override
  String get publicKey => '公開鍵';

  @override
  String get copyFingerprint => 'フィンガープリントをコピー';

  @override
  String get copyPublicKey => '公開鍵をコピー';

  @override
  String get keySettings => '鍵の設定';

  @override
  String get keyName => '鍵の名前';

  @override
  String get confirmBeforeUse => '使用前に確認';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      'この鍵で認証する前に許可を求めます';

  @override
  String get importedPrivateKey => 'インポートした秘密鍵';

  @override
  String get androidKeystoreP256Key => 'Android KeystoreのP-256鍵';

  @override
  String get authenticateWithAnImportedPrivateKeyFile => 'インポートした秘密鍵ファイルで認証します';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice =>
      '秘密鍵をこのデバイスからエクスポートすることはできません';

  @override
  String get disabledLegacyPrivateKey => '無効化された従来の秘密鍵';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      '新しいAndroid Keystore鍵に置き換えてから削除してください。';

  @override
  String get connectionType => '接続方式';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return '$arg0接続には対応していません。SSHまたはローカルに変更してください。';
  }

  @override
  String get hostName => 'ホストの名前';

  @override
  String get name => '名前';

  @override
  String get serverAddress => 'サーバーアドレス';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      'アドレス欄にuser@host:portを貼り付けると、各項目に分けて入力します。';

  @override
  String get advanced => '詳細設定';

  @override
  String get ipAddress => 'IPアドレス';

  @override
  String get automatic => '自動';

  @override
  String get jumpHost => '踏み台ホスト';

  @override
  String get directConnection => '直接接続';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      'この接続方式ではSSH認証の設定を使用しません。';

  @override
  String get account => 'アカウント';

  @override
  String get doNotUse => '使用しない';

  @override
  String usingAccount(String arg0) {
    return 'アカウント$arg0を使用';
  }

  @override
  String get loginKey => 'ログイン用の鍵';

  @override
  String get registerKeyOnThisServer => 'このサーバーに鍵を登録';

  @override
  String get logInOnceWithAPasswordToInstallThe => 'パスワードで一度ログインし、公開鍵を登録します';

  @override
  String get hostColor => 'ホストの色';

  @override
  String get previewInTheHomeListTabsAndNotifications => 'ホーム一覧・タブ・通知での表示を確認';

  @override
  String get customHostColor => 'ホストの色を指定';

  @override
  String appDefault2(String arg0) {
    return 'アプリの既定値 · $arg0';
  }

  @override
  String get manageProfiles => 'プロファイルを管理';

  @override
  String get keepConnectionAlive => '接続を維持';

  @override
  String get reconnectAutomaticallyAfterAnIOError => '入出力エラーで切断された場合に自動再接続します';

  @override
  String get closeWithoutAsking => '確認せずに閉じる';

  @override
  String get closeTheTabImmediatelyAfterExit => 'exit後すぐにタブを閉じます';

  @override
  String get sshCompression => 'SSH圧縮';

  @override
  String get enableOnlyOnSlowConnections => '低速な回線でのみ有効にしてください';

  @override
  String get openTerminal => 'ターミナルを開く';

  @override
  String get whenOffOnlyPortForwardingIsEnabled => '無効にするとポート転送のみを行います';

  @override
  String get overrideForThisHost => 'このホストのみ変更';

  @override
  String get scrollback => 'スクロール履歴';

  @override
  String linesDefault(String arg0) {
    return '行 · 既定値$arg0';
  }

  @override
  String get useCtrlAltAsMeta => 'Ctrl+AltをMetaとして使用';

  @override
  String get displayAndProfile => '表示とプロファイル';

  @override
  String get session2 => 'セッション';

  @override
  String get editHost => 'ホストを編集';

  @override
  String get localShell => 'ローカルシェル';

  @override
  String get selectKey => '鍵を選択';

  @override
  String get connectionSettings => '接続設定';

  @override
  String get trustedServerKeys => '信頼したサーバー鍵';

  @override
  String get nameForDuplicate => '複製の名前';

  @override
  String get couldNotSave => '保存できませんでした';

  @override
  String get details => '詳細';

  @override
  String get changedFields => '変更した項目';

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get none => 'なし';

  @override
  String get saving => '保存中';

  @override
  String changed(String arg0) {
    return '$arg0を変更しました';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0ほか';
  }

  @override
  String items(num count) {
    return '$count項目';
  }

  @override
  String get saved => '保存しました';

  @override
  String get undo => '元に戻す';

  @override
  String get save => '保存';

  @override
  String get saveAndOpenNewTerminal => '保存して新しいターミナルを開く';

  @override
  String get deleteHost => 'ホストを削除';

  @override
  String get couldNotSaveChanges => '変更を保存できませんでした';

  @override
  String get add => '追加';

  @override
  String get cancel => 'キャンセル';

  @override
  String get saving2 => '保存中…';

  @override
  String get apply => '適用';

  @override
  String get back => '戻る';

  @override
  String get systemDefault => 'システムの既定値';

  @override
  String get appDefaultFont => 'アプリの既定フォント';

  @override
  String get newSshKey => '新しいSSH鍵';

  @override
  String get enterAName => '名前を入力してください。';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      'Android KeystoreにP-256秘密鍵を作成し、署名のたびに生体認証を求めます。秘密鍵のコピー、エクスポート、バックアップはできません。';

  @override
  String get couldNotCreateKey => '鍵を作成できませんでした';

  @override
  String get createKey => '鍵を作成';

  @override
  String get search => '検索';

  @override
  String get saving3 => '保存中';

  @override
  String changes(String arg0) {
    return '$arg0件の変更';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return '$arg0～$arg1の値を入力してください';
  }

  @override
  String decrease(String arg0) {
    return '$arg0を減らす';
  }

  @override
  String increase(String arg0) {
    return '$arg0を増やす';
  }

  @override
  String get discardChanges => '変更を破棄';

  @override
  String get unsavedChangesWillBeLost => '保存していない変更は失われます。';

  @override
  String get keepEditing => '編集を続ける';

  @override
  String get discard => '破棄';

  @override
  String get selectColor => '色を選択';

  @override
  String get brightness => '明るさ';

  @override
  String get hexColor => '16進数の色';

  @override
  String get enterASixDigitColor => '6桁の色を入力してください';

  @override
  String get menu2 => 'メニュー';

  @override
  String get defaultProfile => '既定のプロファイル';

  @override
  String get theSavedConnectionSettingsAreInvalid => '保存された接続設定が正しくありません。';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return '保存された$arg0の設定が正しくありません。';
  }

  @override
  String get theSavedColorThemeIsInvalid => '保存されたカラーテーマが正しくありません。';

  @override
  String get checkTheSshAddress => 'SSHアドレスを確認してください。';

  @override
  String get useAnSshHost => 'SSHホストを使用してください。';

  @override
  String get thisTerminalUsesUtf8 => 'このターミナルはUTF-8を使用します。';

  @override
  String get colorThemeNotFound => 'カラーテーマが見つかりません。';

  @override
  String get enterAThemeName => 'テーマ名を入力してください。';

  @override
  String get aThemeWithThisNameAlreadyExists => '同じ名前のテーマが既にあります。';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues => '色は3桁または6桁の16進数で指定してください。';

  @override
  String get invalidColorThemeFileFormat => 'カラーテーマのファイル形式が正しくありません。';

  @override
  String get defaultColorIndicesMustBeBetween0And15 => '既定色の番号は0～15で指定してください。';

  @override
  String get ansiColorIndicesMustBeBetween0And15 => 'ANSI色の番号は0～15で指定してください。';

  @override
  String get invalidThemeDescriptionFormat => 'テーマの説明の形式が正しくありません。';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt =>
      '既定のテーマを複製してから編集してください。';

  @override
  String get checkTheColorRole => '色の役割を確認してください。';

  @override
  String get unsupportedThemeOperation => '対応していないテーマ操作です。';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      '明示的に確認した新しいサーバー鍵のみ保存できます。';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed => '転送用の一時ファイルのみ処理できます。';

  @override
  String get checkTheSshJumpHostConnection => 'SSH踏み台ホストへの接続を確認してください。';

  @override
  String get enterAServerAddress => 'サーバーアドレスを入力してください。';

  @override
  String get noHostToRestore => '復元するホストがありません。';

  @override
  String get thisProfileIsInUse => 'このプロファイルは使用中です。';

  @override
  String get unsupportedLink => '対応していないリンクです。';

  @override
  String get keyFile => '鍵ファイル';

  @override
  String unsupportedOperation(String arg0) {
    return '対応していない操作：$arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable => 'Android Keystore鍵を使用できません';

  @override
  String get legacyPrivateKeyDisabled => '従来の秘密鍵 · 無効';

  @override
  String get toggleKeyboard => 'キーボードを切り替え';

  @override
  String get endSession => 'セッションを終了';

  @override
  String disconnectFrom(String arg0) {
    return '$arg0への接続を切断しますか？';
  }

  @override
  String get end => '終了';

  @override
  String get couldNotCloseConnection => '接続を閉じることができませんでした';

  @override
  String get noOpenSessions => '開いているセッションはありません。';

  @override
  String disconnected2(String arg0) {
    return '切断済み$arg0';
  }

  @override
  String end2(String arg0) {
    return '$arg0を終了';
  }

  @override
  String get newTab => '新しいタブ';

  @override
  String close(String arg0) {
    return '$arg0を閉じる';
  }

  @override
  String get image => '画像';

  @override
  String get words => '単語';

  @override
  String get firstConnectionToThisServer => 'このサーバーへの初回接続です';

  @override
  String get biometricAuthentication => '生体認証';

  @override
  String logInTo(String arg0) {
    return '$arg0にログイン';
  }

  @override
  String get server => 'サーバー';

  @override
  String get hidePassword => 'パスワードを隠す';

  @override
  String get showPassword => 'パスワードを表示';

  @override
  String get saveOnThisDevice => 'このデバイスに保存';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      'このフィンガープリントがサーバー管理者から提供されたものと一致することを確認してください。';

  @override
  String get fingerprintFormat => 'フィンガープリントの形式';

  @override
  String authenticateWithKey(String arg0) {
    return '鍵$arg0で認証します。';
  }

  @override
  String get cancelConnection => '接続をキャンセル';

  @override
  String get reject => '拒否';

  @override
  String get trustAndConnect => '信頼して接続';

  @override
  String get logIn => 'ログイン';

  @override
  String get continueAction => '続行';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0のログイン待ち';
  }

  @override
  String get continueLogin => 'ログインを続ける';

  @override
  String pasteLines(String arg0) {
    return '$arg0行を貼り付けますか？';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return 'ターミナルに$arg0行を貼り付けると、コマンドが直ちに実行される場合があります。';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      '制御文字が含まれているため、ターミナルの操作やコマンド実行が発生する場合があります。';

  @override
  String get pasteWithoutTrailingEnter => '末尾のEnterを除いて貼り付け';

  @override
  String pasteLines2(String arg0) {
    return '$arg0行を貼り付け';
  }

  @override
  String get editText => 'テキストを編集';

  @override
  String get textToSend => '送信するテキスト';

  @override
  String get send => '送信';

  @override
  String get selectEntireLine => '行全体を選択';

  @override
  String get selectVisibleScreen => '表示中の画面を選択';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get blockSelection => '矩形選択';

  @override
  String get share => '共有';

  @override
  String get paste => '貼り付け';

  @override
  String get copy2 => 'コピー';

  @override
  String get editAndSend => '編集して送信';

  @override
  String get moreSelectionOptions => '選択メニューをさらに表示';

  @override
  String get selectionEnd => '選択範囲の終点';

  @override
  String get selectionStart => '選択範囲の始点';

  @override
  String get clearSelection => '選択を解除';

  @override
  String couldNotConnectTo(String arg0) {
    return '$arg0に接続できませんでした';
  }

  @override
  String get couldNotCompleteOperation => '操作を完了できませんでした';

  @override
  String get couldNotFinishOperation => '操作を完了できませんでした';

  @override
  String checked(String arg0) {
    return '確認時刻 · $arg0';
  }

  @override
  String occurred(String arg0) {
    return '発生時刻 · $arg0';
  }

  @override
  String get copyErrorLog => 'エラーログをコピー';

  @override
  String get close2 => '閉じる';

  @override
  String get saveElsewhere => '別の場所に保存';

  @override
  String get retry => '再試行';

  @override
  String deletedHost(String arg0) {
    return 'ホスト$arg0を削除しました';
  }

  @override
  String get ok => 'OK';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    return '$count行 · Enterで改行$arg1';
  }

  @override
  String get ctrlEnterSends => '、Ctrl Enterで送信';

  @override
  String unsupported(String arg0) {
    return ' · $arg0非対応';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return '$arg0のサーバー鍵を確認';
  }

  @override
  String get trustServerKey => 'サーバー鍵を信頼';

  @override
  String authenticateWithKey2(String arg0) {
    return '鍵$arg0で認証します。';
  }

  @override
  String get disconnectAll => 'すべて切断';

  @override
  String get disconnectAllSessions => 'すべてのセッションを切断しますか？';

  @override
  String get disconnectAll2 => 'すべて切断';

  @override
  String get removeServerKey => 'サーバー鍵を削除しますか？';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe => '次回の接続時にサーバー鍵を再度確認します。';

  @override
  String get deleteServerKey => 'サーバー鍵を削除';

  @override
  String sessions(String arg0) {
    return ' · セッション$arg0';
  }

  @override
  String get fileTransferSftp => 'ファイル転送（SFTP）';

  @override
  String get favorites => 'お気に入り';

  @override
  String get quickConnect => 'クイック接続';

  @override
  String get createSshKeyOnThisDevice => 'このデバイスにSSH鍵を作成';

  @override
  String get sort => '並べ替え';

  @override
  String get byColor => '色順';

  @override
  String get byName => '名前順';

  @override
  String get help => 'ヘルプ';

  @override
  String get unlock => 'ロック解除';

  @override
  String get couldNotPrepareAppData => 'アプリのデータを準備できませんでした';

  @override
  String get preparingTilde => 'Tildeを準備中';

  @override
  String get errorDetails => 'エラーの詳細';

  @override
  String get tildeHomeDirectory => 'Tildeのホームディレクトリ';

  @override
  String get inProgress => '処理中';

  @override
  String get newOutput => '新しい出力';

  @override
  String get error => 'エラー';

  @override
  String get notConnected => '未接続';

  @override
  String sessions2(num count) {
    return ' · $countセッション';
  }

  @override
  String get connectToYourFirstServer => '最初のサーバーに接続しましょう';

  @override
  String get saveAHostToConnectWithADoubleClick =>
      'ホストを保存すると、次回からダブルクリックで接続できます。';

  @override
  String get saveAServerToConnectQuicklyNextTime => 'サーバーを保存すると、次回からすぐに接続できます。';

  @override
  String get saveAddressUserAndAuthentication => 'アドレス・ユーザー・認証情報を保存';

  @override
  String get connectNow => '今すぐ接続';

  @override
  String get connectByAddress => 'アドレスで接続';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      '検索欄にssh user@hostを入力してEnterを押す';

  @override
  String get privateKeyFileSuchAsIdEd25519 => 'id_ed25519などの秘密鍵ファイル';

  @override
  String connectingTo(String arg0, String arg1) {
    return '$arg0:$arg1に接続中';
  }

  @override
  String get negotiatingSshConnection => 'SSH接続をネゴシエート中';

  @override
  String get verifyingServerKey => 'サーバー鍵を確認中';

  @override
  String authenticating(String arg0) {
    return '$arg0を認証中';
  }

  @override
  String get authenticated => '認証済み';

  @override
  String get openingTerminalSession => 'ターミナルセッションを開始中';

  @override
  String get confirmSshKeyUse => 'SSH鍵の使用を確認';

  @override
  String get sshPrivateKeyPassphrase => 'SSH秘密鍵のパスフレーズ';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      'サーバー鍵が変更されたため、接続をブロックしました。保存済みのサーバー鍵を確認し、手動で削除してください。';

  @override
  String get preparingSshLogin => 'SSHログインを準備中';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      'ログインしましたが、パスワードを保存できませんでした。ホストの編集画面で保存し直してください。';

  @override
  String sendTo(String arg0) {
    return '$arg0に送信';
  }

  @override
  String get send2 => '送信';

  @override
  String get terminalSize => 'ターミナルのサイズ';

  @override
  String get columns => '列';

  @override
  String get rows => '行';

  @override
  String get fullScreen => '全画面';

  @override
  String get autoHideTitleBar => 'タイトルバーを自動的に隠す';

  @override
  String get terminalSizeColumnsRows => 'ターミナルのサイズ · 列×行';

  @override
  String get resize => 'サイズを変更';

  @override
  String get text8024LeaveBlankForAutomaticSizing => '80×24 · 空欄で自動調整';

  @override
  String get enterColumnsRowsSuchAs8024 => '80×24のように、列×行で入力してください。';

  @override
  String get terminalLinks => 'ターミナル内のリンク';

  @override
  String get noLinksOnScreen => '画面内にリンクはありません。';

  @override
  String get enterText => 'テキストを入力';

  @override
  String get links => 'リンク';

  @override
  String get reconnect => '再接続';

  @override
  String get couldNotVerifyServerKey => 'サーバー鍵を確認できませんでした';

  @override
  String get couldNotLogIn => 'ログインできませんでした';

  @override
  String get couldNotOpenTerminal => 'ターミナルを開けませんでした';

  @override
  String get couldNotConnectToServer => 'サーバーに接続できませんでした';

  @override
  String connectingTo2(String arg0) {
    return '$arg0に接続中';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      '保存済みのサーバー鍵と、サーバー管理者から提供されたフィンガープリントを確認してください。';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      'ユーザー名と認証情報を確認してください。SSH鍵を使用する場合は、公開鍵をサーバーに登録してください。';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      'サーバーのアドレス、ポート、ネットワーク接続を確認してください。';

  @override
  String get connectionLog => '接続ログ';

  @override
  String get deviceList => 'デバイス一覧';

  @override
  String get view => '表示';

  @override
  String get dismissBanner => 'バナーを閉じる';

  @override
  String get connectionClosed => '接続を終了しました';

  @override
  String get theServerEndedTheSession => 'サーバーがセッションを終了しました';

  @override
  String get connectionEndedAfterAuthenticationFailed => '認証に失敗したため接続を終了しました';

  @override
  String get connectionLost => '接続が切れました';

  @override
  String ended(String arg0) {
    return '終了 · $arg0';
  }

  @override
  String get copyOutput => '出力をコピー';

  @override
  String sshKey(String arg0) {
    return '$arg0のSSH鍵';
  }

  @override
  String get couldNotPrepareRegistration => '登録の準備ができませんでした';

  @override
  String get keyToRegister => '登録する鍵';

  @override
  String get newBiometricKey => '新しい生体認証鍵';

  @override
  String get createNewSshKey => '新しいSSH鍵を作成';

  @override
  String get registerSshKeyLogin => 'SSH鍵ログインを登録';

  @override
  String keyRegistration(String arg0, String arg1) {
    return '$arg0の鍵登録$arg1';
  }

  @override
  String get anotherHost => '別のホスト';

  @override
  String get isInProgress => 'を実行中です';

  @override
  String get isComplete => 'が完了しました';

  @override
  String get registrationPreparationForThisHost => 'このホストへの鍵登録を準備';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      '公開鍵を登録してから、別の接続で鍵ログインを検証します。';

  @override
  String get newKeyName => '新しい鍵の名前';

  @override
  String get progress => '進行状況';

  @override
  String get installPublicKey => '公開鍵を登録';

  @override
  String get verifyKeyLogin => '鍵ログインを検証';

  @override
  String get applyToHost => 'ホストに適用';

  @override
  String get theServerRejectedTheKey => 'サーバーが鍵を拒否しました';

  @override
  String get theServerRequiresAdditionalAuthentication => 'サーバーが追加の認証を求めています';

  @override
  String get couldNotCompleteThisStep => 'この手順を完了できませんでした';

  @override
  String get installedOnServer => 'サーバーに登録しました';

  @override
  String get keyAlreadyInstalled => '鍵は既に登録されています';

  @override
  String get keyLoginVerified => '鍵ログインを検証しました';

  @override
  String get theServerRejectedThisKey => 'サーバーがこの鍵を拒否しました';

  @override
  String get registrationComplete => '登録完了';

  @override
  String usingKey(String arg0) {
    return '鍵$arg0を使用中';
  }

  @override
  String get removeSavedPasswordForThisHost => 'このホストの保存済みパスワードを削除';

  @override
  String get registerAndVerify => '登録して検証';

  @override
  String get continueInBackground => 'バックグラウンドで続行';

  @override
  String get previewColorThemeFontAndMargins => 'カラーテーマ・フォント・余白のプレビュー';

  @override
  String get srcBuildSampleMd => '\nsrc  build  sample.md';

  @override
  String get specialKeyBarPreview => '特殊キーバーのプレビュー';

  @override
  String get fileTransferIsAvailableForSshHosts => 'SSHホストではファイル転送を利用できます。';

  @override
  String get registerAKeyFromAConnectedSshSession =>
      '接続済みのSSHセッションから鍵を登録してください。';

  @override
  String get onlySshAndLocalConnectionsAreSupported => 'SSH接続とローカル接続のみ対応しています。';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      '接続方式が変更されました。ホームから新しいセッションを開いてください。';

  @override
  String get calculatingTimeRemaining => '残り時間を計算中';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return '残り$arg0分$arg1秒';
  }

  @override
  String secondsRemaining(String arg0) {
    return '残り$arg0秒';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · キャンセル中…';
  }

  @override
  String get checkingSize => 'サイズを確認中';

  @override
  String get calculatingSpeed => '速度を計算中';

  @override
  String active(String arg0) {
    return '実行中$arg0';
  }

  @override
  String queued(String arg0) {
    return '待機中$arg0';
  }

  @override
  String failed(String arg0) {
    return '失敗$arg0';
  }

  @override
  String completed(String arg0) {
    return '完了$arg0';
  }

  @override
  String cancelled(String arg0) {
    return 'キャンセル$arg0';
  }

  @override
  String get noTransfers => '転送はありません';

  @override
  String get queued2 => '待機中';

  @override
  String get paused => '一時停止中';

  @override
  String get completed2 => '完了';

  @override
  String get failed2 => '失敗';

  @override
  String get cancelOperation => '操作をキャンセル';

  @override
  String get openFolder => 'フォルダーを開く';

  @override
  String couldNotComplete(String arg0) {
    return '$arg0を完了できませんでした';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return '$arg0 / $arg1項目$arg2';
  }

  @override
  String transfer(String arg0) {
    return '転送 · $arg0';
  }

  @override
  String get transferQueue => '転送キュー';

  @override
  String get clearCompleted => '完了した項目を消去';

  @override
  String get collapseTransferQueue => '転送キューを折りたたむ';

  @override
  String get expandTransferQueue => '転送キューを展開';

  @override
  String get all => 'すべて';

  @override
  String get selectARegularFile => '通常のファイルを選択してください。';

  @override
  String get aFileWithTheSameNameAlreadyExists => '同じ名前のファイルが既にあります。';

  @override
  String get theSourceFileSizeChangedDuringTransfer =>
      '転送中に転送元ファイルのサイズが変わりました。';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer =>
      '転送中に同じ名前のファイルが作成されました。';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return '一時アップロードファイルを削除できませんでした。サーバー上で確認してください。$arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return '一時アップロードファイルを確認できませんでした。サーバー上で確認してください。$arg0';
  }

  @override
  String get changePermissions => 'アクセス権を変更';

  @override
  String get read => '読み取り';

  @override
  String get write => '書き込み';

  @override
  String get execute => '実行';

  @override
  String get owner => '所有者';

  @override
  String get group => 'グループ';

  @override
  String get other => 'その他';

  @override
  String get octalPermissions => '8進数のアクセス権';

  @override
  String get enterThreeOrFourDigitsFrom0To7 => '0～7の数字を3桁または4桁で入力してください。';

  @override
  String get changePermissions2 => 'アクセス権を変更';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return 'フォルダーを開けませんでした。パスとアクセス権を確認してください。\n$arg0';
  }

  @override
  String get newFolder => '新しいフォルダー';

  @override
  String get create => '作成';

  @override
  String get destinationFolder => '移動先のフォルダー';

  @override
  String move(String arg0) {
    return '$arg0を移動';
  }

  @override
  String moveItems(String arg0) {
    return '$arg0項目を移動';
  }

  @override
  String get parentFolder => '親フォルダー';

  @override
  String get folderPath => 'フォルダーのパス';

  @override
  String get editPath => 'パスを編集';

  @override
  String get moveHere => 'ここに移動';

  @override
  String permanentlyDeleteItems(String arg0) {
    return '$arg0項目を完全に削除しますか？';
  }

  @override
  String childItems(String arg0) {
    return '配下の$arg0項目';
  }

  @override
  String get checkingContents => '内容を確認中…';

  @override
  String get couldNotInspectFolderContentsTryAgain =>
      'フォルダーの内容を確認できませんでした。再試行してください。';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return 'フォルダーの内容も含め、全$arg0項目を削除します。元に戻すことはできません。';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      'ゴミ箱を使わずに直接削除します。元に戻すことはできません。';

  @override
  String get deletePermanently => '完全に削除';

  @override
  String get unknownModificationDate => '更新日時不明';

  @override
  String get aFileWithTheSameNameExists => '同じ名前のファイルがあります';

  @override
  String transferringItems(String arg0, String arg1) {
    return '$arg0 / $arg1項目を転送中';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict =>
      '重複する各ファイルについて、残すファイルを選択してください。';

  @override
  String get fileBeingUploaded => 'アップロードするファイル';

  @override
  String get fileBeingDownloaded => 'ダウンロードするファイル';

  @override
  String get existingFileOnServer => 'サーバー上の既存ファイル';

  @override
  String get existingFileOnDevice => 'デバイス上の既存ファイル';

  @override
  String get unknownSize => 'サイズ不明';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile =>
      '既存ファイルを残し、このファイルのコピーをスキップします。';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      '両方を残します。コピーするファイルの拡張子の前に、(1)から順に空いている番号を付けます。';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      'コピーするファイルで既存ファイルを上書きします。元に戻すことはできません。';

  @override
  String get cancelCopyingKeepTheExistingFile =>
      '残りのファイルを含む、このコピー処理全体をキャンセルします。既存のファイルは保持します。';

  @override
  String applyToRemainingItems(String arg0) {
    return '残りの$arg0項目にも適用';
  }

  @override
  String get cancelTransfer => '転送をキャンセル';

  @override
  String get cancelCopy => 'コピーをキャンセル';

  @override
  String get loggingInForFileTransfer => 'ファイル転送のためにログイン中';

  @override
  String get couldNotLogInForFileTransfer => 'ファイル転送のためのログインに失敗しました。';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      'プレビューできるのは4 MiB以下のファイルです。ダウンロードして開いてください。';

  @override
  String get saveFile => 'ファイルを保存';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      'エディターからフォルダーやシンボリックリンクを上書きすることはできません。';

  @override
  String get serverFileChanged => 'サーバー上のファイルが変更されています';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\n編集開始後にサーバー上のファイルが変更されました。上書きしますか？';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\n既存のファイルを上書きしますか？';
  }

  @override
  String get overwrite => '上書き';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      'サーバーに再接続できませんでした。ファイル一覧で認証を確認してください。';

  @override
  String get saveACopyElsewhere => '別の場所にコピーを保存';

  @override
  String get saveCopy => 'コピーを保存';

  @override
  String get enterAnAbsolutePathIncludingTheFileName =>
      'ファイル名を含む絶対パスを入力してください。';

  @override
  String get enterAPathDifferentFromTheOriginal => '元のファイルとは異なるパスを入力してください。';

  @override
  String get newFile => '新しいファイル';

  @override
  String get anItemWithTheSameNameAlreadyExists => '同じ名前の項目が既にあります。';

  @override
  String get thisItemIsBeingTransferred => 'この項目は転送中です。';

  @override
  String get rename => '名前を変更';

  @override
  String get change => '変更';

  @override
  String get creatingFolder => 'フォルダーを作成中';

  @override
  String get folderCreated => 'フォルダーを作成しました。';

  @override
  String get deleting => '削除中';

  @override
  String deletingItems(String arg0) {
    return '$arg0項目を削除中';
  }

  @override
  String deletedItems(String arg0) {
    return '$arg0項目を削除しました。';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · $arg0項目は削除済みです。';
  }

  @override
  String get changingPermissions => 'アクセス権を変更中';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged =>
      'シンボリックリンクのアクセス権は変更しません。';

  @override
  String get permissionsChanged => 'アクセス権を変更しました。';

  @override
  String operationCancelled(String arg0) {
    return '操作をキャンセルしました。$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return '操作を完了できませんでした。$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return '$arg0項目を$arg1 · 貼り付け先のフォルダーで貼り付けてください。';
  }

  @override
  String get cut => '切り取り';

  @override
  String get noFilesToPaste => '貼り付けるファイルがありません。';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr =>
      '同じ場所や転送元のフォルダー内に移動・コピーすることはできません。';

  @override
  String get move2 => '移動';

  @override
  String get copyTemporaryDownloadAndUpload => 'コピー（一時ダウンロード後にアップロード）';

  @override
  String get upload => 'アップロード';

  @override
  String get download => 'ダウンロード';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      'このプラットフォームでは保存先フォルダーの選択に対応していません。';

  @override
  String get connectionClosed2 => '接続は閉じられました。';

  @override
  String get downloadToFileManager => 'ファイルマネージャーにダウンロード';

  @override
  String get theTemporaryExportPathAlreadyExists => 'エクスポート用の一時パスが既に存在します。';

  @override
  String get cancelTransfersAndClose => '転送をキャンセルして閉じる';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      'このタブの実行中の転送と待機中の操作をキャンセルしますか？';

  @override
  String get uploadFolder => 'フォルダーをアップロード';

  @override
  String get connectionCancelled => '接続をキャンセルしました';

  @override
  String get couldNotOpenFileList => 'ファイル一覧を開けませんでした';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · ファイル転送';
  }

  @override
  String get fileList => 'ファイル一覧';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      'フォルダーのパスとアクセス権を確認してから、再試行してください。';

  @override
  String get bookmarkCurrentFolder => '現在のフォルダーをお気に入りに追加';

  @override
  String get recentLocations => '最近使った場所';

  @override
  String selected(String arg0) {
    return '$arg0項目を選択中';
  }

  @override
  String get forward => '進む';

  @override
  String get remoteFolderPath => 'リモートフォルダーのパス';

  @override
  String get bookmarksAndRecentLocations => 'お気に入りと最近使った場所';

  @override
  String get refresh => '更新';

  @override
  String get findInCurrentFolder => '現在のフォルダー内で検索';

  @override
  String get readOnly => '読み取り専用';

  @override
  String get discardChanges2 => '変更を破棄';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\n保存していない変更を破棄しますか？';
  }

  @override
  String get doNotSave => '保存しない';

  @override
  String get editing => '編集中';

  @override
  String get saveCopyKeepOriginalUnchanged => 'コピーを保存 · 元のファイルは変更しない';

  @override
  String savedACopyTo(String arg0) {
    return '$arg0にコピーを保存しました。';
  }

  @override
  String get saved2 => '保存しました。';

  @override
  String get couldNotOpenFile => 'ファイルを開けませんでした';

  @override
  String couldNotOpen(String arg0) {
    return '$arg0を開けませんでした';
  }

  @override
  String get previewIsUnsupportedForThisFileType => 'このファイル形式のプレビューには対応していません。';

  @override
  String get couldNotSaveYourChangesHaveBeenKept => '保存できませんでした。変更内容は保持されています。';

  @override
  String couldNotSave2(String arg0) {
    return '$arg0を保存できませんでした';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · $arg1行 · $arg2 B';
  }

  @override
  String get unsupportedFileType => '対応していないファイルの種類です。';

  @override
  String get unsupportedRemoteFileType => '対応していないリモートファイルの種類です。';

  @override
  String get theTransferSourceChangedStartANewTransfer =>
      '転送元が変更されました。新しい転送を開始してください。';

  @override
  String get anItemWithThisNameExistsAndIsNot => '同じ名前の項目がありますが、フォルダーではありません。';

  @override
  String get cannotOverwriteAFolderWithAFile => 'フォルダーをファイルで上書きすることはできません。';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      '名前にパス区切り文字は使えません。また、名前を「.」や「..」にすることはできません。';

  @override
  String get aFileOrFolderWithTheSameNameAlready => '同じ名前のファイルまたはフォルダーが既にあります。';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      'フォルダー自身やその配下に移動することはできません。';

  @override
  String get cannotDeleteTheRootFolder => 'ルートフォルダーは削除できません。';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      'サーバーがアクセスを拒否しました。転送先パスのアクセス権を確認してください。';

  @override
  String get theFileOrFolderNoLongerExists => 'ファイルまたはフォルダーが見つかりません。';

  @override
  String get serverConnectionLost => 'サーバーへの接続が切れました。';

  @override
  String get theServerCouldNotCompleteTheOperation => 'サーバーで操作を完了できませんでした。';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd =>
      'サーバーが応答していません。アドレスとネットワークを確認してください。';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      'サーバーで認証できませんでした。ユーザー名、鍵、パスワードを確認してください。';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return 'サーバーが接続$arg0を拒否しました。SSHの起動状況とポート設定を確認してください。';
  }

  @override
  String onPort(String arg0) {
    return '（ポート$arg0）';
  }

  @override
  String get checkTheServerConnection => 'サーバーと通信できませんでした。ネットワーク接続を確認してください。';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      '予期しないエラーです。以下の詳細をコピーしてお問い合わせください。';

  @override
  String get transferCancelled => '転送をキャンセルしました。';

  @override
  String get invalidFileName => 'ファイル名が正しくありません。';

  @override
  String get theFileWasNotReceivedCompletely => 'ファイルを最後まで受信できませんでした。';

  @override
  String get size => 'サイズ';

  @override
  String get modified => '更新日時';

  @override
  String get permissions => 'アクセス権';

  @override
  String get ownerUid => '所有者UID';

  @override
  String get groupGid => 'グループGID';

  @override
  String get showHiddenFilesAndFolders => '隠しファイルとフォルダーを表示';

  @override
  String get descending => '降順';

  @override
  String get visibleColumns => '表示する列';

  @override
  String get preview => 'プレビュー';

  @override
  String get move3 => '移動…';

  @override
  String get copyPath => 'パスをコピー';

  @override
  String get info => '情報';

  @override
  String get changePermissions3 => 'アクセス権を変更…';

  @override
  String get fileInformation => 'ファイル情報';

  @override
  String get path => 'パス';

  @override
  String get type2 => '種類';

  @override
  String get folder => 'フォルダー';

  @override
  String get symbolicLink => 'シンボリックリンク';

  @override
  String get file => 'ファイル';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get location => '場所';

  @override
  String selected2(String arg0, String arg1) {
    return '$arg0項目を選択中 · $arg1';
  }

  @override
  String get parentFolderBackspace => '親フォルダー（Backspace）';

  @override
  String get loading => '読み込み中…';

  @override
  String get noFilesToDisplay => '表示するファイルがありません。';

  @override
  String get noMatchingFiles => '一致するファイルがありません。';

  @override
  String get applyNewName => '新しい名前を適用';

  @override
  String actions(String arg0) {
    return '$arg0の操作';
  }

  @override
  String items3(String arg0, String arg1) {
    return '$arg0項目$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · $arg0項目を非表示／フィルター中';
  }

  @override
  String copy3(String arg0) {
    return '$arg0のコピー';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return '$arg0台のホストでアプリの既定プロファイルを使用するようになります。';
  }

  @override
  String get deleteThisProfile => 'このプロファイルを削除します。';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return '$arg0台のホストの接続設定は残りますが、共通パスワードは削除されます。';
  }

  @override
  String delete2(String arg0) {
    return '$arg0を削除';
  }

  @override
  String get setAsDefault => '既定に設定';

  @override
  String add2(String arg0) {
    return '$arg0を追加';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      '複数のホストでユーザー名・鍵・パスワードを共有します。';

  @override
  String get default2 => ' · 既定';

  @override
  String get noHostsUsingThis => '使用しているホストはありません';

  @override
  String hosts(num count) {
    return '$count台のホスト';
  }

  @override
  String get privateKeyPassphrase => '秘密鍵のパスフレーズ';

  @override
  String get leaveBlankIfThereIsNoPassphrase => 'パスフレーズがなければ空欄にしてください。';

  @override
  String get deleteKey2 => '鍵を削除';

  @override
  String deleteKey3(String arg0) {
    return '鍵$arg0を削除しますか？';
  }

  @override
  String get savePublicKeyFile => '公開鍵ファイルを保存';

  @override
  String get addKeyFile => '鍵ファイルを追加';

  @override
  String get newKey => '新しい鍵';

  @override
  String get couldNotCompleteKeyOperation => '鍵の操作を完了できませんでした';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      'インポートした秘密鍵はアプリの保護された領域から使用します。保存したパスフレーズはiOS Keychainで保護されます。';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      '秘密鍵ファイルは元の場所から使用します。保存したパスフレーズはWindowsアカウントで保護されます。';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      '秘密鍵はAndroid Keystoreで作成され、エクスポートできません。従来の秘密鍵は無効の状態で保持されます。';

  @override
  String get disabled => '無効';

  @override
  String options(String arg0) {
    return '$arg0のオプション';
  }

  @override
  String get deleteForwarding => '転送設定を削除';

  @override
  String deleteSettingsFor(String arg0) {
    return '$arg0の設定を削除しますか？';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · ポート転送';
  }

  @override
  String get addForwarding => '転送設定を追加';

  @override
  String get sessionToControl => '操作するセッション';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · スイッチの変更はすぐに適用されます';
  }

  @override
  String get defaultOnConnection => '接続時の既定値';

  @override
  String get couldNotLoadForwarding => '転送設定を読み込めませんでした';

  @override
  String get socks4UnsupportedChangeToSocks5 => 'SOCKS4非対応 · SOCKS5に変更してください';

  @override
  String get removeServerKeyTrust => 'サーバー鍵への信頼を解除';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\n次回の接続時にサーバー鍵を再度確認します。';
  }

  @override
  String get noTrustedServerKeys => '信頼したサーバー鍵はありません。';

  @override
  String get use => '使用';

  @override
  String get editPalette => 'パレットを編集';

  @override
  String get export => 'エクスポート';

  @override
  String get defaultTheme => '既定のテーマ';

  @override
  String get customTheme => 'カスタムテーマ';

  @override
  String get nameForDuplicateTheme => '複製するテーマの名前';

  @override
  String get themeName => 'テーマ名';

  @override
  String get deleteTheme => 'テーマを削除';

  @override
  String deleteTheme2(String arg0) {
    return 'テーマ$arg0を削除しますか？';
  }

  @override
  String get newThemeName => '新しいテーマの名前';

  @override
  String get newTheme => '新しいテーマ';

  @override
  String get import => 'インポート';

  @override
  String get textColor => '文字色';

  @override
  String get backgroundColor => '背景色';

  @override
  String get cursorAndAppAccent => 'カーソルとアプリのアクセント色';

  @override
  String get couldNotLoadColorTheme => 'カラーテーマを読み込めませんでした';

  @override
  String get makeACopyToEditTheColors => 'コピーを作成して色を編集してください。';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  sample.md\n';

  @override
  String get defaultColors => '既定の色';

  @override
  String get lowContrastAgainstBackground => '背景とのコントラストが低くなっています';

  @override
  String get ansiPalette => 'ANSIパレット';

  @override
  String ansiColor(String arg0) {
    return 'ANSI色$arg0';
  }

  @override
  String get findServer => 'サーバーを検索';

  @override
  String get verifyServerKey => 'サーバー鍵を確認';

  @override
  String seconds(String arg0) {
    return '$arg0秒';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain =>
      '広告のプライバシー設定を開けませんでした。再試行してください。';

  @override
  String get ad => '広告';

  @override
  String get adPrivacySettings => '広告のプライバシー設定';

  @override
  String get googleFontsMonospace => 'Google Fonts · 等幅';

  @override
  String get searchSettings => '設定を検索';

  @override
  String get keyboard => 'キーボード';

  @override
  String get gestures => 'ジェスチャー';

  @override
  String get connectionsAndNotifications => '接続と通知';

  @override
  String get securityAndBackup => 'セキュリティとバックアップ';

  @override
  String get manageFonts => 'フォントを管理';

  @override
  String get specialKeyBar => '特殊キーバー';

  @override
  String specialKeys(String arg0) {
    return '特殊キー$arg0個';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return '2本指で横にスワイプ · $arg0';
  }

  @override
  String get tmuxWindows => 'tmuxウィンドウ';

  @override
  String get disabled2 => '無効';

  @override
  String get defaultTerminal => '既定のターミナル';

  @override
  String get notificationsAndBell => '通知とベル';

  @override
  String sshKeys2(num count) {
    return 'SSH鍵$count個';
  }

  @override
  String get helpAndLogs2 => 'ヘルプとログ';

  @override
  String get horizontalMargins => '左右の余白';

  @override
  String get lines => '行';

  @override
  String get appTheme => 'アプリのテーマ';

  @override
  String get systemTheme => 'システムのテーマ';

  @override
  String get light => 'ライト';

  @override
  String get dark => 'ダーク';

  @override
  String get font => 'フォント';

  @override
  String get orientation => '画面の向き';

  @override
  String get alwaysRotate => '常に回転';

  @override
  String get portrait => '縦向き';

  @override
  String get landscape => '横向き';

  @override
  String get hideStatusBar => 'ステータスバーを隠す';

  @override
  String get specialKeyLayout => '特殊キーの配置';

  @override
  String get showWhenKeyboardIsClosed => 'キーボードを閉じても表示';

  @override
  String get whenPressingCtrlOrAlt => 'CtrlまたはAltを押したとき';

  @override
  String get once => '1回';

  @override
  String get sticky => '固定';

  @override
  String get stickyAltOnly => 'Altのみ固定';

  @override
  String get keyboardToggleButton => 'キーボード切り替えボタン';

  @override
  String get twoFingerHorizontalSwipe2 => '2本指で横にスワイプ';

  @override
  String get doNothing => '何もしない';

  @override
  String get switchSessions => 'セッションを切り替え';

  @override
  String get switchTmuxWindows => 'tmuxウィンドウを切り替え';

  @override
  String get prefixKey => 'プレフィックスキー';

  @override
  String get twoFingerVerticalSwipe => '2本指で縦にスワイプ';

  @override
  String get scroll => 'スクロール';

  @override
  String get volumeButtonsChangeFontSize => '音量ボタンで文字サイズを変更';

  @override
  String get specialKeyVibration => '特殊キーの振動';

  @override
  String get defaultTerminalProfile => '既定のターミナルプロファイル';

  @override
  String get manageTerminalProfiles => 'ターミナルプロファイルを管理';

  @override
  String itemCount(String arg0) {
    return '$arg0';
  }

  @override
  String get appearance => '外観';

  @override
  String get terminalTypeTerm => 'ターミナルの種類（TERM）';

  @override
  String get addTerminalType => 'ターミナルの種類を追加';

  @override
  String get terminalType => 'ターミナルの種類';

  @override
  String get keepScreenAwakeWhileConnected => '接続中は画面をオンに保つ';

  @override
  String get theTerminalScreenWillStayAwake => 'ターミナルの画面が自動でオフにならなくなります';

  @override
  String get preventWiFiSleep => 'Wi-Fiのスリープを防止';

  @override
  String get usesMoreBattery => 'バッテリーの消費が増えます';

  @override
  String get backgroundConnectionNotification => 'バックグラウンド接続の通知';

  @override
  String get pinnedWhileConnected => '接続中は通知を固定表示';

  @override
  String get terminalBell => 'ターミナルのベル';

  @override
  String get whenTheBellRings => 'ベルが鳴ったとき';

  @override
  String get ignore => '無視';

  @override
  String get sound => '音';

  @override
  String get vibration => '振動';

  @override
  String get soundAndVibration => '音と振動';

  @override
  String get volume => '音量';

  @override
  String get notifications => '通知';

  @override
  String get notificationPermissionRequired => '通知の許可が必要です';

  @override
  String get allow => '許可';

  @override
  String get enableConnectionNotifications => '接続通知を有効にする';

  @override
  String get allowBellAndDisconnectionNotifications => 'ベルと切断の通知を許可します';

  @override
  String get bellInBackground => 'バックグラウンドでのベル通知';

  @override
  String get onDisconnect => '切断時';

  @override
  String get androidNotificationSettings => 'Androidの通知設定';

  @override
  String get notificationsOff => '通知が無効です';

  @override
  String get notificationsAllowed => '通知が許可されています';

  @override
  String get lock => 'ロック';

  @override
  String get unlockWhenStartingTheApp => 'アプリ起動時にロック解除を求める';

  @override
  String get setUpAScreenLockFirst => '先に画面ロックを設定してください';

  @override
  String get fingerprintOrScreenLock => '指紋または画面ロック';

  @override
  String get keysAndServers => '鍵とサーバー';

  @override
  String get configurationFile => '設定ファイル';

  @override
  String get exportHosts => 'ホストをエクスポート';

  @override
  String get importHosts => 'ホストをインポート';

  @override
  String get selectDefaultFont => '既定のフォントを選択';

  @override
  String fontSample(String arg0) {
    return '$arg0 Aa あいう';
  }

  @override
  String get bundledWithApp => 'アプリに同梱';

  @override
  String get monospaceFont => '等幅フォント';

  @override
  String get deleteFont => 'フォントを削除';

  @override
  String get deleteThisFontFile => 'このフォントファイルを削除しますか？';

  @override
  String get removeFont => 'フォントを削除';

  @override
  String get preparingFont => 'フォントを準備中';

  @override
  String get importFontFile => 'フォントファイルをインポート';

  @override
  String get findOnGoogleFonts => 'Google Fontsで探す';

  @override
  String get onlyMonospaceFontsAreShown => '等幅フォントのみ表示します';

  @override
  String settings2(String arg0) {
    return '設定 › $arg0';
  }

  @override
  String get couldNotSaveSettings => '設定を保存できませんでした';

  @override
  String get resetSpecialKeyBar => '特殊キーバーをリセットしますか？';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      '高さ・キーの順序・表示を既定値に戻します。';

  @override
  String get longPressToDragTapToHide => '長押しで移動 · タップで非表示';

  @override
  String get hiddenKeys => '非表示のキー';

  @override
  String get tapAKeyToMoveItHere => 'キーをタップするとここに移動します';

  @override
  String get combineF1F12IntoFn => 'F1～F12をFnにまとめる';

  @override
  String get height => '高さ';

  @override
  String get small => '小';

  @override
  String get large => '大';

  @override
  String get default3 => '既定';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc・Ctrlは左側、キーボード・Fn・Tabは右側に固定されます。';

  @override
  String get flutterLibraryLicenses => 'Flutterライブラリのライセンス';

  @override
  String get tips => '使い方のヒント';

  @override
  String get licensesAndTerms => 'ライセンスと利用条件';

  @override
  String get projectAndContact => 'プロジェクトとお問い合わせ';

  @override
  String get diagnostics => '診断';

  @override
  String get diagnosticLogs => '診断ログ';

  @override
  String get searchLogs => 'ログを検索';

  @override
  String get saveNativeCrashLog => 'ネイティブクラッシュログを保存';

  @override
  String get warning => '警告';

  @override
  String get couldNotLoadLogs => 'ログを読み込めませんでした';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      'Android KeystoreのSSH鍵のみ対応しています';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      'Android KeystoreのP-256鍵のみ対応しています';

  @override
  String get invalidEcdsaSignature => 'ECDSA署名が正しくありません';

  @override
  String get invalidEcdsaSignatureValues => 'ECDSA署名の値が正しくありません';

  @override
  String get invalidX509PublicKey => 'X509公開鍵が正しくありません';

  @override
  String get invalidPublicKeyBitString => '公開鍵のビット列が正しくありません';

  @override
  String get invalidRsaPublicKey => 'RSA公開鍵が正しくありません';

  @override
  String get invalidEcCurve => 'EC曲線が正しくありません';

  @override
  String get invalidUncompressedEcPoint => '非圧縮EC点が正しくありません';

  @override
  String get invalidEd25519PublicKey => 'Ed25519公開鍵が正しくありません';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return '対応していないSSH公開鍵アルゴリズム：$arg0';
  }

  @override
  String get unsupportedSshEcCurve => '対応していないSSH EC曲線です';

  @override
  String get invalidDerSequence => 'DERシーケンスが正しくありません';

  @override
  String get privateKeyExportIsNotSupported => '秘密鍵のエクスポートには対応していません';

  @override
  String get publicKeyIsUnavailable => '公開鍵を使用できません';

  @override
  String unsupportedTerminalKey(String arg0) {
    return '対応していないターミナルキー：$arg0';
  }

  @override
  String get disconnectBeforeReconnecting => '接続を切断してから再接続してください';

  @override
  String get localShellIsNotOpen => 'ローカルシェルが開いていません';

  @override
  String get unknownModifier => '不明な修飾キーです';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return '対応していないローカルターミナル操作：$arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'SSH公開鍵の行の形式が正しくありません';

  @override
  String get serverDidNotConfirmPublicKeyRegistration =>
      'サーバーで公開鍵の登録を確認できませんでした。';

  @override
  String get logInToASavedSshHostBeforeRegistering =>
      '保存したSSHホストにログインしてから鍵を登録してください。';

  @override
  String get theSelectedSshKeyNoLongerExists => '選択したSSH鍵が見つかりません。';

  @override
  String get aUniqueBiometricKeyNameIsRequired =>
      'ほかの鍵と重複しない生体認証鍵の名前を入力してください。';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      '元のSSH接続の認証が無効になっています。';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      '鍵だけではログインできませんでした。サーバーが追加の認証を求めている可能性があります。ログイン設定は変更していません。';

  @override
  String get theSavedHostNoLongerExists => '保存したホストが見つかりません。';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      '登録中にホストのアドレスが変更されました。ログイン設定は変更していません。';

  @override
  String get invalidPtyDimensions => 'PTYのサイズが正しくありません';

  @override
  String get sshTargetIsRequired => 'SSH接続先を指定してください';

  @override
  String get sshSessionWasClosed => 'SSHセッションは閉じられました';

  @override
  String get sshSessionIsNotConnected => 'SSHセッションが接続されていません';

  @override
  String get sshSessionsCannotBeReused => 'SSHセッションは再利用できません';

  @override
  String get noAddressForRequestedIpVersion => '指定したIPバージョンのアドレスがありません';

  @override
  String get sshHopConnectionTimedOut => '踏み台経由のSSH接続がタイムアウトしました';

  @override
  String get sshSessionHasNoShell => 'SSHセッションにシェルがありません';

  @override
  String get sshSessionRequestTimedOut => 'SSHセッションの要求がタイムアウトしました';

  @override
  String get invalidForwardBindPort => '転送の待受ポートが正しくありません';

  @override
  String get invalidForwardDestination => '転送先が正しくありません';

  @override
  String get remoteForwardingRequestTimedOut => 'リモート転送の要求がタイムアウトしました';

  @override
  String get remoteForwardingWasRefused => 'リモート転送が拒否されました';

  @override
  String get forwardConnectionTimedOut => '転送の接続がタイムアウトしました';

  @override
  String get remoteForwardDestinationTimedOut => 'リモート転送先への接続がタイムアウトしました';

  @override
  String get remoteForwardingCancellationWasRefused => 'リモート転送のキャンセルが拒否されました';

  @override
  String get sshAuthenticationCancelled => 'SSH認証をキャンセルしました';

  @override
  String get concurrentSshAuthenticationPrompt => 'SSH認証の要求が既に進行中です';

  @override
  String get sessionDisposed => 'セッションは終了しています';

  @override
  String get disconnectBeforeRefreshingSshConfiguration =>
      '接続を切断してからSSH設定を更新してください';

  @override
  String get couldNotUnlockTheSelectedKey => '選択した鍵のロックを解除できませんでした。';

  @override
  String get logInToThisServerBeforeRegisteringAKey =>
      'このサーバーにログインしてから鍵を登録してください。';

  @override
  String get sshShellIsNotOpen => 'SSHシェルが開いていません';

  @override
  String get sshIsNotConnected => 'SSHが接続されていません';

  @override
  String get portForwardIsMissing => 'ポート転送の設定がありません';

  @override
  String get unsupportedSshForwardType => '対応していないSSH転送方式です';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return '対応していないアプリのSSH操作：$arg0';
  }

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get timedOutReadingWindowsSshSettings =>
      'WindowsのSSH設定の読み込みがタイムアウトしました。';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return 'WindowsのSSH設定を読み込めませんでした。$arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable =>
      'Windowsユーザープロファイルのパスが見つかりません。';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return '対応していないSSH鍵パスの変数：$arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return 'ファイルをインポートできませんでした：$arg0';
  }

  @override
  String uploadTo(String arg0) {
    return '$arg0にアップロード';
  }

  @override
  String get currentFolder => '現在のフォルダー';

  @override
  String get windowsUserDataFolderIsUnavailable =>
      'Windowsのユーザーデータフォルダーが見つかりません。';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return 'Windowsアカウントによる認証情報の保護に失敗しました。$arg0';
  }

  @override
  String get altDrag => 'Altを押しながらドラッグ';

  @override
  String get keyUp => '上へ';

  @override
  String get keyDown => '下へ';

  @override
  String get keyHome => '行の先頭へ';

  @override
  String get keyEnd => '行の末尾へ';

  @override
  String get keyPageUp => '前のページへ';

  @override
  String get keyPageDown => '次のページへ';

  @override
  String get keyInsert => '挿入';

  @override
  String get keyDelete => '削除';

  @override
  String get skipCopy => 'スキップ';

  @override
  String get keepBothFiles => '両方を保持';

  @override
  String get cancelJobNoApplyAll => 'コピーをキャンセルする場合、残りのファイルへの一括適用はできません。';

  @override
  String get editAuthentication => '認証設定を編集';

  @override
  String get serverMessage => 'サーバーからのメッセージ';

  @override
  String get cancellingOperation => 'キャンセル中…';

  @override
  String get transferHeading => '転送';
}
