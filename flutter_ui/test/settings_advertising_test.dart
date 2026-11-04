/* Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0 */
import 'dart:async';

import 'package:android_shell_ui/settings_advertising.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late bool allowed;
  late bool updateFails;
  late bool privacyRequired;
  Completer<void>? consentUpdate;

  setUp(() {
    calls = [];
    allowed = false;
    updateFails = false;
    privacyRequired = false;
    consentUpdate = null;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    messenger.setMockMethodCallHandler(ump, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'ConsentInformation#requestConsentInfoUpdate':
          await consentUpdate?.future;
          if (updateFails) {
            throw PlatformException(code: '1', message: 'offline');
          }
          return null;
        case 'ConsentInformation#canRequestAds':
          return allowed;
        case 'ConsentInformation#getPrivacyOptionsRequirementStatus':
          return privacyRequired ? 1 : 0;
        case 'UserMessagingPlatform#showPrivacyOptionsForm':
          allowed = false;
          return null;
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return null;
      }
      throw StateError('Unexpected UMP call: ${call.method}');
    });
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'MobileAds#initialize':
          return InitializationStatus({});
        case 'AdSize#getAnchoredAdaptiveBannerAdSize':
          return 50;
        case 'loadBannerAd':
        case 'disposeAd':
        case 'MobileAds#setAppMuted':
        case '_init':
          return null;
      }
      throw StateError('Unexpected ads call: ${call.method}');
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(ump, null);
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ko'),
        home: Scaffold(bottomNavigationBar: SettingsAdvertising()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Iterable<MethodCall> requests() =>
      calls.where((c) => c.method == 'loadBannerAd');

  testWidgets('does not initialize or request ads without consent', (
    tester,
  ) async {
    await open(tester);
    expect(requests(), isEmpty);
    expect(calls.where((c) => c.method == 'MobileAds#initialize'), isEmpty);
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline consent failure leaves settings usable', (tester) async {
    updateFails = true;
    await open(tester);
    expect(requests(), isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses test ads after consent and releases them on exit', (
    tester,
  ) async {
    allowed = true;
    await open(tester);
    expect(requests(), hasLength(1));
    final request = requests().single.arguments as Map;
    expect(request['adUnitId'], 'ca-app-pub-3940256099942544/9214589741');
    final adRequest = request['request'] as AdRequest;
    expect(adRequest.keywords, isNull);
    expect(adRequest.contentUrl, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  testWidgets('does not request ads after exiting during consent', (
    tester,
  ) async {
    allowed = true;
    consentUpdate = Completer<void>();
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    consentUpdate!.complete();
    await tester.pumpAndSettle();
    expect(requests(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded compact banner fits a small screen with large text', (
    tester,
  ) async {
    allowed = true;
    privacyRequired = true;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(bottomNavigationBar: SettingsAdvertising()),
      ),
    );
    await tester.pumpAndSettle();
    final ad =
        instanceManager.adFor(requests().single.arguments['adId'] as int)
            as BannerAd;
    ad.listener.onAdLoaded!(ad);
    await tester.pumpAndSettle();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getSize(find.byType(AdWidget)), const Size(336, 50));
    expect(find.text('광고 개인정보 설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed banner is released without retrying or reserving space', (
    tester,
  ) async {
    allowed = true;
    await open(tester);
    final ad =
        instanceManager.adFor(requests().single.arguments['adId'] as int)
            as BannerAd;
    ad.listener.onAdFailedToLoad!(ad, LoadAdError(3, 'admob', 'no fill', null));
    await tester.pumpAndSettle();
    expect(requests(), hasLength(1));
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen resize replaces the banner with the new width', (
    tester,
  ) async {
    allowed = true;
    await open(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    expect(requests(), hasLength(2));
    expect((requests().last.arguments['size'] as AdSize).width, 366);
  });

  testWidgets('privacy choice removes the old ad and rechecks permission', (
    tester,
  ) async {
    allowed = true;
    privacyRequired = true;
    await open(tester);
    expect(requests(), hasLength(1));
    await tester.tap(find.text('광고 개인정보 설정'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    expect(requests(), hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
  });

  testWidgets('covering settings releases ads until returning', (tester) async {
    allowed = true;
    await open(tester);
    final context = tester.element(find.byType(SettingsAdvertising));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('도움말')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(requests(), hasLength(2));
  });

  testWidgets('backgrounding releases ads and resumes only when visible', (
    tester,
  ) async {
    allowed = true;
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests(), hasLength(2));
  });
}
