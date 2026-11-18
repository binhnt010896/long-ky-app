import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/providers.dart';
import 'pressable.dart';

/// The VI / EN language toggle — a gold pill with two segments. VI is canonical;
/// flipping to EN never drops diacritics, it just prefers English where present.
///
/// [compact] is the top-bar form: one small pill showing both codes with the
/// active one lit, and a tap anywhere flips it. The full two-segment form
/// lives in the Sảnh's settings and the first-run tour.
class LangToggle extends ConsumerWidget {
  const LangToggle({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    void setLang(Lang next) {
      if (next == lang) return;
      ref.read(langProvider.notifier).state = next;
      ref.read(langStoreProvider).save(next);
    }

    if (compact) {
      return Pressable(
        onTap: () => setLang(lang == Lang.vi ? Lang.en : Lang.vi),
        haptic: true,
        minSize: kMinTapTarget,
        semanticLabel: lang == Lang.vi
            ? 'Ngôn ngữ: Tiếng Việt. Chạm để đổi sang tiếng Anh'
            : 'Language: English. Tap to switch to Vietnamese',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: VSColors.lacquer.withValues(alpha: 0.55),
            borderRadius: VSRadii.chip.toBorderRadius(),
            border: Border.all(color: VSColors.gold.withValues(alpha: 0.35)),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Code(label: 'VI', active: lang == Lang.vi),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                      width: 1, height: 10, color: VSColors.goldBorder),
                ),
                _Code(label: 'EN', active: lang == Lang.en),
              ],
            ),
          ),
        ),
      );
    }

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
            semanticLabel: 'Tiếng Việt',
            active: lang == Lang.vi,
            onTap: () => setLang(Lang.vi),
          ),
          _Segment(
            label: 'EN',
            semanticLabel: 'English',
            active: lang == Lang.en,
            onTap: () => setLang(Lang.en),
          ),
        ],
      ),
    );
  }
}

/// One language code inside the compact pill.
class _Code extends StatelessWidget {
  const _Code({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: VSType.caption.copyWith(
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: VSType.track(0.06, 12),
        color: active ? VSColors.goldBright : VSColors.inkMuted,
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      selected: active,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: VSMotion.control,
        // 44px tall with the caption line: a full-size target per segment.
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: active ? VSColors.goldSheen : null,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: VSType.caption.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: VSType.track(0.08, 12),
              color: active ? VSColors.lacquerRaised : VSColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

extension on Radius {
  BorderRadius toBorderRadius() => BorderRadius.all(this);
}
