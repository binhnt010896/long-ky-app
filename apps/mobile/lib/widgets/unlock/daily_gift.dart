import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../screens/today/reminder_sheet.dart';
import '../../state/providers.dart';
import '../../state/unlock_store.dart';
import '../../theme/content_assets.dart';
import 'mystery_art.dart';
import 'unlock_reveal.dart';

/// What the gift (or a milestone bonus) opened, resolved from the content.
class UnlockedArt {
  const UnlockedArt({
    required this.key,
    required this.title,
    this.subtitle,
    this.imagePath,
    required this.route,
  });

  final String key;
  final LocalizedText title;
  final LocalizedText? subtitle;
  final String? imagePath;
  final String route;

  bool get isPerson => key.startsWith('person:');
  MysteryKind get kind => isPerson ? MysteryKind.avatar : MysteryKind.hero;
}

/// Resolves a [VisitKey] to its name, picture and page.
final unlockedArtProvider = FutureProvider.family<UnlockedArt?, String>((
  ref,
  key,
) async {
  final eras = await ref.watch(erasProvider.future);
  if (key.startsWith('person:')) {
    final id = key.substring('person:'.length);
    for (final era in eras) {
      final c = era.figureById(id);
      if (c == null) continue;
      return UnlockedArt(
        key: key,
        title: c.name,
        subtitle: c.epithet,
        imagePath: c.avatar?.flagship ?? c.avatar?.reduced,
        route: '/era/${era.slug}/figure/$id',
      );
    }
  } else if (key.startsWith('event:')) {
    final id = key.substring('event:'.length);
    for (final era in eras) {
      for (final e in era.events) {
        if (e.id != id) continue;
        final hero = e.hero;
        return UnlockedArt(
          key: key,
          title: e.title,
          subtitle: e.year.display,
          imagePath: hero == null || hero.isPlaceholder
              ? null
              : (hero.reduced ?? hero.flagship),
          route: '/era/${era.slug}/event/$id',
        );
      }
    }
  }
  return null;
});

/// Opens today's gift sheet: the gift to open, or — once opened — what it was.
Future<void> showGiftSheet(BuildContext context, WidgetRef ref) async {
  final before = (await ref.read(unlockProvider.future)).giftClaims;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VSColors.lacquerRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: VSRadii.screen),
    ),
    builder: (_) => const _GiftSheet(),
  );
  // Every 5th gift opened, offer the daily reminder again if it is still off.
  final after = ref.read(unlockProvider).valueOrNull?.giftClaims ?? before;
  if (after > before && after % kGiftReminderEvery == 0 && context.mounted) {
    await maybeOfferReminder(context, ref, again: true);
  }
}

class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet();

  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  UnlockResult? _result;
  bool _opening = false;
  bool _revealDone = false;
  bool _lostChecked = false;
  bool _showLost = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final r = await ref.read(unlockProvider.notifier).openGift();
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final en = ref.watch(langProvider) == Lang.en;
    final lang = en ? Lang.en : Lang.vi;
    final data = ref.watch(unlockProvider).valueOrNull;
    final now = ref.watch(unlockClockProvider)();
    final openedToday = data?.giftOpenedOn(now) ?? false;
    final justOpened = _result != null;
    final key = justOpened
        ? _result!.key
        : (openedToday ? data?.giftKey : null);
    final allOpen = (justOpened || openedToday) && key == null;
    final art = key == null
        ? null
        : ref.watch(unlockedArtProvider(key)).valueOrNull;
    // Counted here from the same data, not read from unlockProgressProvider:
    // that one is derived, and reading it first from inside the sheet's build
    // would notify the cards underneath mid-build.
    final hiddenKeys = ref.watch(hiddenArtProvider);
    final progress = UnlockProgress(
        data == null ? 0 : hiddenKeys.where(data.unlocked.contains).length,
        hiddenKeys.length);
    final streak = data?.streak;
    // A lost streak is told once: remember it for this sheet, then clear it.
    if (!_lostChecked && data != null && (justOpened || openedToday)) {
      _lostChecked = true;
      _showLost = data.lostStreak > 0;
      if (_showLost) {
        Future<void>.microtask(
          () => ref.read(unlockProvider.notifier).dismissLostStreak(),
        );
      }
    }

    Widget body;
    if (!justOpened && !openedToday) {
      body = _Closed(en: en, busy: _opening, onOpen: _open);
    } else if (allOpen) {
      body = Column(
        children: <Widget>[
          Text(
            en ? 'Every picture is open' : 'Bạn đã mở hết mọi bức ảnh',
            textAlign: TextAlign.center,
            style: VSType.headline,
          ),
          const SizedBox(height: VSSpacing.sm),
          Text(
            en
                ? 'Open "Hôm nay" each day to keep your streak.'
                : 'Mở «Hôm nay» mỗi ngày để giữ chuỗi.',
            textAlign: TextAlign.center,
            style: VSType.bodySmall,
          ),
        ],
      );
    } else if (art == null) {
      body = const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: VSColors.gold)),
      );
    } else {
      final width = art.isPerson ? 200.0 : 300.0;
      final height = art.isPerson ? 200.0 : 200.0;
      final image = art.imagePath == null
          ? const ColoredBox(color: VSColors.lacquerRaised)
          : Image(
              image: contentImageProvider(art.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: VSColors.lacquerRaised),
            );
      final milestone = _result?.streak?.milestone;
      body = Column(
        children: <Widget>[
          SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: VSRadii.cardAll,
              child: justOpened && !_revealDone
                  ? UnlockReveal(
                      kind: art.kind,
                      revealed: image,
                      milestone: milestone != null,
                      caption: '+1 · ${progress.opened}/${progress.total}',
                      onDone: () {
                        if (mounted) setState(() => _revealDone = true);
                      },
                    )
                  : image,
            ),
          ),
          const SizedBox(height: VSSpacing.lg),
          Text(
            art.title.resolve(lang),
            textAlign: TextAlign.center,
            style: VSType.headline,
          ),
          if (art.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                art.subtitle!.resolve(lang),
                textAlign: TextAlign.center,
                style: VSType.caption.copyWith(color: VSColors.gold),
              ),
            ),
          if (milestone != null)
            Padding(
              padding: const EdgeInsets.only(top: VSSpacing.md),
              child: Text(
                en
                    ? '$milestone-day streak! One more unlock'
                    : 'Chuỗi $milestone ngày! Thêm một lượt mở khóa',
                key: const ValueKey<String>('gift-milestone'),
                textAlign: TextAlign.center,
                style: VSType.label.copyWith(color: VSColors.goldBright),
              ),
            ),
          if (_result?.bonusKey != null)
            _BonusLine(keyName: _result!.bonusKey!, lang: lang),
          const SizedBox(height: VSSpacing.lg),
          GestureDetector(
            key: const ValueKey<String>('gift-view-page'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(art.route);
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VSColors.gold.withValues(alpha: 0.14),
                borderRadius: VSRadii.pillAll,
                border: Border.all(color: VSColors.gold.withValues(alpha: 0.6)),
              ),
              child: Text(
                en ? 'View page ›' : 'Xem trang ›',
                style: VSType.label.copyWith(color: VSColors.inkPrimary),
              ),
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VSSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(en ? "TODAY'S GIFT" : 'QUÀ HÔM NAY', style: VSType.overline),
            const SizedBox(height: VSSpacing.lg),
            body,
            if (streak != null && (justOpened || openedToday)) ...<Widget>[
              const SizedBox(height: VSSpacing.lg),
              Text(
                [
                  en
                      ? '🔥 ${streak.current}-day streak'
                      : '🔥 Chuỗi ${streak.current} ngày',
                  if (streak.freezes > 0)
                    en
                        ? '${streak.freezes} streak freeze'
                        : '${streak.freezes} lượt giữ chuỗi',
                  en
                      ? 'Opened ${progress.opened}/${progress.total}'
                      : 'Đã mở ${progress.opened}/${progress.total}',
                ].join(' · '),
                key: const ValueKey<String>('gift-streak'),
                textAlign: TextAlign.center,
                style: VSType.caption,
              ),
              if (_showLost) _LostStreakNote(en: en),
            ],
          ],
        ),
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed({required this.en, required this.busy, required this.onOpen});

  final bool en;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(
          width: 180,
          height: 180,
          child: ClipRRect(
            borderRadius: VSRadii.cardAll,
            child: MysteryArt(kind: MysteryKind.avatar),
          ),
        ),
        const SizedBox(height: VSSpacing.lg),
        Text(
          en ? 'A picture is waiting for you' : 'Một bức ảnh đang chờ bạn',
          textAlign: TextAlign.center,
          style: VSType.headline,
        ),
        const SizedBox(height: VSSpacing.lg),
        GestureDetector(
          key: const ValueKey<String>('gift-open'),
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : onOpen,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: VSColors.goldSheen,
              borderRadius: VSRadii.pillAll,
            ),
            child: Text(
              en ? 'Open the gift' : 'Mở quà',
              style: VSType.label.copyWith(color: VSColors.lacquerVoid),
            ),
          ),
        ),
      ],
    );
  }
}

class _BonusLine extends ConsumerWidget {
  const _BonusLine({required this.keyName, required this.lang});

  final String keyName;
  final Lang lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(unlockedArtProvider(keyName)).valueOrNull;
    if (art == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: VSSpacing.xs),
      child: Text(
        '${lang == Lang.en ? 'Bonus' : 'Thưởng thêm'}: ${art.title.resolve(lang)}',
        key: const ValueKey<String>('gift-bonus'),
        textAlign: TextAlign.center,
        style: VSType.caption.copyWith(color: VSColors.goldBright),
      ),
    );
  }
}

class _LostStreakNote extends StatelessWidget {
  const _LostStreakNote({required this.en});
  final bool en;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: VSSpacing.sm),
      child: Text(
        en
            ? 'Your streak started over — today is day 1'
            : 'Chuỗi đã bắt đầu lại — hôm nay là ngày 1',
        key: const ValueKey<String>('streak-lost-note'),
        textAlign: TextAlign.center,
        style: VSType.caption,
      ),
    );
  }
}

/// The glowing "Quà hôm nay" chip on Home, next to the seal. Glows until
/// today's gift is opened; after that it shows the streak. Nothing when no art
/// is hidden.
class GiftChip extends ConsumerStatefulWidget {
  const GiftChip({super.key});

  @override
  ConsumerState<GiftChip> createState() => _GiftChipState();
}

class _GiftChipState extends ConsumerState<GiftChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A few pulses to catch the eye, then it rests: a chip that never stops
    // glowing would read as a nag.
    if (MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
    } else if (!_glow.isAnimating && _glow.value == 0) {
      _glow.repeat(reverse: true, count: 6);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(unlockProgressProvider);
    final data = ref.watch(unlockProvider).valueOrNull;
    if (progress.total == 0 || data == null) return const SizedBox.shrink();
    final en = ref.watch(langProvider) == Lang.en;
    final opened = data.giftOpenedOn(ref.watch(unlockClockProvider)());
    final label = opened
        ? (en
              ? '🔥 ${data.streak.current}-day streak'
              : '🔥 Chuỗi ${data.streak.current} ngày')
        : (en ? '🎁 Today\'s gift' : '🎁 Quà hôm nay');
    return GestureDetector(
      key: const ValueKey<String>('home-gift-chip'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showGiftSheet(context, ref),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: VSColors.gold.withValues(alpha: opened ? 0.06 : 0.14),
            borderRadius: VSRadii.pillAll,
            border: Border.all(
              color: VSColors.goldBright.withValues(
                alpha: opened ? 0.3 : 0.4 + 0.5 * _glow.value,
              ),
            ),
            boxShadow: opened
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: VSColors.goldGlow.withValues(
                        alpha: 0.15 + 0.3 * _glow.value,
                      ),
                      blurRadius: 14,
                    ),
                  ],
          ),
          child: child,
        ),
        child: Text(
          label,
          style: VSType.caption.copyWith(color: VSColors.goldBright),
        ),
      ),
    );
  }
}

/// The gift as a card at the top of the Sảnh, with the counts, tapping to open
/// the gift and expanding to the per-period tally.
class GiftCard extends ConsumerStatefulWidget {
  const GiftCard({super.key});

  @override
  ConsumerState<GiftCard> createState() => _GiftCardState();
}

class _GiftCardState extends ConsumerState<GiftCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(unlockProgressProvider);
    final data = ref.watch(unlockProvider).valueOrNull;
    if (progress.total == 0 || data == null) return const SizedBox.shrink();
    final en = ref.watch(langProvider) == Lang.en;
    final lang = en ? Lang.en : Lang.vi;
    final opened = data.giftOpenedOn(ref.watch(unlockClockProvider)());
    final streak = data.streak;
    final summary = [
      en
          ? 'Opened ${progress.opened}/${progress.total}'
          : 'Đã mở ${progress.opened}/${progress.total}',
      if (streak.current > 0)
        en
            ? '🔥 ${streak.current}-day streak'
            : '🔥 Chuỗi ${streak.current} ngày',
      if (streak.freezes > 0)
        en ? '${streak.freezes} freeze' : '${streak.freezes} lượt giữ chuỗi',
    ].join(' · ');

    final eras = ref.watch(erasProvider).valueOrNull ?? const <Era>[];
    final periods =
        ref.watch(periodsProvider).valueOrNull ?? PeriodRegistry.empty;
    final hidden = ref.watch(hiddenArtProvider);
    final rows = <(String, int, int)>[];
    for (final p in periods.ordered) {
      var o = 0, t = 0;
      for (final e in eras.where((e) => e.period == p.id)) {
        final pr = eraUnlockProgress(e, hidden, data.unlocked);
        o += pr.opened;
        t += pr.total;
      }
      if (t > 0) rows.add((p.title.resolve(lang), o, t));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: VSSpacing.lg),
      child: Container(
        key: const ValueKey<String>('sanh-gift-card'),
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 12),
        decoration: BoxDecoration(
          color: VSColors.lacquerRaised.withValues(alpha: 0.6),
          borderRadius: VSRadii.cardAll,
          border: Border.all(
            color: opened ? VSColors.goldBorder : VSColors.goldBright,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showGiftSheet(context, ref),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          (en ? "TODAY'S GIFT" : 'QUÀ HÔM NAY'),
                          style: VSType.overline.copyWith(
                            color: VSColors.goldBright,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opened
                              ? (en ? 'Opened today ✓' : 'Đã mở hôm nay ✓')
                              : (en
                                    ? 'A picture is waiting'
                                    : 'Một bức ảnh đang chờ'),
                          style: VSType.cardTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          key: const ValueKey<String>('gift-card-summary'),
                          style: VSType.caption.copyWith(
                            color: VSColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.card_giftcard,
                    color: VSColors.goldBright,
                    size: 26,
                  ),
                ],
              ),
            ),
            GestureDetector(
              key: const ValueKey<String>('gift-card-expand'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: VSSpacing.sm),
                child: Text(
                  _expanded
                      ? (en ? 'Hide by dynasty ▴' : 'Ẩn theo triều đại ▴')
                      : (en ? 'By dynasty ▾' : 'Theo triều đại ▾'),
                  style: VSType.caption,
                ),
              ),
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: VSSpacing.xs),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(r.$1, style: VSType.bodySmall)),
                      Text(
                        '${r.$2}/${r.$3}',
                        style: VSType.caption.copyWith(
                          color: VSColors.goldBright,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: VSSpacing.sm),
                child: Text(
                  en
                      ? 'Progress is kept on this phone only.'
                      : 'Tiến trình chỉ được lưu trên máy này.',
                  style: VSType.caption.copyWith(color: VSColors.inkFaint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
