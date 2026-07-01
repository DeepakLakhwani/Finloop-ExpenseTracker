import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../theme/app_colors.dart';

class BannerAdWidget extends StatefulWidget {
  final ValueChanged<bool>? onAdLoaded;
  const BannerAdWidget({super.key, this.onAdLoaded});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isError = false;
  AdSize? _adaptiveSize;

  void _notifyParent(bool isLoaded) {
    if (widget.onAdLoaded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onAdLoaded!(isLoaded);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only load the ad if ads are enabled and we haven't loaded one already
    if (AdService.adsEnabled) {
      if (_bannerAd == null) {
        _loadAdaptiveBanner();
      } else {
        _notifyParent(_isLoaded && !_isError);
      }
    } else {
      _notifyParent(false);
    }
  }

  Future<void> _loadAdaptiveBanner() async {
    // 1. Get the screen width dynamically to calculate adaptive size
    final double screenWidth = MediaQuery.of(context).size.width;

    // Subtract some horizontal padding to match app layout
    final int targetWidth = (screenWidth - 32).toInt().clamp(0, 1000);

    // 2. Fetch the anchored adaptive banner size for the current orientation
    final Orientation orientation = MediaQuery.of(context).orientation;
    final AdSize? size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      orientation,
      targetWidth,
    );

    if (size == null) {
      debugPrint(
        "[BannerAdWidget] Failed to calculate anchored adaptive banner size.",
      );
      setState(() => _isError = true);
      _notifyParent(false);
      return;
    }

    if (!mounted) return;

    setState(() {
      _adaptiveSize = size;
    });

    // 3. Load the Banner Ad
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          debugPrint(
            "[BannerAdWidget] Adaptive Banner Ad loaded successfully.",
          );
          setState(() {
            _isLoaded = true;
            _isError = false;
          });
          _notifyParent(true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("[BannerAdWidget] Failed to load banner ad: $error");
          ad.dispose();
          if (mounted) {
            setState(() {
              _isError = true;
              _isLoaded = false;
            });
            _notifyParent(false);
          }
        },
      ),
    );

    await _bannerAd!.load();
  }

  @override
  void dispose() {
    // Crucial: dispose of the ad object to prevent native memory leaks
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If ads are disabled globally, or there's an error loading, shrink to nothing
    if (!AdService.adsEnabled || _isError) {
      return const SizedBox.shrink();
    }

    final double bannerHeight = _adaptiveSize?.height.toDouble() ?? 50.0;
    final double containerWidth =
        _adaptiveSize?.width.toDouble() ??
        MediaQuery.of(context).size.width - 32;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: containerWidth,
        height: bannerHeight,
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Loading State Placeholder
            if (!_isLoaded)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading sponsored content...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            // 2. Banner Ad View
            if (_isLoaded && _bannerAd != null) AdWidget(ad: _bannerAd!),
          ],
        ),
      ),
    );
  }
}
