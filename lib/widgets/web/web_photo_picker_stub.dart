import 'package:flutter/material.dart';

import '../../core/services/profile_photo_service.dart';

/// Non-web: not used.
class WebNativePhotoPicker extends StatelessWidget {
  const WebNativePhotoPicker({
    super.key,
    required this.onPicked,
    this.busy = false,
    this.label = 'Choose photo',
  });

  final void Function(ProfilePhotoPick pick) onPicked;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
