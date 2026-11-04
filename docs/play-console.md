# Tilde Play 등록

## 빌드와 서명

Play 패키지는 `com.korellas.tilde`다. 기존 Mink Store 앱은 별도 패키지이며,
Play 앱을 설치해도 기존 앱의 연결 설정과 키가 자동으로 이전되지는 않는다.

```sh
./scripts/build-flutter-android.sh release play
```

산출물은 `app/build/outputs/bundle/ossRelease/app-oss-release.aab`다.
Play 업로드용 키를 Gradle의 `keystoreFile`, `keystoreAlias`, `keystorePassword`
속성으로 제공해야 업로드 가능한 서명된 AAB가 된다. 키가 없으면 서명 전
AAB가 생성된다. 키와 비밀번호는 로컬에서 보관하고 Git에 넣지 않는다.
기존 Mink Store의 Android Debug 키를 Play 업로드 키로 사용하지 않는다.

`playDistribution` 속성을 지정하지 않은 기존 빌드 명령은 Mink 패키지를
유지한다. Play용 AAB를 Mink Store 업데이트로 등록하지 않는다.

Play Console의 내부 테스트 트랙에 AAB를 업로드하고 Play 앱 서명을
설정한다. Google이 관리하는 앱 서명 키와 로컬 업로드 키는 역할이 다르다.
공개 출시 전에 내부 테스트 설치와 실행을 확인한다.

## 등록정보 초안

- 앱 이름: Tilde
- 기본 언어: 한국어
- 앱 유형: 앱
- 가격: 무료
- 카테고리: 도구
- 개인정보처리방침: https://korellas.github.io/tilde/

짧은 설명:

> SSH 연결과 터미널, 원격 파일 관리를 한곳에서.

자세한 설명:

> Tilde는 Android에서 원격 서버에 접속하고 터미널 작업을 할 수 있는 SSH 클라이언트입니다.
>
> 연결 정보를 저장하고 여러 세션을 오가며 작업하세요. SSH 키 인증을 사용하고,
> SFTP 파일 탐색기로 원격 파일을 확인하고 전송할 수 있습니다.
>
> 설정 화면에는 배너 광고가 표시됩니다.

결제 상품과 실제 구매 테스트를 완료한 뒤에만 아래 문장을 등록정보에 추가한다.

> 선택 사항인 Founders Edition을 한 번 구매하면 설정 화면의 광고를 제거할 수 있습니다.

## 앱 콘텐츠와 심사

광고 포함 여부는 '예'로 신고한다. 데이터 보안 양식은 앱 코드뿐 아니라
Google Mobile Ads SDK의 수집·공유 항목까지 확인해서 작성한다.
SSH 접속용 사용자 서버 인증과 Tilde 자체 계정 로그인을 구분하고,
심사자가 접속 기능을 확인할 수 있도록 앱 액세스 안내를 준비한다.

`FlutterSessionService`는 사용자가 시작한 SSH 연결, 포트 전달, 로컬 터미널
세션을 백그라운드에서 유지하는 `specialUse` 포그라운드 서비스다.
실제 동작을 보여주는 화면 녹화와 서비스 사용 사유를 Play Console에 제출한다.
세션이 없을 때는 서비스를 종료하며, 알림에서 세션으로 복귀하거나 연결을
해제할 수 있다. 선언만으로 심사 승인이 보장되지는 않는다.

콘텐츠 등급, 대상 연령, 데이터 보안과 계정 검증은 실제 앱 동작과 개발자
계정의 요구사항에 맞춰 완료한다. 결제계좌 설정과 상품 활성화 전에는
Founders Edition 구매를 출시 준비 완료로 취급하지 않는다.

공식 안내:

- [앱 만들기 및 설정하기](https://support.google.com/googleplay/android-developer/answer/9859152?hl=ko)
- [앱 서명](https://developer.android.com/studio/publish/app-signing)
- [검토를 위한 앱 준비](https://support.google.com/googleplay/android-developer/answer/9859455?hl=ko)
- [Mobile Ads SDK 데이터 공개](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [포그라운드 서비스 선언](https://support.google.com/googleplay/android-developer/answer/13392821?hl=ko)
