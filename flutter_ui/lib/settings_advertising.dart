/* Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'l10n/strings.dart';

class SettingsAdvertising extends StatefulWidget {
  const SettingsAdvertising({super.key});

  @override
  State<SettingsAdvertising> createState() => _SettingsAdvertisingState();
}

class _SettingsAdvertisingState extends State<SettingsAdvertising>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  bool _loaded = false;
  bool _privacyRequired = false;
  bool _privacyBusy = false;
  bool _visible = false;
  bool _backgrounded = false;
  int _width = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final width = (media.size.width - media.padding.horizontal - 24)
        .clamp(0, 640)
        .floor();
    final visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (width == _width && visible == _visible) return;
    _width = width;
    _visible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  bool get _active =>
      mounted &&
      _visible &&
      !const {
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      }.contains(WidgetsBinding.instance.lifecycleState);

  bool _current(int generation) => _active && generation == _generation;

  void _releaseAd() {
    final banner = _banner;
    _banner = null;
    _loaded = false;
    if (banner != null) unawaited(banner.dispose());
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    setState(_releaseAd);
    if (!_active) return;
    final updated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(true),
      (_) => updated.complete(false),
    );
    try {
      final success = await updated.future;
      if (!_current(generation)) return;
      if (success) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      if (_current(generation)) await _loadAllowedAd(generation);
    } catch (_) {
      // Advertising failures must not prevent settings or SSH use.
    }
  }

  Future<void> _loadAllowedAd(int generation) async {
    final consent = ConsentInformation.instance;
    final privacy = await consent.getPrivacyOptionsRequirementStatus();
    if (!_current(generation)) return;
    setState(() {
      _privacyRequired = privacy == PrivacyOptionsRequirementStatus.required;
    });
    if (!await consent.canRequestAds() ||
        !_current(generation) ||
        _width < 320) {
      return;
    }
    await MobileAds.instance.initialize();
    if (!_current(generation)) return;
    await MobileAds.instance.setAppMuted(true);
    // Keep the compact banner instead of the SDK's larger banner format.
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      _width,
    );
    if (size == null || !_current(generation)) return;
    final banner = BannerAd(
      adUnitId: !kReleaseMode || const bool.fromEnvironment('TILDE_TEST_ADS')
          ? 'ca-app-pub-3940256099942544/9214589741'
          : 'ca-app-pub-2419651602326063/6058345067',
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_current(generation) && identical(ad, _banner)) {
            setState(() => _loaded = true);
          } else {
            unawaited(ad.dispose());
          }
        },
        onAdFailedToLoad: (ad, _) {
          if (mounted && identical(ad, _banner)) {
            setState(_releaseAd);
          } else {
            unawaited(ad.dispose());
          }
        },
      ),
    );
    _banner = banner;
    try {
      await banner.load();
    } catch (_) {
      if (mounted && identical(_banner, banner)) setState(_releaseAd);
    }
  }

  Future<void> _showPrivacyOptions() async {
    final contextStrings = context.l10n;
    final generation = ++_generation;
    setState(() {
      _privacyBusy = true;
      _releaseAd();
    });
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null && _current(generation)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                contextStrings.couldNotOpenAdPrivacySettingsTryAgain,
              ),
            ),
          );
        }
      });
      if (_current(generation)) await _loadAllowedAd(generation);
    } catch (_) {
      if (mounted && _current(generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(contextStrings.couldNotOpenAdPrivacySettingsTryAgain),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _privacyBusy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    if (state == AppLifecycleState.resumed) {
      if (!_backgrounded) return;
      _backgrounded = false;
    } else {
      _backgrounded = true;
    }
    unawaited(_prepare());
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _releaseAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || (!_loaded && !_privacyRequired)) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loaded && _banner != null)
              Semantics(
                label: context.l10n.ad,
                child: SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
              ),
            if (_privacyRequired) ...[
              if (_loaded) const SizedBox(height: 16),
              TextButton(
                onPressed: _privacyBusy ? null : _showPrivacyOptions,
                child: Text(context.l10n.adPrivacySettings),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
