import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/content_sync.dart';
import '../../state/providers.dart';
import '../../state/tip_store.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/flag_mark.dart';
import '../../widgets/lang_toggle.dart';
import '../../widgets/seal_button.dart';
import '../home/widgets/particle_field.dart';

/// One entry in the Sảnh's directory. New features (e.g. Câu đố) are one more
/// line in [_items].
class _SanhItem {
  const _SanhItem({
    required this.icon,
    required this.titleVi,
    required this.titleEn,
    required this.subtitleVi,
    required this.subtitleEn,
    required this.route,
  });

  final IconData icon;
  final String titleVi;
  final String titleEn;
  final String subtitleVi;
  final String subtitleEn;
  final String route;
}

const List<_SanhItem> _items = <_SanhItem>[
  _SanhItem(
    icon: Icons.timeline_rounded,
    titleVi: 'Niên biểu',
    titleEn: 'Timeline',
    subtitleVi: 'Mọi kỷ nguyên trên một dòng thời gian',
    subtitleEn: 'Every era on one line',
    route: '/timeline',
  ),
  _SanhItem(
    icon: Icons.map_outlined,
    titleVi: 'Bản đồ lãnh thổ',
    titleEn: 'Territory atlas',
    subtitleVi: 'Cương vực qua các thời kỳ',
    subtitleEn: 'The borders through history',
    route: '/map',
  ),
  _SanhItem(
    icon: Icons.auto_stories_outlined,
    titleVi: 'Về Long Ký',
    titleEn: 'About Long Ký',
    subtitleVi: 'Nguồn sử liệu, hình ảnh, phiên bản',
    subtitleEn: 'Sources, images, version',
    route: '/sanh/gioi-thieu',
  ),
];

/// The Sảnh — the hall behind the Long Ký seal: a lacquer panel holding the
/// features that live outside the eras (Chào cờ first), the directory, and the
/// "một chén trà" tip.
class SanhScreen extends ConsumerStatefulWidget {
  const SanhScreen({super.key});

  @override
  ConsumerState<SanhScreen> createState() => _SanhScreenState();
}

class _SanhScreenState extends ConsumerState<SanhScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  StreamSubscription<TipOutcome>? _tipSub;

  @override
  void initState() {
    super.initState();
    _tipSub = ref.read(tipStoreProvider)?.outcomes.listen(_onTipOutcome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations ||
        !ref.read(tierProvider).capabilities.particles;
    if (still) {
      _stagger.value = 1;
    } else if (!_stagger.isAnimating && _stagger.value == 0) {
      _stagger.forward();
    }
  }

  @override
  void dispose() {
    _tipSub?.cancel();
    _stagger.dispose();
    super.dispose();
  }

  void _onTipOutcome(TipOutcome outcome) {
    if (!mounted) return;
    final en = ref.read(langProvider) == Lang.en;
    switch (outcome) {
      case TipOutcome.thanked:
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: VSColors.lacquerRaised,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: VSRadii.card),
            side: BorderSide(color: VSColors.goldBorder),
          ),
          builder: (_) => _ThanksSheet(en: en),
        );
      case TipOutcome.pending:
        _toast(en
            ? 'Your payment is awaiting confirmation.'
            : 'Giao dịch đang chờ xác nhận.');
      case TipOutcome.failed:
        _toast(en
            ? 'The purchase didn’t go through. Please try again later.'
            : 'Chưa thực hiện được giao dịch. Vui lòng thử lại sau.');
      case TipOutcome.cancelled:
        break;
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: VSColors.lacquerRaised,
      content: Text(text, style: VSType.bodySmall),
    ));
  }

  /// The i-th element's fade + 12px rise, 60ms after the previous one.
  Widget _rise(int i, Widget child) {
    const total = 700.0;
    final start = (i * 60 / total).clamp(0.0, 1.0);
    final end = (start + 320 / total).clamp(0.0, 1.0);
    final a = CurvedAnimation(
      parent: _stagger,
      curve: Interval(start, end, curve: VSMotion.emphasized),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - a.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final version = ref.watch(activeContentVersionProvider);
    final offer = ref.watch(tipOfferProvider).valueOrNull;
    final particles = ref.watch(tierProvider).capabilities.particles;

    var i = 0;
    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _SanhBackdrop(),
          if (particles)
            const ParticleField(color: VSColors.goldBright, count: 10, seed: 23),
          SafeArea(
            child: CustomPaint(
              painter: const _PanelFramePainter(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 26, 32, 40),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const LangToggle(),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.close,
                        size: 34,
                        onTap: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSSpacing.lg),
                  _rise(i++, const _BrandLockup()),
                  const SizedBox(height: VSSpacing.xxl),
                  _rise(i++, _ChaoCoCard(en: en)),
                  const SizedBox(height: VSSpacing.xxl),
                  _rise(
                    i++,
                    Text(en ? 'EXPLORE' : 'LỐI VÀO', style: VSType.overline),
                  ),
                  const SizedBox(height: VSSpacing.xs),
                  Container(height: 1, color: VSColors.goldBorder),
                  for (final item in _items)
                    _rise(i++, _DirectoryRow(item: item, en: en)),
                  if (offer != null) ...<Widget>[
                    const SizedBox(height: VSSpacing.xl),
                    _rise(
                      i++,
                      _TipRow(
                        price: offer.price,
                        en: en,
                        onTap: () => ref.read(tipStoreProvider)?.buy(),
                      ),
                    ),
                  ],
                  const SizedBox(height: VSSpacing.xxl),
                  Text(
                    en
                        ? 'Content · version $version'
                        : 'Nội dung · bản $version',
                    textAlign: TextAlign.center,
                    style: VSType.provenance.copyWith(color: VSColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lacquer ground, a radial lift near the top, and the seal as a faint gold
/// watermark sinking off the bottom edge.
class _SanhBackdrop extends StatelessWidget {
  const _SanhBackdrop();

  // Luminance → gold: keeps the seal's gold line-work, drops its oxblood.
  static const ColorFilter _goldTone = ColorFilter.matrix(<double>[
    0.168, 0.565, 0.057, 0, 0, //
    0.136, 0.458, 0.046, 0, 0, //
    0.062, 0.207, 0.021, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.7),
              radius: 1.2,
              colors: <Color>[VSColors.lacquerRaised, VSColors.lacquerDeep],
            ),
          ),
        ),
        Positioned(
          left: -w * 0.15,
          right: -w * 0.15,
          bottom: -w * 0.45,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.05,
              child: ColorFiltered(
                colorFilter: _goldTone,
                child: Image.asset(
                  SealButton.asset,
                  width: w * 1.3,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A lacquer panel's border: a chamfered outer gold rule, a fainter inner rule,
/// and a small gold lozenge at each corner.
class _PanelFramePainter extends CustomPainter {
  const _PanelFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const outer = 14.0;
    const inner = 20.0;
    const cut = 10.0;
    final r = Rect.fromLTRB(outer, outer, size.width - outer, size.height - outer);
    final chamfered = Path()
      ..moveTo(r.left + cut, r.top)
      ..lineTo(r.right - cut, r.top)
      ..lineTo(r.right, r.top + cut)
      ..lineTo(r.right, r.bottom - cut)
      ..lineTo(r.right - cut, r.bottom)
      ..lineTo(r.left + cut, r.bottom)
      ..lineTo(r.left, r.bottom - cut)
      ..lineTo(r.left, r.top + cut)
      ..close();
    canvas.drawPath(
      chamfered,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = VSColors.goldBorder,
    );
    canvas.drawRect(
      Rect.fromLTRB(inner, inner, size.width - inner, size.height - inner),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = VSColors.gold.withValues(alpha: 0.18),
    );
    final lozenge = Paint()..color = VSColors.gold;
    for (final c in <Offset>[
      Offset(r.left + cut / 2, r.top + cut / 2),
      Offset(r.right - cut / 2, r.top + cut / 2),
      Offset(r.left + cut / 2, r.bottom - cut / 2),
      Offset(r.right - cut / 2, r.bottom - cut / 2),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 2.5)
          ..lineTo(c.dx + 2.5, c.dy)
          ..lineTo(c.dx, c.dy + 2.5)
          ..lineTo(c.dx - 2.5, c.dy)
          ..close(),
        lozenge,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PanelFramePainter oldDelegate) => false;
}

/// The splash lockup, smaller: seal on a gold halo, wordmark, rule, kicker.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: VSColors.gold.withValues(alpha: 0.22),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              SealButton.asset,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(height: VSSpacing.md),
        Text(
          'Long Ký',
          style: VSType.hero.copyWith(
            fontSize: 30,
            color: VSColors.goldBright,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: VSSpacing.sm),
        Container(width: 40, height: 1, color: VSColors.goldBorder),
        const SizedBox(height: VSSpacing.sm),
        Text('NGHÌN NĂM SỬ VIỆT', style: VSType.kicker),
      ],
    );
  }
}

/// The Sảnh's feature card: Chào cờ, the daily flag salute.
class _ChaoCoCard extends StatelessWidget {
  const _ChaoCoCard({required this.en});
  final bool en;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('sanh-chao-co-card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/chao-co'),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: VSRadii.cardAll,
          border: Border.all(color: VSColors.goldBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // A tall photo: anchor on the waving flag near its top.
            Image.asset(
              'assets/content/chao-co/background.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.92),
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: VSColors.lacquerRaised),
            ),
            // Lacquer on the left (behind the title), clear on the flag side.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xE607100F), Color(0x3307100F)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
            const Positioned(left: 16, top: 16, child: FlagMark()),
            Positioned(
              left: 18,
              right: 72,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    en ? 'CEREMONY' : 'NGHI THỨC',
                    style: VSType.overline.copyWith(color: VSColors.goldBright),
                  ),
                  const SizedBox(height: 2),
                  Text(en ? 'Salute the flag' : 'Chào cờ',
                      style: VSType.headline),
                  const SizedBox(height: 2),
                  Text(
                    en ? 'National flag · Anthem' : 'Quốc kỳ · Tiến quân ca',
                    style: VSType.caption.copyWith(color: VSColors.inkSecondary),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 18,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSColors.gold.withValues(alpha: 0.14),
                  border: Border.all(color: VSColors.goldBright),
                ),
                child: const Icon(Icons.arrow_forward,
                    size: 18, color: VSColors.goldBright),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({required this.item, required this.en});
  final _SanhItem item;
  final bool en;

  @override
  Widget build(BuildContext context) {
    return _SanhRow(
      key: ValueKey<String>('sanh-row-${item.route}'),
      icon: item.icon,
      title: en ? item.titleEn : item.titleVi,
      subtitle: en ? item.subtitleEn : item.subtitleVi,
      trailing: Icon(Icons.chevron_right,
          color: VSColors.gold.withValues(alpha: 0.7)),
      onTap: () => context.push(item.route),
    );
  }
}

/// "Mời Long Ký một chén trà" — shown only when the store product loaded.
class _TipRow extends StatelessWidget {
  const _TipRow({required this.price, required this.en, required this.onTap});
  final String price;
  final bool en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SanhRow(
      key: const ValueKey<String>('sanh-tip-row'),
      icon: Icons.emoji_food_beverage_outlined,
      title: en ? 'Buy Long Ký a cup of tea' : 'Mời Long Ký một chén trà',
      subtitle: en
          ? 'Keep Long Ký free and ad-free'
          : 'Giữ Long Ký miễn phí, không quảng cáo',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: VSRadii.pillAll,
          border: Border.all(color: VSColors.gold.withValues(alpha: 0.6)),
        ),
        child: Text(price,
            style: VSType.caption.copyWith(color: VSColors.goldBright)),
      ),
      onTap: onTap,
      topRule: true,
    );
  }
}

class _SanhRow extends StatelessWidget {
  const _SanhRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.topRule = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    const rule = BorderSide(color: VSColors.goldBorder);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: VSSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: rule, top: topRule ? rule : BorderSide.none),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Icon(icon, size: 22, color: VSColors.gold),
            ),
            const SizedBox(width: VSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: VSType.cardTitle),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VSType.caption.copyWith(color: VSColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: VSSpacing.sm),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ThanksSheet extends StatelessWidget {
  const _ThanksSheet({required this.en});
  final bool en;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(SealButton.asset, width: 48, height: 48),
            ),
            const SizedBox(height: VSSpacing.md),
            Text(
              en
                  ? 'Thank you for the cup of tea.'
                  : 'Cảm ơn bạn đã mời Long Ký một chén trà.',
              textAlign: TextAlign.center,
              style: VSType.title.copyWith(color: VSColors.goldBright),
            ),
            const SizedBox(height: VSSpacing.sm),
            Text(
              en
                  ? 'Every cup helps Long Ký write the next eras.'
                  : 'Mỗi chén trà giúp Long Ký viết tiếp những kỷ nguyên mới.',
              textAlign: TextAlign.center,
              style: VSType.body,
            ),
            const SizedBox(height: VSSpacing.lg),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(en ? 'Close' : 'Đóng',
                  style: VSType.label.copyWith(color: VSColors.goldBright)),
            ),
          ],
        ),
      ),
    );
  }
}
