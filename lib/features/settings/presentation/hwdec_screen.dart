/// Hardware-decoder (libmpv `hwdec`) picker — a second-level settings page.
///
/// Mirrors the reference "硬件解码器" screen: a single-select list where an
/// unsupported choice falls back to software decoding. Applies to the
/// media_kit backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/settings_providers.dart';

/// Full-screen single-select list of [HwdecMode] options.
class HwdecScreen extends ConsumerWidget {
  /// Creates a [HwdecScreen].
  const HwdecScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(hwdecModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('硬件解码器')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              '选择不受支持的解码器将回退到软件解码',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          ),
          for (final mode in HwdecMode.values)
            _HwdecTile(
              mode: mode,
              selected: mode == current,
              onTap: () => ref.read(hwdecModeProvider.notifier).set(mode),
            ),
        ],
      ),
    );
  }
}

/// A selectable hwdec option row.
class _HwdecTile extends StatelessWidget {
  const _HwdecTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final HwdecMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          mode.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          mode.description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? color : Colors.grey,
        ),
      ),
    );
  }
}
