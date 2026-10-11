import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/pwa_update.dart';

/// Unobtrusive top bar when a new PWA build is waiting. Web only.
///
/// Checks once per launch. Reload happens only when the user taps Restart.
class PwaUpdateBanner extends StatefulWidget {
  const PwaUpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  State<PwaUpdateBanner> createState() => _PwaUpdateBannerState();
}

class _PwaUpdateBannerState extends State<PwaUpdateBanner> {
  bool _checked = false;
  bool _waiting = false;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnce());
    }
  }

  Future<void> _checkOnce() async {
    if (_checked || !kIsWeb) return;
    _checked = true;
    final waiting = await detectWaitingServiceWorker();
    if (!mounted) return;
    if (waiting) setState(() => _waiting = true);
  }

  Future<void> _restart() async {
    if (_activating) return;
    setState(() => _activating = true);
    await skipWaitingAndReload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_waiting)
          Material(
            color: AppColors.primaryMaroon,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: _activating ? null : _restart,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'A new version is ready. Restart to update.',
                          style: TextStyle(
                            color: AppColors.textOnMaroon,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.refresh,
                        color: AppColors.textOnMaroon,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
