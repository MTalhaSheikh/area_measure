import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads a rewarded (full-screen video) ad ahead of time so it's ready
/// instantly when the user hits the free-point limit, and re-loads a
/// fresh one after each watch since a [RewardedAd] instance is single-use.
///
/// IMPORTANT: the ad unit IDs below are Google's official *test* IDs —
/// safe to ship, but they only ever show sample/placeholder ads and earn
/// no revenue. Replace with your real AdMob rewarded ad unit IDs before a
/// production release.
class RewardedAdService {
  RewardedAdService() {
    _loadAd();
  }

  // TODO: replace with your real AdMob rewarded ad unit IDs before release.
  static const String _androidAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  static String get _adUnitId =>
      Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isReady => _rewardedAd != null;

  void _loadAd() {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    try {
      RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            // Common causes: no internet, no fill yet for this region, or
            // (in debug builds) the ad unit not active yet. Fails silently
            // — callers check [isReady] before offering to show one.
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      // E.g. Mobile Ads SDK failed to initialize at app startup (see
      // main.dart) — don't let that surface as a crash here either.
      _isLoading = false;
    }
  }

  /// Shows the preloaded ad if one is ready. [onUserEarnedReward] fires
  /// only if the user watches to completion — closing early earns
  /// nothing, which is exactly the gate this is used for. Returns false
  /// immediately (without showing anything) if no ad is ready yet.
  Future<bool> show({required void Function() onUserEarnedReward}) async {
    final RewardedAd? ad = _rewardedAd;
    if (ad == null) return false;

    _rewardedAd = null; // this instance is single-use
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd(); // preload the next one immediately
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadAd();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) => onUserEarnedReward(),
    );
    return true;
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}
