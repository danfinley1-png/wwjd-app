import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/tts_providers.dart';

/// Listen / stop control for reading text aloud.
class PrayerReadAloudButton extends ConsumerStatefulWidget {
  const PrayerReadAloudButton({
    super.key,
    required this.text,
    this.compact = false,
  });

  final String text;
  final bool compact;

  @override
  ConsumerState<PrayerReadAloudButton> createState() =>
      _PrayerReadAloudButtonState();
}

class _PrayerReadAloudButtonState extends ConsumerState<PrayerReadAloudButton> {
  bool _speaking = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initReadAloud());
  }

  Future<void> _initReadAloud() async {
    final readAloud = ref.read(ttsReadAloudProvider);
    readAloud.onSpeakingChanged = (speaking) {
      if (mounted) setState(() => _speaking = speaking);
    };
    if (!readAloud.isReady) {
      await readAloud.initialize();
    }
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _toggle() async {
    if (!_initialized) return;
    final readAloud = ref.read(ttsReadAloudProvider);
    if (_speaking) {
      await readAloud.stop();
      return;
    }

    try {
      await readAloud.speak(widget.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to read aloud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: _speaking ? 'Stop' : 'Listen',
        icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up),
        onPressed: _initialized ? _toggle : null,
      );
    }

    return OutlinedButton.icon(
      onPressed: _initialized ? _toggle : null,
      icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
      label: Text(_speaking ? 'Stop' : 'Listen'),
    );
  }
}
