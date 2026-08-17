import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/theme.dart';

/// Google Mobile Ads with a hard test/prod split and no child-directed
/// targeting. UMP is requested so EEA/UK users can consent later.
abstract final class AdsService {
  static bool _started = false;
  static bool _adsReady = false;

  static bool get adsReady => _adsReady;

  static Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      await _requestConsentThenInit();
    } catch (error, stack) {
      debugPrint('[ads] init skipped: $error\n$stack');
    }
  }

  static Future<void> _requestConsentThenInit() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
    );
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadConsentForm();
          }
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        debugPrint('[ads] UMP update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
    await _initSdk();
  }

  static Future<void> _loadConsentForm() async {
    final done = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        debugPrint('[ads] consent form: ${error.message}');
      }
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
  }

  static Future<void> _initSdk() async {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: AppConfig.adMobTestDeviceIds,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
        maxAdContentRating: MaxAdContentRating.pg,
      ),
    );
    await MobileAds.instance.initialize();
    _adsReady = true;
  }
}

class AdaptiveAdBanner extends StatefulWidget {
  const AdaptiveAdBanner({super.key});

  @override
  State<AdaptiveAdBanner> createState() => _AdaptiveAdBannerState();
}

class _AdaptiveAdBannerState extends State<AdaptiveAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AdsService.start();
    if (!mounted || !AdsService.adsReady) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final ad = BannerAd(
      size: AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
          AdSize.banner,
      adUnitId: AppConfig.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[ads] banner failed: $error');
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
      request: const AdRequest(),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_loaded && ad != null) {
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        AppConfig.useTestAds
            ? 'TEST ADS · not directed at children'
            : 'AD · not directed at children',
        style: const TextStyle(
          color: Color(0xFF9AA7B3),
          fontSize: 9,
          letterSpacing: .8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
