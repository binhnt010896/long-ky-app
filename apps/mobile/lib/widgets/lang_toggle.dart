import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/providers.dart';

/// The VI / EN language toggle — a gold pill with two segments. VI is canonical;
/// flipping to EN never drops diacritics, it just prefers English where present.
class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VSColors.lacquer.withValues(alpha: 0.55),
        borderRadius: VSRadii.chip.toBorderRadius(),
        border: Border.all(color: VSColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Segment(
            label: 'VI',
            active: lang == Lang.vi,
            onTap: () => ref.read(langProvider.notifier).state = Lang.vi,
          ),
          _Segment(
            label: 'EN',
            active: lang == Lang.en,
            onTap: () => ref.read(langProvider.notifier).state = Lang.en,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: VSMotion.control,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? VSColors.goldSheen : null,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        child: Text(
          label,
          style: VSType.caption.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: VSType.track(0.08, 12),
            color: active ? VSColors.lacquerRaised : VSColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

extension on Radius {
  BorderRadius toBorderRadius() => BorderRadius.all(this);
}
