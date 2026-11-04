// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get home => '홈';

  @override
  String get terminal => '터미널';

  @override
  String files(String arg0) {
    return '$arg0 · 파일';
  }

  @override
  String get newHost => '새 호스트';

  @override
  String edit(String arg0) {
    return '$arg0 편집';
  }

  @override
  String get disconnectAndCloseTab => '연결 끊고 탭 닫기';

  @override
  String disconnectFromAndCloseThisTab(String arg0) {
    return '$arg0의 SSH 연결을 종료하고 탭을 닫을까요?';
  }

  @override
  String get disconnectAndClose => '연결 끊고 닫기';

  @override
  String get newTerminal => '새 터미널';

  @override
  String get fileTransfer => '파일 전송';

  @override
  String get edit2 => '편집';

  @override
  String get removeFromFavorites => '즐겨찾기에서 제거';

  @override
  String get addToFavorites => '즐겨찾기에 추가';

  @override
  String get duplicate => '복제';

  @override
  String get portForwarding => '포트 포워딩';

  @override
  String get disconnect => '연결 끊기';

  @override
  String get delete => '삭제';

  @override
  String get nameForDuplicateHost => '복제할 호스트 이름';

  @override
  String copy(String arg0) {
    return '$arg0 복사';
  }

  @override
  String disconnectAllSessionsFor(String arg0) {
    return '$arg0의 연결을 모두 종료할까요?';
  }

  @override
  String get searchHosts => '호스트 검색';

  @override
  String get searchHostsOrEnterSshAddressCtrlK =>
      '호스트 검색 또는 SSH 주소 입력 (Ctrl K)';

  @override
  String get addHost => '호스트 추가';

  @override
  String get noHostsYet => '아직 호스트가 없습니다';

  @override
  String get openTerminals => '열린 터미널';

  @override
  String get openFiles => '열린 파일';

  @override
  String menu(String arg0) {
    return '$arg0 메뉴';
  }

  @override
  String get settings => '설정';

  @override
  String get helpAndLogs => '도움말·로그';

  @override
  String get hostListCtrlB => '호스트 목록 (Ctrl B)';

  @override
  String closeTab(String arg0) {
    return '$arg0 탭 닫기';
  }

  @override
  String get newTabCtrlShiftT => '새 탭 (Ctrl Shift T)';

  @override
  String get terminalMenu => '터미널 메뉴';

  @override
  String get importSshKey => 'SSH 키 가져오기';

  @override
  String get openSessions => '열린 세션';

  @override
  String session(String arg0) {
    return '세션 $arg0';
  }

  @override
  String get connected => '연결됨';

  @override
  String get connecting => '연결 중';

  @override
  String get disconnected => '연결 종료';

  @override
  String get open => '열기';

  @override
  String get connect => '연결';

  @override
  String get address => '주소';

  @override
  String get authentication => '인증';

  @override
  String get tryAllAvailableKeys => '사용 가능한 키 모두 시도';

  @override
  String get useServerSettings => '서버 설정에 따름';

  @override
  String get terminalProfile => '터미널 프로필';

  @override
  String get appDefaultProfile => '앱 기본 프로필';

  @override
  String get manage => '관리';

  @override
  String get minimize => '최소화';

  @override
  String get restore => '이전 크기로';

  @override
  String get maximize => '최대화';

  @override
  String get closeWindow => '창 닫기';

  @override
  String get host => '호스트';

  @override
  String get profile => '프로필';

  @override
  String get sharedLoginAccount => '공용 로그인 계정';

  @override
  String get sshKeys => 'SSH 키';

  @override
  String enter(String arg0) {
    return '$arg0 항목을 입력하세요.';
  }

  @override
  String get enterAWholeNumber => '정수를 입력하세요.';

  @override
  String get checkThePortRange => '포트 범위를 확인하세요.';

  @override
  String currentValue(String arg0) {
    return '$arg0 (현재 값)';
  }

  @override
  String get select => '선택';

  @override
  String get defaultValue => '기본값';

  @override
  String get dsaUnsupported => ' (DSA 미지원)';

  @override
  String get windowsDefaultKeysAndAddedKeys => 'Windows 기본 키와 등록한 키';

  @override
  String get noKey => '키 쓰지 않음';

  @override
  String get passwordSaved => '비밀번호 (저장됨)';

  @override
  String get password => '비밀번호';

  @override
  String get storedEncryptedOnThisDeviceEnterItAgainAfter =>
      '이 기기에 암호화해 보관합니다. 다른 기기로 복원하면 다시 입력해야 합니다.';

  @override
  String get storedEncryptedOnThisDevice => '이 기기에 암호화해 보관합니다.';

  @override
  String get deleteSavedPassword => '저장된 비밀번호 삭제';

  @override
  String get accountName => '계정 이름';

  @override
  String get username => '사용자 이름';

  @override
  String appliesToHosts(String arg0) {
    return '$arg0개 호스트에 적용됩니다';
  }

  @override
  String get display => '화면';

  @override
  String get profileName => '프로필 이름';

  @override
  String get colorTheme => '색상 테마';

  @override
  String get terminalFont => '터미널 폰트';

  @override
  String get appDefault => '앱 기본값';

  @override
  String get fontSize => '글자 크기';

  @override
  String get characterEncoding => '문자 인코딩';

  @override
  String get deleteKey => '삭제 키';

  @override
  String get columnsAutomatic => '열 수 · 자동';

  @override
  String get rowsAutomatic => '행 수 · 자동';

  @override
  String get forwarding => '포워딩';

  @override
  String get forwardingName => '포워딩 이름';

  @override
  String get type => '방식';

  @override
  String get local => '로컬';

  @override
  String get remote => '원격';

  @override
  String get forwardConnectionsFromAServerPortToAnAddress =>
      '서버의 포트로 들어온 연결을 이 기기의 주소로 보냅니다.';

  @override
  String get forwardConnectionsFromADevicePortToAnAddress =>
      '이 기기의 포트로 들어온 연결을 서버 쪽 주소로 보냅니다.';

  @override
  String get openASocks5ProxyOnThisDevice => '이 기기에 SOCKS5 프록시를 엽니다.';

  @override
  String get socks4IsUnsupportedChangeTheTypeToSocks5To =>
      'SOCKS4는 실행할 수 없습니다. 방식을 SOCKS5로 변경하면 사용할 수 있습니다.';

  @override
  String get listenAddressOnServer => '서버에서 받을 주소';

  @override
  String get listenAddressOnThisDevice => '이 기기에서 받을 주소';

  @override
  String get text127001AccessibleOnlyOnThisDevice => '127.0.0.1 · 이 기기에서만 접근';

  @override
  String get port => '포트';

  @override
  String get destinationAddress => '대상 주소';

  @override
  String get publicKey => '공개키';

  @override
  String get copyFingerprint => '지문 복사';

  @override
  String get copyPublicKey => '공개키 복사';

  @override
  String get keySettings => '키 설정';

  @override
  String get keyName => '키 이름';

  @override
  String get confirmBeforeUse => '사용할 때 확인';

  @override
  String get askForPermissionBeforeAuthenticatingWithThisKey =>
      '이 키로 인증하기 전에 허용 여부를 묻습니다';

  @override
  String get importedPrivateKey => '가져온 개인키';

  @override
  String get androidKeystoreP256Key => 'Android Keystore P-256 키';

  @override
  String get authenticateWithAnImportedPrivateKeyFile => '가져온 개인키 파일로 인증합니다';

  @override
  String get thePrivateKeyCannotBeExportedFromThisDevice =>
      '비밀키는 기기 밖으로 내보낼 수 없습니다';

  @override
  String get disabledLegacyPrivateKey => '사용 중지된 기존 개인키';

  @override
  String get replaceItWithANewAndroidKeystoreKeyBefore =>
      '새 Android Keystore 키로 교체한 뒤 삭제하세요.';

  @override
  String get connectionType => '연결 방식';

  @override
  String connectionsAreUnsupportedChangeToSshOrLocal(String arg0) {
    return '$arg0 연결은 지원하지 않습니다. SSH 또는 로컬로 변경하세요.';
  }

  @override
  String get hostName => '호스트 이름';

  @override
  String get name => '이름';

  @override
  String get serverAddress => '서버 주소';

  @override
  String get pasteUserHostPortIntoTheAddressFieldTo =>
      'user@host:port를 주소 칸에 붙여 넣으면 나눠서 채웁니다.';

  @override
  String get advanced => '고급';

  @override
  String get ipAddress => 'IP 주소';

  @override
  String get automatic => '자동';

  @override
  String get jumpHost => '점프 호스트';

  @override
  String get directConnection => '직접 연결';

  @override
  String get thisConnectionTypeDoesNotUseSshAuthenticationSettings =>
      '이 연결 방식은 SSH 인증 설정을 사용하지 않습니다.';

  @override
  String get account => '계정';

  @override
  String get doNotUse => '쓰지 않음';

  @override
  String usingAccount(String arg0) {
    return '$arg0 계정을 씁니다';
  }

  @override
  String get loginKey => '로그인 키';

  @override
  String get registerKeyOnThisServer => '이 서버에 키 등록';

  @override
  String get logInOnceWithAPasswordToInstallThe => '비밀번호로 한 번 로그인해 공개키를 올립니다';

  @override
  String get hostColor => '호스트 색';

  @override
  String get previewInTheHomeListTabsAndNotifications => '홈 목록·탭·알림에서 이렇게 보입니다';

  @override
  String get customHostColor => '호스트 색 직접 지정';

  @override
  String appDefault2(String arg0) {
    return '앱 기본 · $arg0';
  }

  @override
  String get manageProfiles => '프로필 관리';

  @override
  String get keepConnectionAlive => '연결 유지';

  @override
  String get reconnectAutomaticallyAfterAnIOError =>
      '입출력 오류로 연결이 끊기면 자동으로 다시 연결합니다';

  @override
  String get closeWithoutAsking => '닫을 때 묻지 않기';

  @override
  String get closeTheTabImmediatelyAfterExit => 'exit 후 바로 탭을 닫습니다';

  @override
  String get sshCompression => 'SSH 압축';

  @override
  String get enableOnlyOnSlowConnections => '느린 회선에서만 켜세요';

  @override
  String get openTerminal => '터미널 열기';

  @override
  String get whenOffOnlyPortForwardingIsEnabled => '끄면 포트 포워딩만 합니다';

  @override
  String get overrideForThisHost => '이 호스트만 다르게';

  @override
  String get scrollback => '스크롤 기록';

  @override
  String linesDefault(String arg0) {
    return '행 · 기본값 $arg0';
  }

  @override
  String get useCtrlAltAsMeta => 'Ctrl+Alt를 Meta로';

  @override
  String get displayAndProfile => '화면·프로필';

  @override
  String get session2 => '세션';

  @override
  String get editHost => '호스트 편집';

  @override
  String get localShell => '로컬 셸';

  @override
  String get selectKey => '키 선택';

  @override
  String get connectionSettings => '연결 설정';

  @override
  String get trustedServerKeys => '신뢰한 서버 키';

  @override
  String get nameForDuplicate => '복제할 이름';

  @override
  String get couldNotSave => '저장하지 못했습니다';

  @override
  String get details => '자세히';

  @override
  String get changedFields => '변경한 항목';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get none => '없음';

  @override
  String get saving => '저장하는 중입니다';

  @override
  String changed(String arg0) {
    return '$arg0를 바꿨습니다';
  }

  @override
  String andOthers(String arg0) {
    return '$arg0 외';
  }

  @override
  String items(num count) {
    return '$count개 항목';
  }

  @override
  String get saved => '저장했습니다';

  @override
  String get undo => '되돌리기';

  @override
  String get save => '저장';

  @override
  String get saveAndOpenNewTerminal => '저장하고 새 터미널';

  @override
  String get deleteHost => '호스트 삭제';

  @override
  String get couldNotSaveChanges => '변경 사항을 저장하지 못했습니다';

  @override
  String get add => '추가';

  @override
  String get cancel => '취소';

  @override
  String get saving2 => '저장 중…';

  @override
  String get apply => '적용';

  @override
  String get back => '뒤로';

  @override
  String get systemDefault => '시스템 기본값';

  @override
  String get appDefaultFont => '앱 기본 폰트';

  @override
  String get newSshKey => '새 SSH 키';

  @override
  String get enterAName => '이름을 입력하세요.';

  @override
  String get createAP256PrivateKeyInAndroidKeystore =>
      'P-256 개인키를 Android Keystore에 만들고 서명할 때마다 생체인증을 요구합니다. 개인키는 복사·내보내기·백업할 수 없습니다.';

  @override
  String get couldNotCreateKey => '키를 만들지 못했습니다';

  @override
  String get createKey => '키 만들기';

  @override
  String get search => '검색';

  @override
  String get saving3 => '저장 중';

  @override
  String changes(String arg0) {
    return '$arg0개 변경됨';
  }

  @override
  String enterAValueBetweenAnd(String arg0, String arg1) {
    return '$arg0–$arg1 사이로 입력하세요';
  }

  @override
  String decrease(String arg0) {
    return '$arg0 줄이기';
  }

  @override
  String increase(String arg0) {
    return '$arg0 늘리기';
  }

  @override
  String get discardChanges => '변경 사항 버리기';

  @override
  String get unsavedChangesWillBeLost => '저장하지 않은 변경 사항이 사라집니다.';

  @override
  String get keepEditing => '계속 편집';

  @override
  String get discard => '버리기';

  @override
  String get selectColor => '색상 선택';

  @override
  String get brightness => '밝기';

  @override
  String get hexColor => '16진 색상';

  @override
  String get enterASixDigitColor => '6자리 색상을 입력하세요';

  @override
  String get menu2 => '메뉴';

  @override
  String get defaultProfile => '기본 프로필';

  @override
  String get theSavedConnectionSettingsAreInvalid => '저장된 접속 설정이 올바르지 않습니다.';

  @override
  String theSavedSettingsAreInvalid(String arg0) {
    return '저장된 $arg0 설정이 올바르지 않습니다.';
  }

  @override
  String get theSavedColorThemeIsInvalid => '저장된 색상 테마가 올바르지 않습니다.';

  @override
  String get checkTheSshAddress => 'SSH 주소를 확인하세요.';

  @override
  String get useAnSshHost => 'SSH 호스트를 사용하세요.';

  @override
  String get thisTerminalUsesUtf8 => '이 터미널은 UTF-8을 사용합니다.';

  @override
  String get colorThemeNotFound => '색상 테마를 찾을 수 없습니다.';

  @override
  String get enterAThemeName => '테마 이름을 입력하세요.';

  @override
  String get aThemeWithThisNameAlreadyExists => '같은 이름의 테마가 있습니다.';

  @override
  String get colorsMustBeThreeOrSixDigitHexValues =>
      '색상은 3자리 또는 6자리 16진수여야 합니다.';

  @override
  String get invalidColorThemeFileFormat => '색상 테마 파일 형식이 올바르지 않습니다.';

  @override
  String get defaultColorIndicesMustBeBetween0And15 => '기본 색상 번호는 0–15여야 합니다.';

  @override
  String get ansiColorIndicesMustBeBetween0And15 => 'ANSI 색상 번호는 0–15여야 합니다.';

  @override
  String get invalidThemeDescriptionFormat => '테마 설명 형식이 올바르지 않습니다.';

  @override
  String get duplicateTheDefaultThemeBeforeEditingIt => '기본 테마는 복제한 뒤 편집하세요.';

  @override
  String get checkTheColorRole => '색상 역할을 확인하세요.';

  @override
  String get unsupportedThemeOperation => '지원하지 않는 테마 작업입니다.';

  @override
  String get onlyExplicitlyConfirmedNewServerKeysCanBeSaved =>
      '명시적으로 확인한 새 서버 키만 저장할 수 있습니다.';

  @override
  String get onlyTemporaryTransferFilesCanBeProcessed =>
      '전송 임시 파일만 처리할 수 있습니다.';

  @override
  String get checkTheSshJumpHostConnection => 'SSH 점프 호스트 연결을 확인하세요.';

  @override
  String get enterAServerAddress => '서버 주소를 입력하세요.';

  @override
  String get noHostToRestore => '복구할 호스트가 없습니다.';

  @override
  String get thisProfileIsInUse => '사용 중인 프로필입니다.';

  @override
  String get unsupportedLink => '지원하지 않는 링크입니다.';

  @override
  String get keyFile => '키 파일';

  @override
  String unsupportedOperation(String arg0) {
    return '지원하지 않는 작업입니다: $arg0';
  }

  @override
  String get androidKeystoreKeyUnavailable => 'Android Keystore 키를 사용할 수 없음';

  @override
  String get legacyPrivateKeyDisabled => '기존 개인키 · 사용 중지';

  @override
  String get toggleKeyboard => '키보드 전환';

  @override
  String get endSession => '세션 종료';

  @override
  String disconnectFrom(String arg0) {
    return '$arg0 연결을 종료할까요?';
  }

  @override
  String get end => '종료';

  @override
  String get couldNotCloseConnection => '연결을 닫지 못했습니다';

  @override
  String get noOpenSessions => '열린 세션이 없습니다.';

  @override
  String disconnected2(String arg0) {
    return '연결 종료$arg0';
  }

  @override
  String end2(String arg0) {
    return '$arg0 종료';
  }

  @override
  String get newTab => '새 탭';

  @override
  String close(String arg0) {
    return '$arg0 닫기';
  }

  @override
  String get image => '그림';

  @override
  String get words => '단어';

  @override
  String get firstConnectionToThisServer => '처음 연결하는 서버입니다';

  @override
  String get biometricAuthentication => '생체인증';

  @override
  String logInTo(String arg0) {
    return '$arg0 로그인';
  }

  @override
  String get server => '서버';

  @override
  String get hidePassword => '비밀번호 숨기기';

  @override
  String get showPassword => '비밀번호 보기';

  @override
  String get saveOnThisDevice => '이 기기에 저장';

  @override
  String get checkThatThisFingerprintMatchesTheOneProvidedBy =>
      '서버 관리자가 알려 준 지문과 같은지 확인하세요.';

  @override
  String get fingerprintFormat => '지문 형식';

  @override
  String authenticateWithKey(String arg0) {
    return '$arg0 키로 인증합니다.';
  }

  @override
  String get cancelConnection => '연결 취소';

  @override
  String get reject => '거절';

  @override
  String get trustAndConnect => '신뢰하고 연결';

  @override
  String get logIn => '로그인';

  @override
  String get continueAction => '계속';

  @override
  String waitingForLogin(String arg0) {
    return '$arg0 로그인 대기';
  }

  @override
  String get continueLogin => '로그인 계속';

  @override
  String pasteLines(String arg0) {
    return '$arg0줄을 붙여 넣을까요?';
  }

  @override
  String pastingLinesIntoTheTerminalMayRunCommandsImmediately(String arg0) {
    return '$arg0개 줄을 터미널에 붙여넣으면 명령이 즉시 실행될 수 있습니다.';
  }

  @override
  String get controlCharactersMayTriggerTerminalActionsOrCommandExecution =>
      '제어 문자가 포함되어 있어 터미널 동작이나 명령 실행을 유발할 수 있습니다.';

  @override
  String get pasteWithoutTrailingEnter => '마지막 Enter 빼고 붙여넣기';

  @override
  String pasteLines2(String arg0) {
    return '$arg0줄 붙여넣기';
  }

  @override
  String get editText => '텍스트 편집';

  @override
  String get textToSend => '전송할 텍스트';

  @override
  String get send => '전송';

  @override
  String get selectEntireLine => '줄 전체 선택';

  @override
  String get selectVisibleScreen => '보이는 화면 선택';

  @override
  String get selectAll => '전체 선택';

  @override
  String get blockSelection => '블록 선택';

  @override
  String get share => '공유';

  @override
  String get paste => '붙여넣기';

  @override
  String get copy2 => '복사';

  @override
  String get editAndSend => '편집 후 전송';

  @override
  String get moreSelectionOptions => '선택 메뉴 더보기';

  @override
  String get selectionEnd => '선택 끝';

  @override
  String get selectionStart => '선택 시작';

  @override
  String get clearSelection => '선택 해제';

  @override
  String couldNotConnectTo(String arg0) {
    return '$arg0에 연결하지 못했습니다';
  }

  @override
  String get couldNotCompleteOperation => '작업을 완료하지 못했습니다';

  @override
  String get couldNotFinishOperation => '작업을 마치지 못했습니다';

  @override
  String checked(String arg0) {
    return '확인 시각 · $arg0';
  }

  @override
  String occurred(String arg0) {
    return '발생 · $arg0';
  }

  @override
  String get copyErrorLog => '오류 기록 복사';

  @override
  String get close2 => '닫기';

  @override
  String get saveElsewhere => '다른 위치에 저장';

  @override
  String get retry => '다시 시도';

  @override
  String deletedHost(String arg0) {
    return '$arg0 호스트를 삭제했습니다';
  }

  @override
  String get ok => '확인';

  @override
  String linesEnterInsertsANewline(num count, String arg1) {
    return '$count줄 · Enter는 줄바꿈$arg1';
  }

  @override
  String get ctrlEnterSends => ', Ctrl Enter는 보내기';

  @override
  String unsupported(String arg0) {
    return ' · $arg0 미지원';
  }

  @override
  String verifyServerKeyFor(String arg0) {
    return '$arg0 서버 키 확인';
  }

  @override
  String get trustServerKey => '서버 키 신뢰';

  @override
  String authenticateWithKey2(String arg0) {
    return '$arg0 키로 인증해요.';
  }

  @override
  String get disconnectAll => '연결 모두 끊기';

  @override
  String get disconnectAllSessions => '모든 연결을 종료할까요?';

  @override
  String get disconnectAll2 => '모두 연결 끊기';

  @override
  String get removeServerKey => '서버 키를 지울까요?';

  @override
  String get theServerKeyWillBeVerifiedAgainOnThe => '다음에 연결할 때 서버 키를 다시 확인해요.';

  @override
  String get deleteServerKey => '서버 키 삭제';

  @override
  String sessions(String arg0) {
    return ' · 세션 $arg0';
  }

  @override
  String get fileTransferSftp => '파일 전송 (SFTP)';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get quickConnect => '빠른 연결';

  @override
  String get createSshKeyOnThisDevice => '이 기기에 SSH 키 만들기';

  @override
  String get sort => '정렬';

  @override
  String get byColor => '색상순';

  @override
  String get byName => '이름순';

  @override
  String get help => '도움말';

  @override
  String get unlock => '잠금 해제';

  @override
  String get couldNotPrepareAppData => '앱 데이터를 준비하지 못했습니다';

  @override
  String get preparingTilde => 'Tilde 준비 중';

  @override
  String get errorDetails => '오류 자세히';

  @override
  String get tildeHomeDirectory => 'Tilde 홈 디렉터리';

  @override
  String get inProgress => '진행 중';

  @override
  String get newOutput => '새 출력';

  @override
  String get error => '오류';

  @override
  String get notConnected => '연결 안 됨';

  @override
  String sessions2(num count) {
    return ' · 세션 $count개';
  }

  @override
  String get connectToYourFirstServer => '첫 서버를 연결하세요';

  @override
  String get saveAHostToConnectWithADoubleClick =>
      '호스트를 저장해 두면 다음부터 더블클릭으로 접속합니다.';

  @override
  String get saveAServerToConnectQuicklyNextTime => '서버를 저장해 두면 바로 접속할 수 있습니다.';

  @override
  String get saveAddressUserAndAuthentication => '주소 · 사용자 · 인증을 저장';

  @override
  String get connectNow => '바로 접속';

  @override
  String get connectByAddress => '주소로 바로 접속';

  @override
  String get enterSshUserHostInTheSearchFieldAnd =>
      '검색칸에 ssh user@host 입력 후 Enter';

  @override
  String get privateKeyFileSuchAsIdEd25519 => 'id_ed25519 같은 개인키 파일';

  @override
  String connectingTo(String arg0, String arg1) {
    return '$arg0:$arg1 연결 중';
  }

  @override
  String get negotiatingSshConnection => 'SSH 연결 협상 중';

  @override
  String get verifyingServerKey => '서버 키 확인 중';

  @override
  String authenticating(String arg0) {
    return '$arg0 인증 중';
  }

  @override
  String get authenticated => '인증 완료';

  @override
  String get openingTerminalSession => '터미널 세션 여는 중';

  @override
  String get confirmSshKeyUse => 'SSH 키 사용 확인';

  @override
  String get sshPrivateKeyPassphrase => 'SSH 개인키 암호';

  @override
  String get connectionBlockedBecauseTheServerKeyChangedReviewAnd =>
      '서버 키가 변경되어 연결을 차단했습니다. 저장된 서버 키를 확인한 뒤 직접 삭제하세요.';

  @override
  String get preparingSshLogin => 'SSH 로그인 준비 중';

  @override
  String get loggedInButCouldNotSaveThePasswordSave =>
      '로그인했지만 비밀번호를 저장하지 못했습니다. 호스트 편집에서 다시 저장하세요.';

  @override
  String sendTo(String arg0) {
    return '$arg0로 보내기';
  }

  @override
  String get send2 => '보내기';

  @override
  String get terminalSize => '터미널 크기';

  @override
  String get columns => '열';

  @override
  String get rows => '행';

  @override
  String get fullScreen => '전체 화면';

  @override
  String get autoHideTitleBar => '제목 줄 자동 숨김';

  @override
  String get terminalSizeColumnsRows => '터미널 크기 · 열×행';

  @override
  String get resize => '크기 변경';

  @override
  String get text8024LeaveBlankForAutomaticSizing => '80×24 · 빈 값은 자동';

  @override
  String get enterColumnsRowsSuchAs8024 => '‘80×24’처럼 열×행으로 입력해 주세요.';

  @override
  String get terminalLinks => '터미널 링크';

  @override
  String get noLinksOnScreen => '화면에 링크가 없습니다.';

  @override
  String get enterText => '텍스트 입력';

  @override
  String get links => '링크';

  @override
  String get reconnect => '다시 연결';

  @override
  String get couldNotVerifyServerKey => '서버 키를 확인하지 못했습니다';

  @override
  String get couldNotLogIn => '로그인하지 못했습니다';

  @override
  String get couldNotOpenTerminal => '터미널을 열지 못했습니다';

  @override
  String get couldNotConnectToServer => '서버에 연결하지 못했습니다';

  @override
  String connectingTo2(String arg0) {
    return '$arg0에 연결하는 중';
  }

  @override
  String get checkTheSavedServerKeyAndTheFingerprintProvided =>
      '저장된 서버 키와 서버 관리자가 알려 준 지문을 확인하세요.';

  @override
  String get checkYourUsernameAndCredentialsIfUsingAnSsh =>
      '사용자 이름과 인증 정보를 확인하세요. SSH 키를 사용한다면 서버에 공개키가 등록되어 있어야 합니다.';

  @override
  String get checkTheServerAddressPortAndNetworkConnection =>
      '서버 주소와 포트, 네트워크 연결을 확인하세요.';

  @override
  String get connectionLog => '연결 기록';

  @override
  String get deviceList => '기기 목록';

  @override
  String get view => '보기';

  @override
  String get dismissBanner => '배너 닫기';

  @override
  String get connectionClosed => '연결을 종료했습니다';

  @override
  String get theServerEndedTheSession => '서버에서 세션을 종료했습니다';

  @override
  String get connectionEndedAfterAuthenticationFailed => '인증에 실패해 연결이 종료되었습니다';

  @override
  String get connectionLost => '연결이 끊겼습니다';

  @override
  String ended(String arg0) {
    return '종료 · $arg0';
  }

  @override
  String get copyOutput => '출력 복사';

  @override
  String sshKey(String arg0) {
    return '$arg0 SSH 키';
  }

  @override
  String get couldNotPrepareRegistration => '등록 준비를 완료하지 못했습니다';

  @override
  String get keyToRegister => '등록할 키';

  @override
  String get newBiometricKey => '새 생체인증 키';

  @override
  String get createNewSshKey => '새 SSH 키 만들기';

  @override
  String get registerSshKeyLogin => 'SSH 키 로그인 등록';

  @override
  String keyRegistration(String arg0, String arg1) {
    return '$arg0 키 등록$arg1';
  }

  @override
  String get anotherHost => '다른 호스트';

  @override
  String get isInProgress => '을 진행 중입니다';

  @override
  String get isComplete => '이 끝났습니다';

  @override
  String get registrationPreparationForThisHost => '이 호스트의 등록 준비';

  @override
  String get installThePublicKeyThenVerifyKeyLoginWith =>
      '공개키를 등록한 뒤 별도 연결로 키 로그인을 확인합니다.';

  @override
  String get newKeyName => '새 키 이름';

  @override
  String get progress => '진행';

  @override
  String get installPublicKey => '공개키 등록';

  @override
  String get verifyKeyLogin => '키 로그인 검증';

  @override
  String get applyToHost => '호스트에 적용';

  @override
  String get theServerRejectedTheKey => '서버가 키를 거절했습니다';

  @override
  String get theServerRequiresAdditionalAuthentication => '서버가 추가 인증을 요구합니다';

  @override
  String get couldNotCompleteThisStep => '이 단계를 완료하지 못했습니다';

  @override
  String get installedOnServer => '서버에 등록했습니다';

  @override
  String get keyAlreadyInstalled => '이미 등록된 키입니다';

  @override
  String get keyLoginVerified => '키 로그인을 확인했습니다';

  @override
  String get theServerRejectedThisKey => '서버가 이 키를 거절했습니다';

  @override
  String get registrationComplete => '등록 완료';

  @override
  String usingKey(String arg0) {
    return '$arg0 키를 사용합니다';
  }

  @override
  String get removeSavedPasswordForThisHost => '이 호스트의 저장된 비밀번호 지우기';

  @override
  String get registerAndVerify => '등록 및 검증';

  @override
  String get continueInBackground => '백그라운드에서 계속';

  @override
  String get previewColorThemeFontAndMargins => '색상 테마·글꼴·여백 미리보기';

  @override
  String get srcBuildSampleMd => '\nsrc  build  한글.md';

  @override
  String get specialKeyBarPreview => '특수키 바 미리보기';

  @override
  String get fileTransferIsAvailableForSshHosts =>
      'SSH 호스트에서 파일 전송을 사용할 수 있습니다.';

  @override
  String get registerAKeyFromAConnectedSshSession => '연결된 SSH 세션에서 키를 등록해 주세요.';

  @override
  String get onlySshAndLocalConnectionsAreSupported => 'SSH와 로컬 연결만 지원합니다.';

  @override
  String get theConnectionTypeChangedOpenANewSessionFrom =>
      '연결 방식이 변경되었습니다. 홈에서 새 세션을 열어 주세요.';

  @override
  String get calculatingTimeRemaining => '남은 시간 계산 중';

  @override
  String minutesSecondsRemaining(String arg0, String arg1) {
    return '$arg0분 $arg1초 남음';
  }

  @override
  String secondsRemaining(String arg0) {
    return '$arg0초 남음';
  }

  @override
  String cancelling(String arg0) {
    return '$arg0 · 취소 중…';
  }

  @override
  String get checkingSize => '크기 확인 중';

  @override
  String get calculatingSpeed => '속도 계산 중';

  @override
  String active(String arg0) {
    return '진행 $arg0';
  }

  @override
  String queued(String arg0) {
    return '대기 $arg0';
  }

  @override
  String failed(String arg0) {
    return '실패 $arg0';
  }

  @override
  String completed(String arg0) {
    return '완료 $arg0';
  }

  @override
  String cancelled(String arg0) {
    return '취소 $arg0';
  }

  @override
  String get noTransfers => '전송 없음';

  @override
  String get queued2 => '대기';

  @override
  String get paused => '일시정지';

  @override
  String get completed2 => '완료';

  @override
  String get failed2 => '실패';

  @override
  String get cancelOperation => '작업 취소';

  @override
  String get openFolder => '폴더 열기';

  @override
  String couldNotComplete(String arg0) {
    return '$arg0을 완료하지 못했습니다';
  }

  @override
  String items2(String arg0, String arg1, String arg2) {
    return '$arg0 / $arg1개$arg2';
  }

  @override
  String transfer(String arg0) {
    return '전송 · $arg0';
  }

  @override
  String get transferQueue => '전송 목록';

  @override
  String get clearCompleted => '완료 지우기';

  @override
  String get collapseTransferQueue => '전송 목록 접기';

  @override
  String get expandTransferQueue => '전송 목록 펼치기';

  @override
  String get all => '전체';

  @override
  String get selectARegularFile => '일반 파일을 선택하세요.';

  @override
  String get aFileWithTheSameNameAlreadyExists => '같은 이름의 파일이 있습니다.';

  @override
  String get theSourceFileSizeChangedDuringTransfer =>
      '전송 중 원본 파일 크기가 변경되었습니다.';

  @override
  String get aFileWithTheSameNameAppearedDuringTransfer =>
      '전송 중 같은 이름의 파일이 생겼습니다.';

  @override
  String couldNotRemoveTheTemporaryUploadFileCheckThe(String arg0) {
    return '임시 업로드 파일을 지우지 못했습니다. 서버에서 확인하세요. $arg0';
  }

  @override
  String couldNotInspectTheTemporaryUploadFileCheckThe(String arg0) {
    return '임시 업로드 파일을 확인하지 못했습니다. 서버에서 확인하세요. $arg0';
  }

  @override
  String get changePermissions => '권한 변경';

  @override
  String get read => '읽기';

  @override
  String get write => '쓰기';

  @override
  String get execute => '실행';

  @override
  String get owner => '소유자';

  @override
  String get group => '그룹';

  @override
  String get other => '기타';

  @override
  String get octalPermissions => '8진수 권한';

  @override
  String get enterThreeOrFourDigitsFrom0To7 => '0–7로 된 3자리 또는 4자리 값을 입력하세요.';

  @override
  String get changePermissions2 => '권한 바꾸기';

  @override
  String couldNotOpenFolderCheckThePathAndPermissions(String arg0) {
    return '폴더를 열지 못했습니다. 경로와 접근 권한을 확인하세요.\n$arg0';
  }

  @override
  String get newFolder => '새 폴더';

  @override
  String get create => '만들기';

  @override
  String get destinationFolder => '이동할 폴더';

  @override
  String move(String arg0) {
    return '$arg0 이동';
  }

  @override
  String moveItems(String arg0) {
    return '$arg0개 항목 이동';
  }

  @override
  String get parentFolder => '상위 폴더';

  @override
  String get folderPath => '폴더 경로';

  @override
  String get editPath => '경로 편집';

  @override
  String get moveHere => '여기로 이동';

  @override
  String permanentlyDeleteItems(String arg0) {
    return '$arg0개 항목을 영구 삭제할까요?';
  }

  @override
  String childItems(String arg0) {
    return '하위 항목 $arg0개';
  }

  @override
  String get checkingContents => '내용 확인 중…';

  @override
  String get couldNotInspectFolderContentsTryAgain =>
      '폴더 내용을 확인하지 못했습니다. 다시 시도해 주세요.';

  @override
  String deleteAllItemsIncludingFolderContentsThisCannotBe(String arg0) {
    return '폴더 안 내용을 포함해 $arg0개 항목을 모두 지웁니다. 되돌릴 수 없습니다.';
  }

  @override
  String get deleteImmediatelyWithoutUsingTrashThisCannotBeUndone =>
      '휴지통 없이 바로 지웁니다. 되돌릴 수 없습니다.';

  @override
  String get deletePermanently => '영구 삭제';

  @override
  String get unknownModificationDate => '수정일 알 수 없음';

  @override
  String get aFileWithTheSameNameExists => '같은 이름의 파일이 있습니다';

  @override
  String transferringItems(String arg0, String arg1) {
    return '전송 $arg0 / $arg1개';
  }

  @override
  String get chooseWhichFileToKeepForEachConflict => '남길 파일을 각각 선택하세요.';

  @override
  String get fileBeingUploaded => '올리는 파일';

  @override
  String get fileBeingDownloaded => '내려받는 파일';

  @override
  String get existingFileOnServer => '서버의 기존 파일';

  @override
  String get existingFileOnDevice => '기기의 기존 파일';

  @override
  String get unknownSize => '크기 알 수 없음';

  @override
  String get keepTheExistingFileAndSkipCopyingThisFile =>
      '기존 파일을 유지하고 이 파일의 복사를 건너뜁니다.';

  @override
  String get keepBothAddTheFirstAvailableNumberStartingAt =>
      '둘 다 보관합니다. 복사되는 파일은 확장자 앞에 (1)부터 비어 있는 번호를 붙입니다.';

  @override
  String get overwriteTheExistingFileWithTheCopiedFileThis =>
      '복사되는 파일로 기존 파일을 덮어씁니다. 되돌릴 수 없습니다.';

  @override
  String get cancelCopyingKeepTheExistingFile => '복사를 취소합니다. 기존 파일은 그대로 유지됩니다.';

  @override
  String applyToRemainingItems(String arg0) {
    return '남은 $arg0개에도 적용';
  }

  @override
  String get cancelTransfer => '전송 취소';

  @override
  String get cancelCopy => '복사 취소';

  @override
  String get loggingInForFileTransfer => '파일 전송 로그인 중';

  @override
  String get couldNotLogInForFileTransfer => '파일 전송에 로그인하지 못했습니다.';

  @override
  String get previewSupportsFilesUpTo4MibDownloadThe =>
      '미리보기는 4 MiB 이하 파일을 지원합니다. 다운로드해서 열어 주세요.';

  @override
  String get saveFile => '파일 저장';

  @override
  String get theEditorCannotOverwriteFoldersOrSymbolicLinks =>
      '폴더나 심볼릭 링크는 편집기로 덮어쓰지 않습니다.';

  @override
  String get serverFileChanged => '서버 파일 변경됨';

  @override
  String theServerFileChangedAfterEditingBeganOverwriteIt(String arg0) {
    return '$arg0\n서버 파일이 편집 시작 후 변경되었습니다. 덮어쓸까요?';
  }

  @override
  String overwriteTheExistingFile(String arg0) {
    return '$arg0\n기존 파일을 덮어쓸까요?';
  }

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get couldNotReconnectToTheServerCheckAuthenticationIn =>
      '서버에 다시 연결하지 못했습니다. 파일 목록에서 인증을 확인하세요.';

  @override
  String get saveACopyElsewhere => '다른 위치에 사본 저장';

  @override
  String get saveCopy => '사본 저장';

  @override
  String get enterAnAbsolutePathIncludingTheFileName =>
      '파일 이름을 포함한 절대 경로를 입력하세요.';

  @override
  String get enterAPathDifferentFromTheOriginal => '원본과 다른 경로를 입력하세요.';

  @override
  String get newFile => '새 파일';

  @override
  String get anItemWithTheSameNameAlreadyExists => '같은 이름의 항목이 있습니다.';

  @override
  String get thisItemIsBeingTransferred => '전송 중인 항목입니다.';

  @override
  String get rename => '이름 변경';

  @override
  String get change => '변경';

  @override
  String get creatingFolder => '폴더 만드는 중';

  @override
  String get folderCreated => '폴더를 만들었습니다.';

  @override
  String get deleting => '삭제 중';

  @override
  String deletingItems(String arg0) {
    return '$arg0개 항목 삭제 중';
  }

  @override
  String deletedItems(String arg0) {
    return '$arg0개 항목을 삭제했습니다.';
  }

  @override
  String itemsWereDeleted(String arg0) {
    return ' · $arg0개 항목은 삭제되었습니다.';
  }

  @override
  String get changingPermissions => '권한 변경 중';

  @override
  String get symbolicLinkPermissionsWillNotBeChanged =>
      '심볼릭 링크의 권한은 변경하지 않습니다.';

  @override
  String get permissionsChanged => '권한을 변경했습니다.';

  @override
  String operationCancelled(String arg0) {
    return '작업을 취소했습니다.$arg0';
  }

  @override
  String couldNotCompleteOperation2(String arg0) {
    return '작업을 완료하지 못했습니다.$arg0';
  }

  @override
  String itemsPasteInTheDestinationFolder(String arg0, String arg1) {
    return '$arg0개 항목 $arg1 · 대상 폴더에서 붙여넣으세요.';
  }

  @override
  String get cut => '잘라내기';

  @override
  String get noFilesToPaste => '붙여넣을 파일이 없습니다.';

  @override
  String get cannotMoveOrCopyToTheSameLocationOr =>
      '같은 위치나 자기 폴더 안으로 이동·복사할 수 없습니다.';

  @override
  String get move2 => '이동';

  @override
  String get copyTemporaryDownloadAndUpload => '복사 (임시 다운로드 후 업로드)';

  @override
  String get upload => '업로드';

  @override
  String get download => '다운로드';

  @override
  String get choosingAFolderDestinationIsUnsupportedOnThisPlatform =>
      '이 플랫폼에서는 폴더 저장 위치 선택을 지원하지 않습니다.';

  @override
  String get connectionClosed2 => '연결이 닫혔습니다.';

  @override
  String get downloadToFileManager => '탐색기로 다운로드';

  @override
  String get theTemporaryExportPathAlreadyExists => '내보내기 임시 경로가 이미 존재합니다.';

  @override
  String get cancelTransfersAndClose => '전송 취소하고 닫기';

  @override
  String get cancelActiveTransfersAndQueuedOperationsInThisTab =>
      '이 탭에서 진행 중인 전송과 대기 중인 작업을 취소할까요?';

  @override
  String get uploadFolder => '폴더 업로드';

  @override
  String get connectionCancelled => '연결을 취소했습니다';

  @override
  String get couldNotOpenFileList => '파일 목록을 열지 못했습니다';

  @override
  String fileTransfer2(String arg0) {
    return '$arg0 · 파일 전송';
  }

  @override
  String get fileList => '파일 목록';

  @override
  String get checkTheFolderPathAndPermissionsThenTryAgain =>
      '폴더 경로와 접근 권한을 확인한 뒤 다시 시도하세요.';

  @override
  String get bookmarkCurrentFolder => '현재 폴더 즐겨찾기';

  @override
  String get recentLocations => '최근 위치';

  @override
  String selected(String arg0) {
    return '$arg0개 선택';
  }

  @override
  String get forward => '앞으로';

  @override
  String get remoteFolderPath => '원격 폴더 경로';

  @override
  String get bookmarksAndRecentLocations => '즐겨찾기·최근 위치';

  @override
  String get refresh => '새로고침';

  @override
  String get findInCurrentFolder => '현재 폴더에서 찾기';

  @override
  String get readOnly => '읽기 전용';

  @override
  String get discardChanges2 => '변경 내용 버리기';

  @override
  String discardUnsavedChanges(String arg0) {
    return '$arg0\n저장하지 않은 변경 내용을 버릴까요?';
  }

  @override
  String get doNotSave => '저장하지 않음';

  @override
  String get editing => '편집 중';

  @override
  String get saveCopyKeepOriginalUnchanged => '사본 저장 · 원본은 저장하지 않음';

  @override
  String savedACopyTo(String arg0) {
    return '$arg0에 사본을 저장했습니다.';
  }

  @override
  String get saved2 => '저장했습니다.';

  @override
  String get couldNotOpenFile => '파일을 열지 못했습니다';

  @override
  String couldNotOpen(String arg0) {
    return '$arg0을 열지 못했습니다';
  }

  @override
  String get previewIsUnsupportedForThisFileType => '이 파일 형식은 미리보기를 지원하지 않습니다.';

  @override
  String get couldNotSaveYourChangesHaveBeenKept => '저장하지 못했습니다. 변경 내용은 유지됩니다.';

  @override
  String couldNotSave2(String arg0) {
    return '$arg0을 저장하지 못했습니다';
  }

  @override
  String utf8LineBytes(String arg0, String arg1, String arg2) {
    return ' · UTF-8$arg0 · $arg1줄 · $arg2 B';
  }

  @override
  String get unsupportedFileType => '지원하지 않는 파일 종류입니다.';

  @override
  String get unsupportedRemoteFileType => '지원하지 않는 원격 파일 종류입니다.';

  @override
  String get theTransferSourceChangedStartANewTransfer =>
      '전송 원본이 변경되었습니다. 새 작업으로 다시 전송하세요.';

  @override
  String get anItemWithThisNameExistsAndIsNot => '같은 이름의 폴더가 아닌 항목이 있습니다.';

  @override
  String get cannotOverwriteAFolderWithAFile => '폴더를 파일로 덮어쓸 수 없습니다.';

  @override
  String get namesCannotContainPathSeparatorsOrBeOr =>
      '이름에 경로 구분자나 . 또는 ..를 사용할 수 없습니다.';

  @override
  String get aFileOrFolderWithTheSameNameAlready => '같은 이름의 파일이나 폴더가 있습니다.';

  @override
  String get cannotMoveAFolderIntoItselfOrItsDescendants =>
      '자기 자신이나 하위 폴더로 이동할 수 없습니다.';

  @override
  String get cannotDeleteTheRootFolder => '루트 폴더는 삭제할 수 없습니다.';

  @override
  String get theServerDeniedAccessCheckTheDestinationPathPermissions =>
      '서버에서 접근 권한을 거부했습니다. 대상 경로의 권한을 확인하세요.';

  @override
  String get theFileOrFolderNoLongerExists => '파일이나 폴더가 더 이상 없습니다.';

  @override
  String get serverConnectionLost => '서버 연결이 끊겼습니다.';

  @override
  String get theServerCouldNotCompleteTheOperation => '서버에서 작업을 완료하지 못했습니다.';

  @override
  String get theServerIsNotRespondingCheckTheAddressAnd =>
      '서버가 응답하지 않습니다. 주소와 네트워크를 확인하세요.';

  @override
  String get theServerDidNotAuthenticateYouCheckYourUsername =>
      '서버에서 인증을 받지 않았습니다. 사용자 이름과 키·비밀번호를 확인하세요.';

  @override
  String theServerRefusedTheConnectionCheckSshAndPort(String arg0) {
    return '서버가 $arg0연결을 거부했습니다. SSH 실행 상태와 포트를 확인하세요.';
  }

  @override
  String onPort(String arg0) {
    return '$arg0번 포트 ';
  }

  @override
  String get checkTheServerConnection => '서버 연결을 확인하세요.';

  @override
  String get unexpectedErrorCopyTheDetailsBelowAndContactSupport =>
      '예상하지 못한 오류입니다. 아래 기록을 복사해 문의해 주세요.';

  @override
  String get transferCancelled => '전송을 취소했습니다.';

  @override
  String get invalidFileName => '파일 이름이 올바르지 않습니다.';

  @override
  String get theFileWasNotReceivedCompletely => '파일이 끝까지 도착하지 않았습니다.';

  @override
  String get size => '크기';

  @override
  String get modified => '수정일';

  @override
  String get permissions => '권한';

  @override
  String get ownerUid => '소유자 UID';

  @override
  String get groupGid => '그룹 GID';

  @override
  String get showHiddenFilesAndFolders => '숨김 파일·폴더 표시';

  @override
  String get descending => '내림차순';

  @override
  String get visibleColumns => '목록에 보일 정보';

  @override
  String get preview => '미리보기';

  @override
  String get move3 => '이동…';

  @override
  String get copyPath => '경로 복사';

  @override
  String get info => '정보';

  @override
  String get changePermissions3 => '권한 변경…';

  @override
  String get fileInformation => '파일 정보';

  @override
  String get path => '경로';

  @override
  String get type2 => '종류';

  @override
  String get folder => '폴더';

  @override
  String get symbolicLink => '심볼릭 링크';

  @override
  String get file => '파일';

  @override
  String get clearSearch => '검색 지우기';

  @override
  String get location => '위치';

  @override
  String selected2(String arg0, String arg1) {
    return '$arg0개 선택 · $arg1';
  }

  @override
  String get parentFolderBackspace => '상위 폴더 (Backspace)';

  @override
  String get loading => '불러오는 중…';

  @override
  String get noFilesToDisplay => '표시할 파일이 없습니다.';

  @override
  String get noMatchingFiles => '조건에 맞는 파일이 없습니다.';

  @override
  String get applyNewName => '이름 변경 적용';

  @override
  String actions(String arg0) {
    return '$arg0 작업';
  }

  @override
  String items3(String arg0, String arg1) {
    return '$arg0개 항목$arg1';
  }

  @override
  String hiddenFiltered(String arg0) {
    return ' · $arg0개 숨김/필터';
  }

  @override
  String copy3(String arg0) {
    return '$arg0 복사본';
  }

  @override
  String hostsWillUseTheAppDefaultProfile(String arg0) {
    return '$arg0개 호스트가 앱 기본 프로필을 사용하게 됩니다.';
  }

  @override
  String get deleteThisProfile => '이 프로필을 삭제합니다.';

  @override
  String connectionsForHostsWillRemainButTheSharedPassword(String arg0) {
    return '$arg0개 호스트의 연결은 남지만 공용 비밀번호는 삭제됩니다.';
  }

  @override
  String delete2(String arg0) {
    return '$arg0 삭제';
  }

  @override
  String get setAsDefault => '기본으로 지정';

  @override
  String add2(String arg0) {
    return '$arg0 추가';
  }

  @override
  String get shareAUsernameKeyAndPasswordAcrossMultipleHosts =>
      '여러 호스트에서 사용자 이름·키·비밀번호를 함께 사용합니다.';

  @override
  String get default2 => ' · 기본';

  @override
  String get noHostsUsingThis => '쓰는 호스트 없음';

  @override
  String hosts(num count) {
    return '호스트 $count개';
  }

  @override
  String get privateKeyPassphrase => '개인키 암호';

  @override
  String get leaveBlankIfThereIsNoPassphrase => '암호가 없으면 비워두세요.';

  @override
  String get deleteKey2 => '키 삭제';

  @override
  String deleteKey3(String arg0) {
    return '$arg0 키를 삭제할까요?';
  }

  @override
  String get savePublicKeyFile => '공개키 파일 저장';

  @override
  String get addKeyFile => '키 파일 추가';

  @override
  String get newKey => '새 키';

  @override
  String get couldNotCompleteKeyOperation => '키 작업을 완료하지 못했습니다';

  @override
  String get importedPrivateKeysAreUsedFromProtectedAppStorage =>
      '가져온 개인키는 앱의 보호된 저장소에서 사용합니다. 저장한 키 암호는 iOS Keychain으로 보호합니다.';

  @override
  String get privateKeyFilesAreUsedFromTheirOriginalLocation =>
      '개인키 파일은 원래 위치에서 사용합니다. 저장한 키 암호는 Windows 계정으로 보호합니다.';

  @override
  String get privateKeysAreCreatedInAndroidKeystoreAndCannot =>
      '개인키는 Android Keystore에서 생성되며 기기 밖으로 내보낼 수 없습니다. 기존 개인키는 사용 중지 상태로 보존됩니다.';

  @override
  String get disabled => '사용 중지';

  @override
  String options(String arg0) {
    return '$arg0 옵션';
  }

  @override
  String get deleteForwarding => '포워딩 삭제';

  @override
  String deleteSettingsFor(String arg0) {
    return '$arg0 설정을 삭제할까요?';
  }

  @override
  String forwarding2(String arg0) {
    return '$arg0 · 포워딩';
  }

  @override
  String get addForwarding => '포워딩 추가';

  @override
  String get sessionToControl => '제어할 세션';

  @override
  String switchChangesApplyImmediately(String arg0) {
    return '$arg0 · 스위치를 바꾸면 즉시 적용됩니다';
  }

  @override
  String get defaultOnConnection => '접속 시 기본값';

  @override
  String get couldNotLoadForwarding => '포워딩을 불러오지 못했습니다';

  @override
  String get socks4UnsupportedChangeToSocks5 => 'SOCKS4 미지원 · SOCKS5로 변경하세요';

  @override
  String get removeServerKeyTrust => '서버 키 신뢰 삭제';

  @override
  String theServerKeyWillBeVerifiedOnTheNext(String arg0, String arg1) {
    return '$arg0:$arg1\n다음 접속에서 서버 키를 다시 확인합니다.';
  }

  @override
  String get noTrustedServerKeys => '신뢰한 서버 키가 없습니다.';

  @override
  String get use => '사용';

  @override
  String get editPalette => '팔레트 편집';

  @override
  String get export => '내보내기';

  @override
  String get defaultTheme => '기본 테마';

  @override
  String get customTheme => '사용자 테마';

  @override
  String get nameForDuplicateTheme => '복제할 테마 이름';

  @override
  String get themeName => '테마 이름';

  @override
  String get deleteTheme => '테마 삭제';

  @override
  String deleteTheme2(String arg0) {
    return '$arg0 테마를 삭제할까요?';
  }

  @override
  String get newThemeName => '새 테마 이름';

  @override
  String get newTheme => '새 테마';

  @override
  String get import => '가져오기';

  @override
  String get textColor => '글자 색';

  @override
  String get backgroundColor => '배경 색';

  @override
  String get cursorAndAppAccent => '커서 · 앱 강조색';

  @override
  String get couldNotLoadColorTheme => '색상 테마를 불러오지 못했습니다';

  @override
  String get makeACopyToEditTheColors => '복사본을 만들어 색상을 편집하세요.';

  @override
  String get lsSrcBuildSampleMd => '~ \$ ls\nsrc  build  한글.md\n';

  @override
  String get defaultColors => '기본 색';

  @override
  String get lowContrastAgainstBackground => '배경과 대비가 낮습니다';

  @override
  String get ansiPalette => 'ANSI 팔레트';

  @override
  String ansiColor(String arg0) {
    return 'ANSI $arg0 색상';
  }

  @override
  String get findServer => '서버 찾기';

  @override
  String get verifyServerKey => '서버 키 확인';

  @override
  String seconds(String arg0) {
    return '$arg0초';
  }

  @override
  String get couldNotOpenAdPrivacySettingsTryAgain =>
      '광고 개인정보 설정을 열지 못했습니다. 다시 시도해 주세요.';

  @override
  String get ad => '광고';

  @override
  String get adPrivacySettings => '광고 개인정보 설정';

  @override
  String get googleFontsMonospace => 'Google Fonts · 고정폭';

  @override
  String get searchSettings => '설정 검색';

  @override
  String get keyboard => '키보드';

  @override
  String get gestures => '제스처';

  @override
  String get connectionsAndNotifications => '연결·알림';

  @override
  String get securityAndBackup => '보안·백업';

  @override
  String get manageFonts => '폰트 관리';

  @override
  String get specialKeyBar => '특수키 바';

  @override
  String specialKeys(String arg0) {
    return '특수키 $arg0개';
  }

  @override
  String twoFingerHorizontalSwipe(String arg0) {
    return '두 손가락 가로 · $arg0';
  }

  @override
  String get tmuxWindows => 'tmux 창';

  @override
  String get disabled2 => '사용 안 함';

  @override
  String get defaultTerminal => '기본 터미널';

  @override
  String get notificationsAndBell => '알림 · 벨 소리';

  @override
  String sshKeys2(num count) {
    return 'SSH 키 $count개';
  }

  @override
  String get helpAndLogs2 => '도움말 및 로그';

  @override
  String get horizontalMargins => '좌우 여백';

  @override
  String get lines => '줄';

  @override
  String get appTheme => '앱 테마';

  @override
  String get systemTheme => '시스템 테마';

  @override
  String get light => '밝게';

  @override
  String get dark => '어둡게';

  @override
  String get font => '글꼴';

  @override
  String get orientation => '화면 방향';

  @override
  String get alwaysRotate => '항상 회전';

  @override
  String get portrait => '세로';

  @override
  String get landscape => '가로';

  @override
  String get hideStatusBar => '상태 표시줄 숨기기';

  @override
  String get specialKeyLayout => '특수키 구성';

  @override
  String get showWhenKeyboardIsClosed => '키보드를 닫아도 표시';

  @override
  String get whenPressingCtrlOrAlt => 'Ctrl·Alt를 누르면';

  @override
  String get once => '한 번';

  @override
  String get sticky => '고정';

  @override
  String get stickyAltOnly => 'Alt만 고정';

  @override
  String get keyboardToggleButton => '키보드 전환 버튼';

  @override
  String get twoFingerHorizontalSwipe2 => '두 손가락으로 좌우로 밀면';

  @override
  String get doNothing => '아무것도 안 함';

  @override
  String get switchSessions => '세션 전환';

  @override
  String get switchTmuxWindows => 'tmux 창 전환';

  @override
  String get prefixKey => '접두키';

  @override
  String get twoFingerVerticalSwipe => '두 손가락으로 위아래로 밀면';

  @override
  String get scroll => '스크롤';

  @override
  String get volumeButtonsChangeFontSize => '볼륨 버튼으로 글자 크기';

  @override
  String get specialKeyVibration => '특수키 진동';

  @override
  String get defaultTerminalProfile => '기본 터미널 프로필';

  @override
  String get manageTerminalProfiles => '터미널 프로필 관리';

  @override
  String itemCount(String arg0) {
    return '$arg0개';
  }

  @override
  String get appearance => '표시';

  @override
  String get terminalTypeTerm => '터미널 종류 (TERM)';

  @override
  String get addTerminalType => '터미널 종류 추가';

  @override
  String get terminalType => '터미널 종류';

  @override
  String get keepScreenAwakeWhileConnected => '연결 중 화면 켜짐 유지';

  @override
  String get theTerminalScreenWillStayAwake => '터미널 화면이 자동으로 꺼지지 않습니다';

  @override
  String get preventWiFiSleep => 'Wi-Fi 절전 방지';

  @override
  String get usesMoreBattery => '배터리를 더 씁니다';

  @override
  String get backgroundConnectionNotification => '백그라운드 연결 알림';

  @override
  String get pinnedWhileConnected => '연결 중일 때 상단에 고정';

  @override
  String get terminalBell => '터미널 벨';

  @override
  String get whenTheBellRings => '벨이 울리면';

  @override
  String get ignore => '무시';

  @override
  String get sound => '소리';

  @override
  String get vibration => '진동';

  @override
  String get soundAndVibration => '소리·진동';

  @override
  String get volume => '음량';

  @override
  String get notifications => '알림';

  @override
  String get notificationPermissionRequired => '알림 권한이 필요합니다';

  @override
  String get allow => '허용';

  @override
  String get enableConnectionNotifications => '연결 알림 사용';

  @override
  String get allowBellAndDisconnectionNotifications => '벨·연결 끊김 알림을 허용합니다';

  @override
  String get bellInBackground => '백그라운드에서 벨';

  @override
  String get onDisconnect => '연결이 끊기면';

  @override
  String get androidNotificationSettings => 'Android 알림 설정';

  @override
  String get notificationsOff => '알림 꺼짐';

  @override
  String get notificationsAllowed => '알림 허용됨';

  @override
  String get lock => '잠금';

  @override
  String get unlockWhenStartingTheApp => '앱 실행 시 잠금 해제';

  @override
  String get setUpAScreenLockFirst => '화면 잠금을 먼저 설정하세요';

  @override
  String get fingerprintOrScreenLock => '지문 또는 화면 잠금';

  @override
  String get keysAndServers => '키와 서버';

  @override
  String get configurationFile => '설정 파일';

  @override
  String get exportHosts => '호스트 내보내기';

  @override
  String get importHosts => '호스트 가져오기';

  @override
  String get selectDefaultFont => '기본 폰트 선택';

  @override
  String fontSample(String arg0) {
    return '$arg0 가나다';
  }

  @override
  String get bundledWithApp => '앱에 포함';

  @override
  String get monospaceFont => '고정폭 폰트';

  @override
  String get deleteFont => '폰트 삭제';

  @override
  String get deleteThisFontFile => '이 폰트 파일을 삭제할까요?';

  @override
  String get removeFont => '폰트 제거';

  @override
  String get preparingFont => '폰트 준비 중';

  @override
  String get importFontFile => '폰트 파일 가져오기';

  @override
  String get findOnGoogleFonts => 'Google Fonts에서 찾기';

  @override
  String get onlyMonospaceFontsAreShown => '고정폭 폰트만 보여 줍니다';

  @override
  String settings2(String arg0) {
    return '설정 › $arg0';
  }

  @override
  String get couldNotSaveSettings => '설정을 저장하지 못했습니다';

  @override
  String get resetSpecialKeyBar => '특수키 바를 되돌릴까요?';

  @override
  String get restoreTheDefaultHeightKeyOrderAndVisibility =>
      '높이와 키 순서·표시를 기본값으로 되돌려요.';

  @override
  String get longPressToDragTapToHide => '길게 눌러 끌기 · 탭하면 숨김';

  @override
  String get hiddenKeys => '숨긴 키';

  @override
  String get tapAKeyToMoveItHere => '키를 탭하면 여기로 옮겨져요';

  @override
  String get combineF1F12IntoFn => 'F1–F12를 Fn 하나로';

  @override
  String get height => '높이';

  @override
  String get small => '작게';

  @override
  String get large => '크게';

  @override
  String get default3 => '기본';

  @override
  String get escAndCtrlStayOnTheLeftKeyboardFn =>
      'Esc·Ctrl은 왼쪽, 키보드·Fn·tab은 오른쪽에 고정돼요.';

  @override
  String get flutterLibraryLicenses => 'Flutter 라이브러리 라이선스';

  @override
  String get tips => '사용 팁';

  @override
  String get licensesAndTerms => '라이선스 및 이용 조건';

  @override
  String get projectAndContact => '프로젝트 및 문의';

  @override
  String get diagnostics => '진단';

  @override
  String get diagnosticLogs => '진단 로그';

  @override
  String get searchLogs => '로그 검색';

  @override
  String get saveNativeCrashLog => '네이티브 크래시 기록 저장';

  @override
  String get warning => '경고';

  @override
  String get couldNotLoadLogs => '로그를 불러오지 못했습니다';

  @override
  String get onlyAndroidKeystoreSshKeysAreSupported =>
      'Android Keystore SSH 키만 지원합니다.';

  @override
  String get onlyP256AndroidKeystoreKeysAreSupported =>
      'P-256 Android Keystore 키만 지원합니다.';

  @override
  String get invalidEcdsaSignature => 'ECDSA 서명이 올바르지 않습니다.';

  @override
  String get invalidEcdsaSignatureValues => 'ECDSA 서명 값이 올바르지 않습니다.';

  @override
  String get invalidX509PublicKey => 'X509 공개키가 올바르지 않습니다.';

  @override
  String get invalidPublicKeyBitString => '공개키 비트 문자열이 올바르지 않습니다.';

  @override
  String get invalidRsaPublicKey => 'RSA 공개키가 올바르지 않습니다.';

  @override
  String get invalidEcCurve => 'EC 곡선이 올바르지 않습니다.';

  @override
  String get invalidUncompressedEcPoint => '비압축 EC 점이 올바르지 않습니다.';

  @override
  String get invalidEd25519PublicKey => 'Ed25519 공개키가 올바르지 않습니다.';

  @override
  String unsupportedSshPublicKeyAlgorithm(String arg0) {
    return '지원하지 않는 SSH 공개키 알고리즘: $arg0';
  }

  @override
  String get unsupportedSshEcCurve => '지원하지 않는 SSH EC 곡선입니다.';

  @override
  String get invalidDerSequence => 'DER 시퀀스가 올바르지 않습니다.';

  @override
  String get privateKeyExportIsNotSupported => '개인키 내보내기를 지원하지 않습니다.';

  @override
  String get publicKeyIsUnavailable => '공개키를 사용할 수 없습니다.';

  @override
  String unsupportedTerminalKey(String arg0) {
    return '지원하지 않는 터미널 키: $arg0';
  }

  @override
  String get disconnectBeforeReconnecting => '연결을 끊은 뒤 다시 연결하세요.';

  @override
  String get localShellIsNotOpen => '로컬 셸이 열려 있지 않습니다.';

  @override
  String get unknownModifier => '알 수 없는 보조키입니다.';

  @override
  String unsupportedLocalTerminalOperation(String arg0) {
    return '지원하지 않는 로컬 터미널 작업: $arg0';
  }

  @override
  String get invalidSshPublicKeyLine => 'SSH 공개키 형식이 올바르지 않습니다.';

  @override
  String get serverDidNotConfirmPublicKeyRegistration =>
      '서버에서 공개키 등록을 확인하지 못했습니다.';

  @override
  String get logInToASavedSshHostBeforeRegistering =>
      '저장된 SSH 호스트에 로그인한 뒤 키를 등록하세요.';

  @override
  String get theSelectedSshKeyNoLongerExists => '선택한 SSH 키가 더 이상 없습니다.';

  @override
  String get aUniqueBiometricKeyNameIsRequired =>
      '다른 키와 겹치지 않는 생체인증 키 이름을 입력하세요.';

  @override
  String get theOriginalSshConnectionIsNoLongerAuthenticated =>
      '기존 SSH 연결의 인증이 더 이상 유효하지 않습니다.';

  @override
  String get keyOnlyLoginWasNotCompletedTheServerMay =>
      '키만으로 로그인하지 못했습니다. 서버에서 추가 인증을 요구할 수 있습니다. 로그인 설정은 변경되지 않았습니다.';

  @override
  String get theSavedHostNoLongerExists => '저장된 호스트가 더 이상 없습니다.';

  @override
  String get theHostAddressChangedDuringRegistrationItsLoginSettings =>
      '등록 중 호스트 주소가 변경되었습니다. 로그인 설정은 변경되지 않았습니다.';

  @override
  String get invalidPtyDimensions => '터미널 크기가 올바르지 않습니다.';

  @override
  String get sshTargetIsRequired => 'SSH 연결 대상을 지정하세요.';

  @override
  String get sshSessionWasClosed => 'SSH 세션이 닫혔습니다.';

  @override
  String get sshSessionIsNotConnected => 'SSH 세션이 연결되지 않았습니다.';

  @override
  String get sshSessionsCannotBeReused => 'SSH 세션은 재사용할 수 없습니다.';

  @override
  String get noAddressForRequestedIpVersion => '요청한 IP 버전에 해당하는 주소가 없습니다.';

  @override
  String get sshHopConnectionTimedOut => 'SSH 경유 연결 시간이 초과되었습니다.';

  @override
  String get sshSessionHasNoShell => 'SSH 세션에 셸이 없습니다.';

  @override
  String get sshSessionRequestTimedOut => 'SSH 세션 요청 시간이 초과되었습니다.';

  @override
  String get invalidForwardBindPort => '포워딩 수신 포트가 올바르지 않습니다.';

  @override
  String get invalidForwardDestination => '포워딩 대상이 올바르지 않습니다.';

  @override
  String get remoteForwardingRequestTimedOut => '원격 포워딩 요청 시간이 초과되었습니다.';

  @override
  String get remoteForwardingWasRefused => '원격 포워딩이 거부되었습니다.';

  @override
  String get forwardConnectionTimedOut => '포워딩 연결 시간이 초과되었습니다.';

  @override
  String get remoteForwardDestinationTimedOut => '원격 포워딩 대상 연결 시간이 초과되었습니다.';

  @override
  String get remoteForwardingCancellationWasRefused => '원격 포워딩 취소가 거부되었습니다.';

  @override
  String get sshAuthenticationCancelled => 'SSH 인증을 취소했습니다.';

  @override
  String get concurrentSshAuthenticationPrompt => 'SSH 인증 요청이 이미 진행 중입니다.';

  @override
  String get sessionDisposed => '세션이 종료되었습니다.';

  @override
  String get disconnectBeforeRefreshingSshConfiguration =>
      '연결을 끊은 뒤 SSH 설정을 새로고침하세요.';

  @override
  String get couldNotUnlockTheSelectedKey => '선택한 키의 잠금을 해제하지 못했습니다.';

  @override
  String get logInToThisServerBeforeRegisteringAKey => '이 서버에 로그인한 뒤 키를 등록하세요.';

  @override
  String get sshShellIsNotOpen => 'SSH 셸이 열려 있지 않습니다.';

  @override
  String get sshIsNotConnected => 'SSH가 연결되지 않았습니다.';

  @override
  String get portForwardIsMissing => '포트 포워딩 설정이 없습니다.';

  @override
  String get unsupportedSshForwardType => '지원하지 않는 SSH 포워딩 방식입니다.';

  @override
  String unsupportedAppSshOperation(String arg0) {
    return '지원하지 않는 앱 SSH 작업: $arg0';
  }

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get timedOutReadingWindowsSshSettings =>
      'Windows SSH 설정 조회 시간이 초과됐습니다.';

  @override
  String couldNotReadWindowsSshSettings(String arg0) {
    return 'Windows SSH 설정을 읽지 못했습니다. $arg0';
  }

  @override
  String get windowsUserProfilePathIsUnavailable => 'Windows 사용자 프로필 경로가 없습니다.';

  @override
  String unsupportedSshKeyPathVariable(String arg0) {
    return '지원하지 않는 SSH 키 경로 변수: $arg0';
  }

  @override
  String couldNotImportFiles(String arg0) {
    return '파일을 가져오지 못했습니다: $arg0';
  }

  @override
  String uploadTo(String arg0) {
    return '$arg0에 업로드합니다';
  }

  @override
  String get currentFolder => '현재 폴더';

  @override
  String get windowsUserDataFolderIsUnavailable => 'Windows 사용자 데이터 폴더가 없습니다.';

  @override
  String couldNotProtectCredentialsWithTheWindowsAccount(String arg0) {
    return 'Windows 계정의 인증정보 보호에 실패했습니다. $arg0';
  }

  @override
  String get altDrag => 'Alt 드래그';

  @override
  String get keyUp => '위로';

  @override
  String get keyDown => '아래로';

  @override
  String get keyHome => '줄 처음으로';

  @override
  String get keyEnd => '줄 끝으로';

  @override
  String get keyPageUp => '이전 페이지';

  @override
  String get keyPageDown => '다음 페이지';

  @override
  String get keyInsert => '삽입';

  @override
  String get keyDelete => '삭제';
}
