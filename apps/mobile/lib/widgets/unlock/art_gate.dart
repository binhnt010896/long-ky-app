import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/unlock_store.dart';
import 'mystery_art.dart';
import 'unlock_quiz_sheet.dart';
import 'unlock_reveal.dart';

/// Stands in front of one picture. While the art for [visitKey] is hidden it
/// shows the mystery placeholder (with a "Mở khóa" affordance when
/// [interactive]); the moment it is unlocked it plays the reveal in place,
/// then shows [child] — the real image, with no frame.
///
/// For anything not in the unlock game (a photographed era, a standalone page)
/// it is just [child].
class ArtGate extends ConsumerStatefulWidget {
  const ArtGate({
    required this.visitKey,
    required this.kind,
    required this.child,
    this.interactive = true,
    super.key,
  });

  /// A [VisitKey.person] or [VisitKey.event].
  final String visitKey;
  final MysteryKind kind;
  final Widget child;

  /// A tap opens the unlock quiz. False for small tiles, where the tap belongs
  /// to the tile itself (it opens the page, which offers the quiz), and for a
  /// picture under other layers, which places [UnlockAffordance] above them.
  final bool interactive;

  @override
  ConsumerState<ArtGate> createState() => _ArtGateState();
}

class _ArtGateState extends ConsumerState<ArtGate> {
  bool _revealing = false;
  String? _caption;
  bool _milestone = false;

  String _captionFor(UnlockResult? r) {
    final en = ref.read(langProvider) == Lang.en;
    final p = ref.read(unlockProgressProvider);
    final parts = <String>['+1 · ${p.opened}/${p.total}'];
    final adv = r?.streak;
    if (adv != null && adv.state.current > 0) {
      parts.add(en
          ? '🔥 ${adv.state.current}-day streak'
          : '🔥 Chuỗi ${adv.state.current} ngày');
    }
    if (adv?.milestone != null) {
      parts.add(en ? 'One more unlock!' : 'Thêm một lượt mở khóa!');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(artHiddenProvider(widget.visitKey));
    ref.listen<bool>(artHiddenProvider(widget.visitKey), (prev, next) {
      if (prev == true && next == false) {
        final r = ref.read(lastRewardProvider);
        setState(() {
          _revealing = true;
          _caption = _captionFor(r);
          _milestone = r?.streak?.milestone != null;
        });
      }
    });

    if (_revealing) {
      return UnlockReveal(
        kind: widget.kind,
        revealed: widget.child,
        caption: _caption,
        milestone: _milestone,
        onDone: () {
          if (mounted) setState(() => _revealing = false);
        },
      );
    }
    if (!hidden) return widget.child;

    final art = MysteryArt(kind: widget.kind);
    if (!widget.interactive) return art;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        art,
        UnlockAffordance(visitKey: widget.visitKey),
      ],
    );
  }
}

/// The "Mở khóa" pill laid over a hidden picture, and the tap that opens the
/// question. Fills its parent; nothing once the art is open or today's unlocks
/// are used up. A screen whose picture sits under other layers (the event hero)
/// places this above them.
class UnlockAffordance extends ConsumerWidget {
  const UnlockAffordance({
    required this.visitKey,
    this.alignment = Alignment.bottomCenter,
    super.key,
  });

  final String visitKey;
  final Alignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(artHiddenProvider(visitKey))) return const SizedBox.shrink();
    final en = ref.watch(langProvider) == Lang.en;
    if (ref.watch(quizCapReachedProvider)) return const SizedBox.shrink();
    return GestureDetector(
      key: const ValueKey<String>('art-gate-tap'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showUnlockQuizSheet(context, ref, visitKey),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(VSSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xCC060D0C),
              borderRadius: VSRadii.pillAll,
              border: Border.all(color: VSColors.goldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_open_rounded,
                    size: 14, color: VSColors.goldBright),
                const SizedBox(width: 6),
                Text(en ? 'Unlock' : 'Mở khóa',
                    style:
                        VSType.caption.copyWith(color: VSColors.goldBright)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under a hidden picture: how to open it, or that today's unlocks
/// are used up. Nothing at all once the art is open.
class UnlockPrompt extends ConsumerWidget {
  const UnlockPrompt({required this.visitKey, super.key});

  final String visitKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(artHiddenProvider(visitKey))) return const SizedBox.shrink();
    final en = ref.watch(langProvider) == Lang.en;
    final capped = ref.watch(quizCapReachedProvider);
    final streak = ref.watch(unlockProvider).valueOrNull?.streak.current ?? 0;
    final text = capped
        ? (en
            ? 'No unlocks left today — come back tomorrow'
            : 'Hết lượt mở khóa hôm nay — mai quay lại nhé')
        : (en
            ? 'Answer one question to unlock the picture ›'
            : 'Trả lời một câu để mở khóa ảnh ›');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VSSpacing.sm),
      child: GestureDetector(
        key: const ValueKey<String>('unlock-prompt'),
        behavior: HitTestBehavior.opaque,
        onTap: capped ? null : () => showUnlockQuizSheet(context, ref, visitKey),
        child: Column(
          children: <Widget>[
            Text(
              text,
              textAlign: TextAlign.center,
              style: VSType.caption.copyWith(color: VSColors.goldBright),
            ),
            if (capped && streak > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  en ? '🔥 $streak-day streak' : '🔥 Chuỗi $streak ngày',
                  style: VSType.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
