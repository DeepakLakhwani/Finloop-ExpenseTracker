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
  bool _isAdLoading = false;

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

    // Only load the ad if ads are enabled, we haven't loaded one already, and we aren't currently loading
    if (AdService.adsEnabled) {
      if (_bannerAd == null && !_isAdLoading) {
        _loadAdaptiveBanner();
      } else {
        _notifyParent(_isLoaded && !_isError);
      }
    } else {
      _notifyParent(false);
    }
  }

  Future<void> _loadAdaptiveBanner() async {
    if (_isAdLoading) return;

    // 1. Get the screen width dynamically to calculate adaptive size
    final double screenWidth = MediaQuery.of(context).size.width;
    final Orientation orientation = MediaQuery.of(context).orientation;

    // Subtract some horizontal padding to match app layout
    final int targetWidth = (screenWidth - 32).toInt().clamp(0, 1000);

    setState(() {
      _isAdLoading = true;
    });

    // 2. Fetch standard adaptive size from the SDK dynamically (ensuring standard height, e.g. 50px)
    // ignore: deprecated_member_use
    final AdSize? size = await AdSize.getAnchoredAdaptiveBannerAdSize(orientation, targetWidth);

    if (!mounted) {
      _isAdLoading = false;
      return;
    }

    final resolvedSize = size ?? AdSize.banner;

    setState(() {
      _adaptiveSize = resolvedSize;
    });

    // 3. Load the Banner Ad
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: resolvedSize,
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
            _isAdLoading = false;
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
              _isAdLoading = false;
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

    final double bannerHeight = _isLoaded
        ? (_adaptiveSize?.height.toDouble() ?? 50.0)
        : 50.0;
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
                  SizedBox(
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
