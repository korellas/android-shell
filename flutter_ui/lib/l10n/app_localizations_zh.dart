// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '主页';

  @override
  String get terminal => '终端';

  @override
  String files(String arg0) {
    return '$arg0 · 文件';
  }

  @override
  String get newHost => '新建主机';

  @override
  String edit(String arg0) {
    return '编辑$arg0';
  }

  @override
  String get disconnectAndCloseTab => '断开连接并关闭标签页';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return '要断开与$arg0的连接并关闭此标签页吗？';
  }

  @override
  String get disconnectAndClose => '断开并关闭';

  @override
  String get newTerminal => '新建终端';

  @override
  String get fileTransfer => '文件传输';

  @override
  String get edit2 => '编辑';

  @override
  String get removeFromFavorites => '从收藏中移除';

  @override
  String get addToFavorites => '添加到收藏';

  @override
  String get duplicate => '创建副本';

  @override
  String get portForwarding => '端口转发';

  @override
  String get disconnect => '断开连接';

  @override
  String get delete => '删除';

  @override
  String get nameForDuplicateHost => '主机副本名称';

  @override
  String copy(String arg0) {
    return '$arg0的副本';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return '要断开$arg0的所有会话吗？';
  }

  @override
  String get searchHosts => '搜索主机';

  @override
  String get searchHostsOrEnterSshAddressCtrlK => '搜索主机或输入SSH地址（Ctrl K）';

  @override
  String get addHost => '添加主机';

  @override
  String get noHostsYet => '尚无主机';

  @override
  String get openTerminals => '已打开的终端';

  @override
  String get openFiles => '已打开的文件';

  @override
  String menu(String arg0) {
    return '$arg0菜单';
  }

  @override
  String get settings => '设置';

  @override
  String get helpAndLogs => '帮助与日志';

  @override
  String get hostListCtrlB => '主机列表（Ctrl B）';

  @override
  String closeTab(String arg0) {
    return '关闭$arg0标签页';
  }

  @override
  String get newTabCtrlShiftT => '新建标签页（Ctrl Shift T）';

  @override
  String get terminalMenu => '终端菜单';

  @override
  String get importSshKey => '导入SSH密钥';

  @override
  String get openSessions => '已打开的会话';

  @override
  String session(String arg0) {
    return '会话$arg0';
  }

  @override
  String get connected => '已连接';

  @override
  String get connecting => '正在连接';

  @override
  String get disconnected => '已断开';

  @override
  String get open => '打开';

  @override
  String get connect => '连接';

  @override
  String get address => '地址';

  @override
  String get authentication => '身份验证';

  @override
  String get tryAllAvailableKeys => '尝试所有可用密钥';

  @override
  String get useServerSettings => '使用服务器设置';

  @override
  String get terminalProfile => '终端配置';

  @override
  String get appDefaultProfile => '应用默认配置';

  @override
  String get manage => '管理';

  @override
  String get minimize => '最小化';

  @override
  String get restore => '还原';

  @override
  String get maximize => '最大化';

  @override
  String get closeWindow => '关闭窗口';

  @override
  String get host => '主机';

  @override
  String get profile => '配置';

  @override
  String get sharedLoginAccount => '共用登录账户';

  @override
  String get sshKeys => 'SSH密钥';

  @override
  String enter(String arg0) {
    return '请输入$arg0。';
  }

  @override
  String get enterAWholeNumber => '请输入整数。';

  @override
  String get checkThePortRange => '请检查端口范围。';

  @override
  String currentValue(String arg0) {
    return '$arg0（当前值）';
  }

  @override
  String get select => '选择';

  @override
  String get defaultValue => '默认值';

  @override
  String get dsaUnsupported => '（不支持DSA）';

  @override
  String get windowsDefaultKeysAndAddedKeys => 'Windows默认密钥和已添加的密钥';

  @override
  String get noKey => '不使用密钥';

  @override
  String get passwordSaved => '密码（已保存）';

  @override
  String get password => '密码';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      '加密保存在此设备上。恢复到其他设备后需要重新输入。';

  @override
  String get storedEncryptedOnThisDevice => '加密保存在此设备上。';

  @override
  String get deleteSavedPassword => '删除已保存的密码';

  @override
  String get accountName => '账户名称';

  @override
  String get username => '用户名';

  @override
  String appliesToHosts(String arg0) {
    return '应用于$arg0台主机';
  }

  @override
  String get display => '显示';

  @override
  String get profileName => '配置名称';

  @override
  String get colorTheme => '配色主题';

  @override
  String get terminalFont => '终端字体';

  @override
  String get appDefault => '应用默认值';

  @override
  String get fontSize => '字号';

  @override
  String get characterEncoding => '字符编码';

  @override
  String get deleteKey => '删除键';

  @override
  String get columnsAutomatic => '列数 · 自动';

  @override
  String get rowsAutomatic => '行数 · 自动';

  @override
  String get forwarding => '转发';

  @override
  String get forwardingName => '转发名称';

  @override
  String get type => '类型';

  @override
  String get local => '本地';

  @override
  String get remote => '远程';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      '将服务器端口收到的连接转发到此设备上的地址。';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      '将此设备端口收到的连接转发到服务器侧的地址。';

  @override
  String get openASocks5ProxyOnThisDevice => '在此设备上开启SOCKS5代理。';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      '不支持SOCKS4。请将类型改为SOCKS5。';

  @override
  String get listenAddressOnServer => '服务器监听地址';

  @override
  String get listenAddressOnThisDevice => '此设备的监听地址';

  @override
  String get text127001AccessibleOnlyOnThisDevice => '127.0.0.1 · 仅此设备可访问';

  @override
  String get port => '端口';

  @override
  String get destinationAddress => '目标地址';

  @override
  String get publicKey => '公钥';

  @override
  String get copyFingerprint => '复制指纹';

  @override
  String get copyPublicKey => '复制公钥';

  @override
  String get keySettings => '密钥设置';

  @override
  String get keyName => '密钥名称';

  @override
  String get confirmBeforeUse => '使用前确认';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      '使用此密钥验证身份前请求许可';

  @override
  String get importedPrivateKey => '已导入的私钥';

  @override
  String get androidKeystoreP256Key => 'Android Keystore P-256密钥';

  @override
  String get authenticateWithAnImportedPrivateKeyFile => '使用已导入的私钥文件验证身份';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice => '私钥无法从此设备导出';

  @override
  String get disabledLegacyPrivateKey => '已停用的旧版私钥';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      '请先替换为新的Android Keystore密钥，再删除。';

  @override
  String get connectionType => '连接方式';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return '不支持$arg0连接。请改用SSH或本地连接。';
  }

  @override
  String get hostName => '主机名称';

  @override
  String get name => '名称';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      '将user@host:port粘贴到地址栏，即可自动填写各项。';

  @override
  String get advanced => '高级';

  @override
  String get ipAddress => 'IP地址';

  @override
  String get automatic => '自动';

  @override
  String get jumpHost => '跳板主机';

  @override
  String get directConnection => '直接连接';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      '此连接方式不使用SSH身份验证设置。';

  @override
  String get account => '账户';

  @override
  String get doNotUse => '不使用';

  @override
  String usingAccount(String arg0) {
    return '使用账户$arg0';
  }

  @override
  String get loginKey => '登录密钥';

  @override
  String get registerKeyOnThisServer => '在此服务器上注册密钥';

  @override
  String get logInOnceWithAPasswordToInstallThe => '用密码登录一次以安装公钥';

  @override
  String get hostColor => '主机颜色';

  @override
  String get previewInTheHomeListTabsAndNotifications => '预览在主页列表、标签页和通知中的显示';

  @override
  String get customHostColor => '自定义主机颜色';

  @override
  String appDefault2(String arg0) {
    return '应用默认值 · $arg0';
  }

  @override
  String get manageProfiles => '管理配置';

  @override
  String get keepConnectionAlive => '保持连接';

  @override
  String get reconnectAutomaticallyAfterAnIOError => '发生输入/输出错误后自动重新连接';

  @override
  String get closeWithoutAsking => '关闭时不询问';

  @override
  String get closeTheTabImmediatelyAfterExit => '执行exit后立即关闭标签页';

  @override
  String get sshCompression => 'SSH压缩';

  @override
  String get enableOnlyOnSlowConnections => '仅在低速连接时启用';

  @override
  String get openTerminal => '打开终端';

  @override
  String get whenOffOnlyPortForwardingIsEnabled => '关闭后仅启用端口转发';

  @override
  String get overrideForThisHost => '仅为此主机覆盖设置';

  @override
  String get scrollback => '回滚历史';

  @override
  String linesDefault(String arg0) {
    return '行 · 默认值$arg0';
  }

  @override
  String get useCtrlAltAsMeta => '将Ctrl+Alt用作Meta';

  @override
  String get displayAndProfile => '显示与配置';

  @override
  String get session2 => '会话';

  @override
  String get editHost => '编辑主机';

  @override
  String get localShell => '本地Shell';

  @override
  String get selectKey => '选择密钥';

  @override
  String get connectionSettings => '连接设置';

  @override
  String get trustedServerKeys => '已信任的服务器密钥';

  @override
  String get nameForDuplicate => '副本名称';

  @override
  String get couldNotSave => '无法保存';

  @override
  String get details => '详情';

  @override
  String get changedFields => '已更改的字段';

  @override
  String get changePassword => '更改密码';

  @override
  String get none => '无';

  @override
  String get saving => '正在保存';

  @override
  String changed(String arg0) {
    return '已更改$arg0';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0等';
  }

  @override
  String items(num count) {
    return '$count项';
  }

  @override
  String get saved => '已保存';

  @override
  String get undo => '撤销';

  @override
  String get save => '保存';

  @override
  String get saveAndOpenNewTerminal => '保存并打开新终端';

  @override
  String get deleteHost => '删除主机';

  @override
  String get couldNotSaveChanges => '无法保存更改';

  @override
  String get add => '添加';

  @override
  String get cancel => '取消';

  @override
  String get saving2 => '正在保存…';

  @override
  String get apply => '应用';

  @override
  String get back => '返回';

  @override
  String get systemDefault => '系统默认值';

  @override
  String get appDefaultFont => '应用默认字体';

  @override
  String get newSshKey => '新建SSH密钥';

  @override
  String get enterAName => '请输入名称。';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      '在Android Keystore中创建P-256私钥，每次签名都需要生物识别验证。私钥无法复制、导出或备份。';

  @override
  String get couldNotCreateKey => '无法创建密钥';

  @override
  String get createKey => '创建密钥';

  @override
  String get search => '搜索';

  @override
  String get saving3 => '正在保存';

  @override
  String changes(String arg0) {
    return '$arg0项更改';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return '请输入$arg0到$arg1之间的值';
  }

  @override
  String decrease(String arg0) {
    return '减小$arg0';
  }

  @override
  String increase(String arg0) {
    return '增大$arg0';
  }

  @override
  String get discardChanges => '放弃更改';

  @override
  String get unsavedChangesWillBeLost => '未保存的更改将丢失。';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get discard => '放弃';

  @override
  String get selectColor => '选择颜色';

  @override
  String get brightness => '亮度';

  @override
  String get hexColor => '十六进制颜色';

  @override
  String get enterASixDigitColor => '请输入6位颜色值';

  @override
  String get menu2 => '菜单';

  @override
  String get defaultProfile => '默认配置';

  @override
  String get theSavedConnectionSettingsAreInvalid => '已保存的连接设置无效。';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return '已保存的$arg0设置无效。';
  }

  @override
  String get theSavedColorThemeIsInvalid => '已保存的配色主题无效。';

  @override
  String get checkTheSshAddress => '请检查SSH地址。';

  @override
  String get useAnSshHost => '请使用SSH主机。';

  @override
  String get thisTerminalUsesUtf8 => '此终端使用UTF-8。';

  @override
  String get colorThemeNotFound => '找不到配色主题。';

  @override
  String get enterAThemeName => '请输入主题名称。';

  @override
  String get aThemeWithThisNameAlreadyExists => '已存在同名主题。';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues => '颜色必须为3位或6位十六进制值。';

  @override
  String get invalidColorThemeFileFormat => '配色主题文件格式无效。';

  @override
  String get defaultColorIndicesMustBeBetween0And15 => '默认颜色索引必须在0到15之间。';

  @override
  String get ansiColorIndicesMustBeBetween0And15 => 'ANSI颜色索引必须在0到15之间。';

  @override
  String get invalidThemeDescriptionFormat => '主题描述格式无效。';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt => '请先复制默认主题，再进行编辑。';

  @override
  String get checkTheColorRole => '请检查颜色用途。';

  @override
  String get unsupportedThemeOperation => '不支持此主题操作。';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      '只能保存经明确确认的新服务器密钥。';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed => '只能处理传输临时文件。';

  @override
  String get checkTheSshJumpHostConnection => '请检查SSH跳板主机连接。';

  @override
  String get enterAServerAddress => '请输入服务器地址。';

  @override
  String get noHostToRestore => '没有可恢复的主机。';

  @override
  String get thisProfileIsInUse => '此配置正在使用中。';

  @override
  String get unsupportedLink => '不支持此链接。';

  @override
  String get keyFile => '密钥文件';

  @override
  String unsupportedOperation(String arg0) {
    return '不支持的操作：$arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable => 'Android Keystore密钥不可用';

  @override
  String get legacyPrivateKeyDisabled => '旧版私钥 · 已停用';

  @override
  String get toggleKeyboard => '切换键盘';

  @override
  String get endSession => '结束会话';

  @override
  String disconnectFrom(String arg0) {
    return '要断开与$arg0的连接吗？';
  }

  @override
  String get end => '结束';

  @override
  String get couldNotCloseConnection => '无法关闭连接';

  @override
  String get noOpenSessions => '没有已打开的会话。';

  @override
  String disconnected2(String arg0) {
    return '已断开$arg0';
  }

  @override
  String end2(String arg0) {
    return '结束$arg0';
  }

  @override
  String get newTab => '新建标签页';

  @override
  String close(String arg0) {
    return '关闭$arg0';
  }

  @override
  String get image => '图像';

  @override
  String get words => '单词';

  @override
  String get firstConnectionToThisServer => '首次连接此服务器';

  @override
  String get biometricAuthentication => '生物识别验证';

  @override
  String logInTo(String arg0) {
    return '登录$arg0';
  }

  @override
  String get server => '服务器';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get saveOnThisDevice => '保存在此设备上';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      '请确认此指纹与服务器管理员提供的指纹一致。';

  @override
  String get fingerprintFormat => '指纹格式';

  @override
  String authenticateWithKey(String arg0) {
    return '使用密钥$arg0验证身份。';
  }

  @override
  String get cancelConnection => '取消连接';

  @override
  String get reject => '拒绝';

  @override
  String get trustAndConnect => '信任并连接';

  @override
  String get logIn => '登录';

  @override
  String get continueAction => '继续';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0正在等待登录';
  }

  @override
  String get continueLogin => '继续登录';

  @override
  String pasteLines(String arg0) {
    return '要粘贴$arg0行吗？';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return '将$arg0行粘贴到终端可能会立即执行命令。';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      '控制字符可能触发终端操作或执行命令。';

  @override
  String get pasteWithoutTrailingEnter => '粘贴时去掉末尾回车';

  @override
  String pasteLines2(String arg0) {
    return '粘贴$arg0行';
  }

  @override
  String get editText => '编辑文本';

  @override
  String get textToSend => '要发送的文本';

  @override
  String get send => '发送';

  @override
  String get selectEntireLine => '选择整行';

  @override
  String get selectVisibleScreen => '选择可见屏幕内容';

  @override
  String get selectAll => '全选';

  @override
  String get blockSelection => '矩形选择';

  @override
  String get share => '分享';

  @override
  String get paste => '粘贴';

  @override
  String get copy2 => '复制';

  @override
  String get editAndSend => '编辑后发送';

  @override
  String get moreSelectionOptions => '更多选择选项';

  @override
  String get selectionEnd => '选择结束位置';

  @override
  String get selectionStart => '选择起始位置';

  @override
  String get clearSelection => '取消选择';

  @override
  String couldNotConnectTo(String arg0) {
    return '无法连接到$arg0';
  }

  @override
  String get couldNotCompleteOperation => '无法完成操作';

  @override
  String get couldNotFinishOperation => '无法完成操作';

  @override
  String checked(String arg0) {
    return '检查时间 · $arg0';
  }

  @override
  String occurred(String arg0) {
    return '发生时间 · $arg0';
  }

  @override
  String get copyErrorLog => '复制错误日志';

  @override
  String get close2 => '关闭';

  @override
  String get saveElsewhere => '保存到其他位置';

  @override
  String get retry => '重试';

  @override
  String deletedHost(String arg0) {
    return '已删除主机$arg0';
  }

  @override
  String get ok => '确定';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    return '$count行 · Enter换行$arg1';
  }

  @override
  String get ctrlEnterSends => '，Ctrl Enter发送';

  @override
  String unsupported(String arg0) {
    return ' · 不支持$arg0';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return '验证$arg0的服务器密钥';
  }

  @override
  String get trustServerKey => '信任服务器密钥';

  @override
  String authenticateWithKey2(String arg0) {
    return '使用密钥$arg0验证身份。';
  }

  @override
  String get disconnectAll => '断开所有连接';

  @override
  String get disconnectAllSessions => '要断开所有会话吗？';

  @override
  String get disconnectAll2 => '断开所有连接';

  @override
  String get removeServerKey => '要移除服务器密钥吗？';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe => '下次连接时将重新验证服务器密钥。';

  @override
  String get deleteServerKey => '删除服务器密钥';

  @override
  String sessions(String arg0) {
    return ' · 会话$arg0';
  }

  @override
  String get fileTransferSftp => '文件传输（SFTP）';

  @override
  String get favorites => '收藏';

  @override
  String get quickConnect => '快速连接';

  @override
  String get createSshKeyOnThisDevice => '在此设备上创建SSH密钥';

  @override
  String get sort => '排序';

  @override
  String get byColor => '按颜色';

  @override
  String get byName => '按名称';

  @override
  String get help => '帮助';

  @override
  String get unlock => '解锁';

  @override
  String get couldNotPrepareAppData => '无法准备应用数据';

  @override
  String get preparingTilde => '正在准备Tilde';

  @override
  String get errorDetails => '错误详情';

  @override
  String get tildeHomeDirectory => 'Tilde主目录';

  @override
  String get inProgress => '正在进行';

  @override
  String get newOutput => '新输出';

  @override
  String get error => '错误';

  @override
  String get notConnected => '未连接';

  @override
  String sessions2(num count) {
    return ' · $count个会话';
  }

  @override
  String get connectToYourFirstServer => '连接到您的第一台服务器';

  @override
  String get saveAHostToConnectWithADoubleClick => '保存主机后，下次双击即可连接。';

  @override
  String get saveAServerToConnectQuicklyNextTime => '保存服务器后，下次即可快速连接。';

  @override
  String get saveAddressUserAndAuthentication => '保存地址、用户和身份验证信息';

  @override
  String get connectNow => '立即连接';

  @override
  String get connectByAddress => '通过地址连接';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      '在搜索栏输入ssh user@host并按Enter';

  @override
  String get privateKeyFileSuchAsIdEd25519 => '例如id_ed25519的私钥文件';

  @override
  String connectingTo(String arg0, String arg1) {
    return '正在连接$arg0:$arg1';
  }

  @override
  String get negotiatingSshConnection => '正在协商SSH连接';

  @override
  String get verifyingServerKey => '正在验证服务器密钥';

  @override
  String authenticating(String arg0) {
    return '正在验证$arg0的身份';
  }

  @override
  String get authenticated => '身份验证成功';

  @override
  String get openingTerminalSession => '正在打开终端会话';

  @override
  String get confirmSshKeyUse => '确认使用SSH密钥';

  @override
  String get sshPrivateKeyPassphrase => 'SSH私钥口令';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      '服务器密钥已更改，连接已被阻止。请检查并手动删除已保存的服务器密钥。';

  @override
  String get preparingSshLogin => '正在准备SSH登录';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      '登录成功，但无法保存密码。请在主机编辑页面重新保存。';

  @override
  String sendTo(String arg0) {
    return '发送到$arg0';
  }

  @override
  String get send2 => '发送';

  @override
  String get terminalSize => '终端大小';

  @override
  String get columns => '列';

  @override
  String get rows => '行';

  @override
  String get fullScreen => '全屏';

  @override
  String get autoHideTitleBar => '自动隐藏标题栏';

  @override
  String get terminalSizeColumnsRows => '终端大小 · 列×行';

  @override
  String get resize => '调整大小';

  @override
  String get text8024LeaveBlankForAutomaticSizing => '80×24 · 留空则自动调整';

  @override
  String get enterColumnsRowsSuchAs8024 => '请按列×行格式输入，例如80×24。';

  @override
  String get terminalLinks => '终端链接';

  @override
  String get noLinksOnScreen => '屏幕上没有链接。';

  @override
  String get enterText => '输入文本';

  @override
  String get links => '链接';

  @override
  String get reconnect => '重新连接';

  @override
  String get couldNotVerifyServerKey => '无法验证服务器密钥';

  @override
  String get couldNotLogIn => '无法登录';

  @override
  String get couldNotOpenTerminal => '无法打开终端';

  @override
  String get couldNotConnectToServer => '无法连接到服务器';

  @override
  String connectingTo2(String arg0) {
    return '正在连接$arg0';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      '请检查已保存的服务器密钥和服务器管理员提供的指纹。';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      '请检查用户名和身份验证信息。使用SSH密钥时，请先在服务器上注册公钥。';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      '请检查服务器地址、端口和网络连接。';

  @override
  String get connectionLog => '连接日志';

  @override
  String get deviceList => '设备列表';

  @override
  String get view => '查看';

  @override
  String get dismissBanner => '关闭横幅';

  @override
  String get connectionClosed => '连接已关闭';

  @override
  String get theServerEndedTheSession => '服务器已结束会话';

  @override
  String get connectionEndedAfterAuthenticationFailed => '身份验证失败，连接已结束';

  @override
  String get connectionLost => '连接已中断';

  @override
  String ended(String arg0) {
    return '已结束 · $arg0';
  }

  @override
  String get copyOutput => '复制输出';

  @override
  String sshKey(String arg0) {
    return '$arg0的SSH密钥';
  }

  @override
  String get couldNotPrepareRegistration => '无法准备注册';

  @override
  String get keyToRegister => '要注册的密钥';

  @override
  String get newBiometricKey => '新建生物识别密钥';

  @override
  String get createNewSshKey => '创建新SSH密钥';

  @override
  String get registerSshKeyLogin => '注册SSH密钥登录';

  @override
  String keyRegistration(String arg0, String arg1) {
    return '$arg0的密钥注册$arg1';
  }

  @override
  String get anotherHost => '其他主机';

  @override
  String get isInProgress => '正在进行';

  @override
  String get isComplete => '已完成';

  @override
  String get registrationPreparationForThisHost => '准备向此主机注册密钥';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      '安装公钥后，通过单独的连接验证密钥登录。';

  @override
  String get newKeyName => '新密钥名称';

  @override
  String get progress => '进度';

  @override
  String get installPublicKey => '安装公钥';

  @override
  String get verifyKeyLogin => '验证密钥登录';

  @override
  String get applyToHost => '应用到主机';

  @override
  String get theServerRejectedTheKey => '服务器拒绝了密钥';

  @override
  String get theServerRequiresAdditionalAuthentication => '服务器需要额外身份验证';

  @override
  String get couldNotCompleteThisStep => '无法完成此步骤';

  @override
  String get installedOnServer => '已安装到服务器';

  @override
  String get keyAlreadyInstalled => '密钥已安装';

  @override
  String get keyLoginVerified => '密钥登录已验证';

  @override
  String get theServerRejectedThisKey => '服务器拒绝了此密钥';

  @override
  String get registrationComplete => '注册完成';

  @override
  String usingKey(String arg0) {
    return '正在使用密钥$arg0';
  }

  @override
  String get removeSavedPasswordForThisHost => '移除此主机已保存的密码';

  @override
  String get registerAndVerify => '注册并验证';

  @override
  String get continueInBackground => '在后台继续';

  @override
  String get previewColorThemeFontAndMargins => '预览配色主题、字体和边距';

  @override
  String get srcBuildSampleMd => '\nsrc  build  sample.md';

  @override
  String get specialKeyBarPreview => '特殊按键栏预览';

  @override
  String get fileTransferIsAvailableForSshHosts => 'SSH主机支持文件传输。';

  @override
  String get registerAKeyFromAConnectedSshSession => '请从已连接的SSH会话中注册密钥。';

  @override
  String get onlySshAndLocalConnectionsAreSupported => '仅支持SSH和本地连接。';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      '连接方式已更改。请从主页打开新会话。';

  @override
  String get calculatingTimeRemaining => '正在计算剩余时间';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return '剩余$arg0分$arg1秒';
  }

  @override
  String secondsRemaining(String arg0) {
    return '剩余$arg0秒';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · 正在取消…';
  }

  @override
  String get checkingSize => '正在检查大小';

  @override
  String get calculatingSpeed => '正在计算速度';

  @override
  String active(String arg0) {
    return '进行中$arg0';
  }

  @override
  String queued(String arg0) {
    return '等待中$arg0';
  }

  @override
  String failed(String arg0) {
    return '失败$arg0';
  }

  @override
  String completed(String arg0) {
    return '完成$arg0';
  }

  @override
  String cancelled(String arg0) {
    return '已取消$arg0';
  }

  @override
  String get noTransfers => '没有传输任务';

  @override
  String get queued2 => '等待中';

  @override
  String get paused => '已暂停';

  @override
  String get completed2 => '已完成';

  @override
  String get failed2 => '失败';

  @override
  String get cancelOperation => '取消操作';

  @override
  String get openFolder => '打开文件夹';

  @override
  String couldNotComplete(String arg0) {
    return '无法完成$arg0';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return '$arg0 / $arg1项$arg2';
  }

  @override
  String transfer(String arg0) {
    return '传输 · $arg0';
  }

  @override
  String get transferQueue => '传输队列';

  @override
  String get clearCompleted => '清除已完成项';

  @override
  String get collapseTransferQueue => '收起传输队列';

  @override
  String get expandTransferQueue => '展开传输队列';

  @override
  String get all => '全部';

  @override
  String get selectARegularFile => '请选择普通文件。';

  @override
  String get aFileWithTheSameNameAlreadyExists => '已存在同名文件。';

  @override
  String get theSourceFileSizeChangedDuringTransfer => '源文件大小在传输过程中发生了变化。';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer => '传输过程中出现了同名文件。';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return '无法删除上传临时文件。请在服务器上检查。$arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return '无法检查上传临时文件。请在服务器上检查。$arg0';
  }

  @override
  String get changePermissions => '更改权限';

  @override
  String get read => '读取';

  @override
  String get write => '写入';

  @override
  String get execute => '执行';

  @override
  String get owner => '所有者';

  @override
  String get group => '用户组';

  @override
  String get other => '其他用户';

  @override
  String get octalPermissions => '八进制权限';

  @override
  String get enterThreeOrFourDigitsFrom0To7 => '请输入由0到7组成的3位或4位数字。';

  @override
  String get changePermissions2 => '更改权限';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return '无法打开文件夹。请检查路径和访问权限。\n$arg0';
  }

  @override
  String get newFolder => '新建文件夹';

  @override
  String get create => '创建';

  @override
  String get destinationFolder => '目标文件夹';

  @override
  String move(String arg0) {
    return '移动$arg0';
  }

  @override
  String moveItems(String arg0) {
    return '移动$arg0项';
  }

  @override
  String get parentFolder => '上级文件夹';

  @override
  String get folderPath => '文件夹路径';

  @override
  String get editPath => '编辑路径';

  @override
  String get moveHere => '移动到此处';

  @override
  String permanentlyDeleteItems(String arg0) {
    return '要永久删除$arg0项吗？';
  }

  @override
  String childItems(String arg0) {
    return '包含$arg0个子项';
  }

  @override
  String get checkingContents => '正在检查内容…';

  @override
  String get couldNotInspectFolderContentsTryAgain => '无法检查文件夹内容。请重试。';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return '将删除包括文件夹内容在内的全部$arg0项。此操作无法撤销。';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      '直接删除，不放入回收站。此操作无法撤销。';

  @override
  String get deletePermanently => '永久删除';

  @override
  String get unknownModificationDate => '修改时间未知';

  @override
  String get aFileWithTheSameNameExists => '存在同名文件';

  @override
  String transferringItems(String arg0, String arg1) {
    return '正在传输$arg0 / $arg1项';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict => '请为每个冲突选择要保留的文件。';

  @override
  String get fileBeingUploaded => '正在上传的文件';

  @override
  String get fileBeingDownloaded => '正在下载的文件';

  @override
  String get existingFileOnServer => '服务器上的现有文件';

  @override
  String get existingFileOnDevice => '设备上的现有文件';

  @override
  String get unknownSize => '大小未知';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile => '保留现有文件并跳过复制此文件。';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      '同时保留两个文件。在复制文件的扩展名前，从(1)开始添加首个未使用的编号。';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      '用复制的文件覆盖现有文件。此操作无法撤销。';

  @override
  String get cancelCopyingKeepTheExistingFile => '取消整个复制任务，包括剩余文件。保留现有文件。';

  @override
  String applyToRemainingItems(String arg0) {
    return '同时应用于剩余$arg0项';
  }

  @override
  String get cancelTransfer => '取消传输';

  @override
  String get cancelCopy => '取消复制';

  @override
  String get loggingInForFileTransfer => '正在登录以传输文件';

  @override
  String get couldNotLogInForFileTransfer => '无法登录以传输文件。';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      '仅支持预览不超过4 MiB的文件。请下载后打开。';

  @override
  String get saveFile => '保存文件';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      '编辑器无法覆盖文件夹或符号链接。';

  @override
  String get serverFileChanged => '服务器文件已更改';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\n服务器文件在开始编辑后已更改。要覆盖吗？';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\n要覆盖现有文件吗？';
  }

  @override
  String get overwrite => '覆盖';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      '无法重新连接到服务器。请在文件浏览器中检查身份验证。';

  @override
  String get saveACopyElsewhere => '将副本保存到其他位置';

  @override
  String get saveCopy => '保存副本';

  @override
  String get enterAnAbsolutePathIncludingTheFileName => '请输入包含文件名的绝对路径。';

  @override
  String get enterAPathDifferentFromTheOriginal => '请输入与原文件不同的路径。';

  @override
  String get newFile => '新建文件';

  @override
  String get anItemWithTheSameNameAlreadyExists => '已存在同名项。';

  @override
  String get thisItemIsBeingTransferred => '此项正在传输中。';

  @override
  String get rename => '重命名';

  @override
  String get change => '更改';

  @override
  String get creatingFolder => '正在创建文件夹';

  @override
  String get folderCreated => '文件夹已创建。';

  @override
  String get deleting => '正在删除';

  @override
  String deletingItems(String arg0) {
    return '正在删除$arg0项';
  }

  @override
  String deletedItems(String arg0) {
    return '已删除$arg0项。';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · 已删除$arg0项。';
  }

  @override
  String get changingPermissions => '正在更改权限';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged => '不会更改符号链接的权限。';

  @override
  String get permissionsChanged => '权限已更改。';

  @override
  String operationCancelled(String arg0) {
    return '操作已取消。$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return '无法完成操作。$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return '已$arg1$arg0项 · 请在目标文件夹中粘贴。';
  }

  @override
  String get cut => '剪切';

  @override
  String get noFilesToPaste => '没有可粘贴的文件。';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr => '不能移动或复制到相同位置或源文件夹内部。';

  @override
  String get move2 => '移动';

  @override
  String get copyTemporaryDownloadAndUpload => '复制（临时下载后上传）';

  @override
  String get upload => '上传';

  @override
  String get download => '下载';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      '此平台不支持选择目标文件夹。';

  @override
  String get connectionClosed2 => '连接已关闭。';

  @override
  String get downloadToFileManager => '下载到文件管理器';

  @override
  String get theTemporaryExportPathAlreadyExists => '临时导出路径已存在。';

  @override
  String get cancelTransfersAndClose => '取消传输并关闭';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      '要取消此标签页中正在进行的传输和等待中的操作吗？';

  @override
  String get uploadFolder => '上传文件夹';

  @override
  String get connectionCancelled => '连接已取消';

  @override
  String get couldNotOpenFileList => '无法打开文件列表';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · 文件传输';
  }

  @override
  String get fileList => '文件列表';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      '请检查文件夹路径和访问权限，然后重试。';

  @override
  String get bookmarkCurrentFolder => '收藏当前文件夹';

  @override
  String get recentLocations => '最近的位置';

  @override
  String selected(String arg0) {
    return '已选择$arg0项';
  }

  @override
  String get forward => '前进';

  @override
  String get remoteFolderPath => '远程文件夹路径';

  @override
  String get bookmarksAndRecentLocations => '收藏和最近的位置';

  @override
  String get refresh => '刷新';

  @override
  String get findInCurrentFolder => '在当前文件夹中查找';

  @override
  String get readOnly => '只读';

  @override
  String get discardChanges2 => '放弃更改';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\n要放弃未保存的更改吗？';
  }

  @override
  String get doNotSave => '不保存';

  @override
  String get editing => '正在编辑';

  @override
  String get saveCopyKeepOriginalUnchanged => '保存副本 · 不更改原文件';

  @override
  String savedACopyTo(String arg0) {
    return '已将副本保存到$arg0。';
  }

  @override
  String get saved2 => '已保存。';

  @override
  String get couldNotOpenFile => '无法打开文件';

  @override
  String couldNotOpen(String arg0) {
    return '无法打开$arg0';
  }

  @override
  String get previewIsUnsupportedForThisFileType => '不支持预览此文件类型。';

  @override
  String get couldNotSaveYourChangesHaveBeenKept => '无法保存。您的更改已保留。';

  @override
  String couldNotSave2(String arg0) {
    return '无法保存$arg0';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · $arg1行 · $arg2 B';
  }

  @override
  String get unsupportedFileType => '不支持此文件类型。';

  @override
  String get unsupportedRemoteFileType => '不支持此远程文件类型。';

  @override
  String get theTransferSourceChangedStartANewTransfer => '传输源已更改。请新建传输任务。';

  @override
  String get anItemWithThisNameExistsAndIsNot => '已存在同名项，且该项不是文件夹。';

  @override
  String get cannotOverwriteAFolderWithAFile => '不能用文件覆盖文件夹。';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      '名称不能包含路径分隔符，也不能为“.”或“..”。';

  @override
  String get aFileOrFolderWithTheSameNameAlready => '已存在同名文件或文件夹。';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      '不能将文件夹移动到自身或其子文件夹中。';

  @override
  String get cannotDeleteTheRootFolder => '无法删除根文件夹。';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      '服务器拒绝访问。请检查目标路径的权限。';

  @override
  String get theFileOrFolderNoLongerExists => '文件或文件夹已不存在。';

  @override
  String get serverConnectionLost => '服务器连接已中断。';

  @override
  String get theServerCouldNotCompleteTheOperation => '服务器无法完成操作。';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd => '服务器无响应。请检查地址和网络。';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      '服务器未能验证您的身份。请检查用户名、密钥和密码。';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return '服务器拒绝了连接$arg0。请检查SSH运行状态和端口设置。';
  }

  @override
  String onPort(String arg0) {
    return '（端口$arg0）';
  }

  @override
  String get checkTheServerConnection => '无法与服务器通信。请检查网络连接。';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      '发生意外错误。请复制下方详情并联系支持。';

  @override
  String get transferCancelled => '传输已取消。';

  @override
  String get invalidFileName => '文件名无效。';

  @override
  String get theFileWasNotReceivedCompletely => '文件未完整接收。';

  @override
  String get size => '大小';

  @override
  String get modified => '修改时间';

  @override
  String get permissions => '权限';

  @override
  String get ownerUid => '所有者UID';

  @override
  String get groupGid => '用户组GID';

  @override
  String get showHiddenFilesAndFolders => '显示隐藏文件和文件夹';

  @override
  String get descending => '降序';

  @override
  String get visibleColumns => '显示的列';

  @override
  String get preview => '预览';

  @override
  String get move3 => '移动…';

  @override
  String get copyPath => '复制路径';

  @override
  String get info => '信息';

  @override
  String get changePermissions3 => '更改权限…';

  @override
  String get fileInformation => '文件信息';

  @override
  String get path => '路径';

  @override
  String get type2 => '类型';

  @override
  String get folder => '文件夹';

  @override
  String get symbolicLink => '符号链接';

  @override
  String get file => '文件';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get location => '位置';

  @override
  String selected2(String arg0, String arg1) {
    return '已选择$arg0项 · $arg1';
  }

  @override
  String get parentFolderBackspace => '上级文件夹（Backspace）';

  @override
  String get loading => '正在加载…';

  @override
  String get noFilesToDisplay => '没有可显示的文件。';

  @override
  String get noMatchingFiles => '没有匹配的文件。';

  @override
  String get applyNewName => '应用新名称';

  @override
  String actions(String arg0) {
    return '$arg0操作';
  }

  @override
  String items3(String arg0, String arg1) {
    return '$arg0项$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · $arg0项隐藏/已过滤';
  }

  @override
  String copy3(String arg0) {
    return '$arg0的副本';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return '$arg0台主机将改用应用默认配置。';
  }

  @override
  String get deleteThisProfile => '将删除此配置。';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return '$arg0台主机的连接设置将保留，但共用密码会被删除。';
  }

  @override
  String delete2(String arg0) {
    return '删除$arg0';
  }

  @override
  String get setAsDefault => '设为默认';

  @override
  String add2(String arg0) {
    return '添加$arg0';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      '在多个主机间共用用户名、密钥和密码。';

  @override
  String get default2 => ' · 默认';

  @override
  String get noHostsUsingThis => '没有主机在使用';

  @override
  String hosts(num count) {
    return '$count台主机';
  }

  @override
  String get privateKeyPassphrase => '私钥口令';

  @override
  String get leaveBlankIfThereIsNoPassphrase => '如果没有口令，请留空。';

  @override
  String get deleteKey2 => '删除密钥';

  @override
  String deleteKey3(String arg0) {
    return '要删除密钥$arg0吗？';
  }

  @override
  String get savePublicKeyFile => '保存公钥文件';

  @override
  String get addKeyFile => '添加密钥文件';

  @override
  String get newKey => '新建密钥';

  @override
  String get couldNotCompleteKeyOperation => '无法完成密钥操作';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      '导入的私钥从应用的受保护存储中使用。保存的口令由iOS Keychain保护。';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      '私钥文件从原位置使用。保存的口令由Windows账户保护。';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      '私钥在Android Keystore中创建，无法导出。旧版私钥将以停用状态保留。';

  @override
  String get disabled => '已停用';

  @override
  String options(String arg0) {
    return '$arg0选项';
  }

  @override
  String get deleteForwarding => '删除转发设置';

  @override
  String deleteSettingsFor(String arg0) {
    return '要删除$arg0的设置吗？';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · 端口转发';
  }

  @override
  String get addForwarding => '添加转发设置';

  @override
  String get sessionToControl => '要控制的会话';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · 开关更改立即生效';
  }

  @override
  String get defaultOnConnection => '连接时的默认值';

  @override
  String get couldNotLoadForwarding => '无法加载转发设置';

  @override
  String get socks4UnsupportedChangeToSocks5 => '不支持SOCKS4 · 请改为SOCKS5';

  @override
  String get removeServerKeyTrust => '移除对服务器密钥的信任';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\n下次连接时将重新验证服务器密钥。';
  }

  @override
  String get noTrustedServerKeys => '没有已信任的服务器密钥。';

  @override
  String get use => '使用';

  @override
  String get editPalette => '编辑调色板';

  @override
  String get export => '导出';

  @override
  String get defaultTheme => '默认主题';

  @override
  String get customTheme => '自定义主题';

  @override
  String get nameForDuplicateTheme => '主题副本名称';

  @override
  String get themeName => '主题名称';

  @override
  String get deleteTheme => '删除主题';

  @override
  String deleteTheme2(String arg0) {
    return '要删除主题$arg0吗？';
  }

  @override
  String get newThemeName => '新主题名称';

  @override
  String get newTheme => '新建主题';

  @override
  String get import => '导入';

  @override
  String get textColor => '文字颜色';

  @override
  String get backgroundColor => '背景颜色';

  @override
  String get cursorAndAppAccent => '光标和应用强调色';

  @override
  String get couldNotLoadColorTheme => '无法加载配色主题';

  @override
  String get makeACopyToEditTheColors => '请先创建副本，再编辑颜色。';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  sample.md\n';

  @override
  String get defaultColors => '默认颜色';

  @override
  String get lowContrastAgainstBackground => '与背景的对比度较低';

  @override
  String get ansiPalette => 'ANSI调色板';

  @override
  String ansiColor(String arg0) {
    return 'ANSI颜色$arg0';
  }

  @override
  String get findServer => '查找服务器';

  @override
  String get verifyServerKey => '验证服务器密钥';

  @override
  String seconds(String arg0) {
    return '$arg0秒';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain => '无法打开广告隐私设置。请重试。';

  @override
  String get ad => '广告';

  @override
  String get adPrivacySettings => '广告隐私设置';

  @override
  String get googleFontsMonospace => 'Google Fonts · 等宽字体';

  @override
  String get searchSettings => '搜索设置';

  @override
  String get keyboard => '键盘';

  @override
  String get gestures => '手势';

  @override
  String get connectionsAndNotifications => '连接与通知';

  @override
  String get securityAndBackup => '安全与备份';

  @override
  String get manageFonts => '管理字体';

  @override
  String get specialKeyBar => '特殊按键栏';

  @override
  String specialKeys(String arg0) {
    return '$arg0个特殊按键';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return '双指横向滑动 · $arg0';
  }

  @override
  String get tmuxWindows => 'tmux窗口';

  @override
  String get disabled2 => '已禁用';

  @override
  String get defaultTerminal => '默认终端';

  @override
  String get notificationsAndBell => '通知与响铃';

  @override
  String sshKeys2(num count) {
    return '$count个SSH密钥';
  }

  @override
  String get helpAndLogs2 => '帮助与日志';

  @override
  String get horizontalMargins => '左右边距';

  @override
  String get lines => '行';

  @override
  String get appTheme => '应用主题';

  @override
  String get systemTheme => '系统主题';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get font => '字体';

  @override
  String get orientation => '屏幕方向';

  @override
  String get alwaysRotate => '始终旋转';

  @override
  String get portrait => '竖屏';

  @override
  String get landscape => '横屏';

  @override
  String get hideStatusBar => '隐藏状态栏';

  @override
  String get specialKeyLayout => '特殊按键布局';

  @override
  String get showWhenKeyboardIsClosed => '键盘关闭时仍显示';

  @override
  String get whenPressingCtrlOrAlt => '按下Ctrl或Alt时';

  @override
  String get once => '一次';

  @override
  String get sticky => '锁定';

  @override
  String get stickyAltOnly => '仅锁定Alt';

  @override
  String get keyboardToggleButton => '键盘切换按钮';

  @override
  String get twoFingerHorizontalSwipe2 => '双指横向滑动';

  @override
  String get doNothing => '不执行操作';

  @override
  String get switchSessions => '切换会话';

  @override
  String get switchTmuxWindows => '切换tmux窗口';

  @override
  String get prefixKey => '前缀键';

  @override
  String get twoFingerVerticalSwipe => '双指纵向滑动';

  @override
  String get scroll => '滚动';

  @override
  String get volumeButtonsChangeFontSize => '用音量键调整字号';

  @override
  String get specialKeyVibration => '特殊按键振动';

  @override
  String get defaultTerminalProfile => '默认终端配置';

  @override
  String get manageTerminalProfiles => '管理终端配置';

  @override
  String itemCount(String arg0) {
    return '$arg0';
  }

  @override
  String get appearance => '外观';

  @override
  String get terminalTypeTerm => '终端类型（TERM）';

  @override
  String get addTerminalType => '添加终端类型';

  @override
  String get terminalType => '终端类型';

  @override
  String get keepScreenAwakeWhileConnected => '连接时保持屏幕常亮';

  @override
  String get theTerminalScreenWillStayAwake => '终端屏幕不会自动关闭';

  @override
  String get preventWiFiSleep => '防止Wi-Fi休眠';

  @override
  String get usesMoreBattery => '耗电量会增加';

  @override
  String get backgroundConnectionNotification => '后台连接通知';

  @override
  String get pinnedWhileConnected => '连接时固定显示';

  @override
  String get terminalBell => '终端响铃';

  @override
  String get whenTheBellRings => '终端响铃时';

  @override
  String get ignore => '忽略';

  @override
  String get sound => '声音';

  @override
  String get vibration => '振动';

  @override
  String get soundAndVibration => '声音和振动';

  @override
  String get volume => '音量';

  @override
  String get notifications => '通知';

  @override
  String get notificationPermissionRequired => '需要通知权限';

  @override
  String get allow => '允许';

  @override
  String get enableConnectionNotifications => '启用连接通知';

  @override
  String get allowBellAndDisconnectionNotifications => '允许响铃和连接断开通知';

  @override
  String get bellInBackground => '后台响铃通知';

  @override
  String get onDisconnect => '断开连接时';

  @override
  String get androidNotificationSettings => 'Android通知设置';

  @override
  String get notificationsOff => '通知已关闭';

  @override
  String get notificationsAllowed => '已允许通知';

  @override
  String get lock => '锁定';

  @override
  String get unlockWhenStartingTheApp => '启动应用时要求解锁';

  @override
  String get setUpAScreenLockFirst => '请先设置屏幕锁定';

  @override
  String get fingerprintOrScreenLock => '指纹或屏幕锁定';

  @override
  String get keysAndServers => '密钥与服务器';

  @override
  String get configurationFile => '配置文件';

  @override
  String get exportHosts => '导出主机';

  @override
  String get importHosts => '导入主机';

  @override
  String get selectDefaultFont => '选择默认字体';

  @override
  String fontSample(String arg0) {
    return '$arg0 Aa 中文';
  }

  @override
  String get bundledWithApp => '应用内置';

  @override
  String get monospaceFont => '等宽字体';

  @override
  String get deleteFont => '删除字体';

  @override
  String get deleteThisFontFile => '要删除此字体文件吗？';

  @override
  String get removeFont => '移除字体';

  @override
  String get preparingFont => '正在准备字体';

  @override
  String get importFontFile => '导入字体文件';

  @override
  String get findOnGoogleFonts => '在Google Fonts中查找';

  @override
  String get onlyMonospaceFontsAreShown => '仅显示等宽字体';

  @override
  String settings2(String arg0) {
    return '设置 › $arg0';
  }

  @override
  String get couldNotSaveSettings => '无法保存设置';

  @override
  String get resetSpecialKeyBar => '要重置特殊按键栏吗？';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      '恢复默认高度、按键顺序和显示状态。';

  @override
  String get longPressToDragTapToHide => '长按拖动 · 轻点隐藏';

  @override
  String get hiddenKeys => '已隐藏的按键';

  @override
  String get tapAKeyToMoveItHere => '轻点按键可将其移到此处';

  @override
  String get combineF1F12IntoFn => '将F1–F12合并为Fn';

  @override
  String get height => '高度';

  @override
  String get small => '小';

  @override
  String get large => '大';

  @override
  String get default3 => '默认';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc和Ctrl固定在左侧，键盘、Fn和Tab固定在右侧。';

  @override
  String get flutterLibraryLicenses => 'Flutter库许可证';

  @override
  String get tips => '使用技巧';

  @override
  String get licensesAndTerms => '许可证与使用条款';

  @override
  String get projectAndContact => '项目与联系';

  @override
  String get diagnostics => '诊断';

  @override
  String get diagnosticLogs => '诊断日志';

  @override
  String get searchLogs => '搜索日志';

  @override
  String get saveNativeCrashLog => '保存原生崩溃日志';

  @override
  String get warning => '警告';

  @override
  String get couldNotLoadLogs => '无法加载日志';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      '仅支持Android Keystore SSH密钥';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      '仅支持Android Keystore P-256密钥';

  @override
  String get invalidEcdsaSignature => 'ECDSA签名无效';

  @override
  String get invalidEcdsaSignatureValues => 'ECDSA签名值无效';

  @override
  String get invalidX509PublicKey => 'X509公钥无效';

  @override
  String get invalidPublicKeyBitString => '公钥位字符串无效';

  @override
  String get invalidRsaPublicKey => 'RSA公钥无效';

  @override
  String get invalidEcCurve => 'EC曲线无效';

  @override
  String get invalidUncompressedEcPoint => '未压缩EC点无效';

  @override
  String get invalidEd25519PublicKey => 'Ed25519公钥无效';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return '不支持的SSH公钥算法：$arg0';
  }

  @override
  String get unsupportedSshEcCurve => '不支持此SSH EC曲线';

  @override
  String get invalidDerSequence => 'DER序列无效';

  @override
  String get privateKeyExportIsNotSupported => '不支持导出私钥';

  @override
  String get publicKeyIsUnavailable => '公钥不可用';

  @override
  String unsupportedTerminalKey(String arg0) {
    return '不支持的终端按键：$arg0';
  }

  @override
  String get disconnectBeforeReconnecting => '请先断开连接，再重新连接';

  @override
  String get localShellIsNotOpen => '本地Shell尚未打开';

  @override
  String get unknownModifier => '未知修饰键';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return '不支持的本地终端操作：$arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'SSH公钥行格式无效';

  @override
  String get serverDidNotConfirmPublicKeyRegistration => '服务器未确认公钥注册。';

  @override
  String get logInToASavedSshHostBeforeRegistering => '请先登录已保存的SSH主机，再注册密钥。';

  @override
  String get theSelectedSshKeyNoLongerExists => '所选SSH密钥已不存在。';

  @override
  String get aUniqueBiometricKeyNameIsRequired => '请输入不与其他密钥重复的生物识别密钥名称。';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      '原SSH连接的身份验证已失效。';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      '未能仅用密钥完成登录。服务器可能需要额外身份验证。登录设置未更改。';

  @override
  String get theSavedHostNoLongerExists => '已保存的主机已不存在。';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      '注册过程中主机地址已更改。登录设置未更改。';

  @override
  String get invalidPtyDimensions => 'PTY大小无效';

  @override
  String get sshTargetIsRequired => '请指定SSH连接目标';

  @override
  String get sshSessionWasClosed => 'SSH会话已关闭';

  @override
  String get sshSessionIsNotConnected => 'SSH会话未连接';

  @override
  String get sshSessionsCannotBeReused => 'SSH会话无法重复使用';

  @override
  String get noAddressForRequestedIpVersion => '没有所请求IP版本的地址';

  @override
  String get sshHopConnectionTimedOut => '通过跳板主机的SSH连接超时';

  @override
  String get sshSessionHasNoShell => 'SSH会话没有Shell';

  @override
  String get sshSessionRequestTimedOut => 'SSH会话请求超时';

  @override
  String get invalidForwardBindPort => '转发监听端口无效';

  @override
  String get invalidForwardDestination => '转发目标无效';

  @override
  String get remoteForwardingRequestTimedOut => '远程转发请求超时';

  @override
  String get remoteForwardingWasRefused => '远程转发被拒绝';

  @override
  String get forwardConnectionTimedOut => '转发连接超时';

  @override
  String get remoteForwardDestinationTimedOut => '远程转发目标连接超时';

  @override
  String get remoteForwardingCancellationWasRefused => '取消远程转发被拒绝';

  @override
  String get sshAuthenticationCancelled => 'SSH身份验证已取消';

  @override
  String get concurrentSshAuthenticationPrompt => '已有SSH身份验证请求正在进行';

  @override
  String get sessionDisposed => '会话已结束';

  @override
  String get disconnectBeforeRefreshingSshConfiguration => '请先断开连接，再刷新SSH配置';

  @override
  String get couldNotUnlockTheSelectedKey => '无法解锁所选密钥。';

  @override
  String get logInToThisServerBeforeRegisteringAKey => '请先登录此服务器，再注册密钥。';

  @override
  String get sshShellIsNotOpen => 'SSH Shell尚未打开';

  @override
  String get sshIsNotConnected => 'SSH未连接';

  @override
  String get portForwardIsMissing => '缺少端口转发设置';

  @override
  String get unsupportedSshForwardType => '不支持此SSH转发类型';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return '不支持的应用SSH操作：$arg0';
  }

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get timedOutReadingWindowsSshSettings => '读取Windows SSH设置超时。';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return '无法读取Windows SSH设置。$arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable => 'Windows用户配置目录路径不可用。';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return '不支持的SSH密钥路径变量：$arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return '无法导入文件：$arg0';
  }

  @override
  String uploadTo(String arg0) {
    return '上传到$arg0';
  }

  @override
  String get currentFolder => '当前文件夹';

  @override
  String get windowsUserDataFolderIsUnavailable => 'Windows用户数据文件夹不可用。';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return '无法使用Windows账户保护凭据。$arg0';
  }

  @override
  String get altDrag => '按住Alt拖动';

  @override
  String get keyUp => '向上';

  @override
  String get keyDown => '向下';

  @override
  String get keyHome => '到行首';

  @override
  String get keyEnd => '到行尾';

  @override
  String get keyPageUp => '上一页';

  @override
  String get keyPageDown => '下一页';

  @override
  String get keyInsert => '插入';

  @override
  String get keyDelete => '删除';

  @override
  String get skipCopy => '跳过';

  @override
  String get keepBothFiles => '保留两者';

  @override
  String get cancelJobNoApplyAll => '取消复制任务时，无法将此操作应用于剩余文件。';

  @override
  String get editAuthentication => '编辑身份验证';

  @override
  String get serverMessage => '服务器消息';

  @override
  String get cancellingOperation => '正在取消…';

  @override
  String get transferHeading => '传输';

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

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');
}
