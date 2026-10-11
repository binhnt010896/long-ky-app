import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// Opens the street filter and returns the buckets the reader left switched
/// off (empty = show everything), or null when the sheet was dismissed.
Future<Set<StreetBucket>?> showStreetFilterSheet(
  BuildContext context, {
  required List<StreetFilterGroup> groups,
  required Set<StreetBucket> hidden,
  required int Function(Set<StreetBucket> hidden) visibleCount,
  required Lang lang,
}) {
  return showModalBottomSheet<Set<StreetBucket>>(
    context: context,
    backgroundColor: VSColors.lacquerRaised,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: VSRadii.card),
      side: BorderSide(color: VSColors.goldBorder),
    ),
    builder: (_) => StreetFilterSheet(
      groups: groups,
      initialHidden: hidden,
      visibleCount: visibleCount,
      lang: lang,
    ),
  );
}

/// "Lọc theo thời kỳ" — periods (dynasties) in order, each expanding to its
/// eras. Everything starts selected; unticking hides those streets.
class StreetFilterSheet extends StatefulWidget {
  const StreetFilterSheet({
    required this.groups,
    required this.initialHidden,
    required this.visibleCount,
    required this.lang,
    super.key,
  });

  final List<StreetFilterGroup> groups;
  final Set<StreetBucket> initialHidden;
  final int Function(Set<StreetBucket> hidden) visibleCount;
  final Lang lang;

  @override
  State<StreetFilterSheet> createState() => _StreetFilterSheetState();
}

class _StreetFilterSheetState extends State<StreetFilterSheet> {
  late final Set<StreetBucket> _hidden = {...widget.initialHidden};
  late final Set<String> _open = {
    // Open the periods the reader has already narrowed.
    for (final g in widget.groups)
      if (g.rows.any((r) => _hidden.contains(r.bucket))) g.period,
  };

  bool get _en => widget.lang == Lang.en;

  Iterable<StreetBucket> get _all =>
      [for (final g in widget.groups) for (final r in g.rows) r.bucket];

  /// `true` all shown, `false` all hidden, `null` some of each.
  bool? _stateOf(StreetFilterGroup g) {
    final off = g.rows.where((r) => _hidden.contains(r.bucket)).length;
    if (off == 0) return true;
    return off == g.rows.length ? false : null;
  }

  void _togglePeriod(StreetFilterGroup g) {
    setState(() {
      // Unticked or mixed → show all of it; fully ticked → hide all of it.
      if (_stateOf(g) == true) {
        _hidden.addAll(g.rows.map((r) => r.bucket));
      } else {
        _hidden.removeAll(g.rows.map((r) => r.bucket));
      }
    });
  }

  void _toggleRow(StreetFilterRow r) {
    setState(() {
      if (!_hidden.remove(r.bucket)) _hidden.add(r.bucket);
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.visibleCount(_hidden);
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _en ? 'Filter by period' : 'Lọc theo thời kỳ',
                style: VSType.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: VSSpacing.xs),
              Row(
                children: <Widget>[
                  _TextAction(
                    key: const Key('street-filter-all'),
                    label: _en ? 'Select all' : 'Chọn tất cả',
                    onTap: () => setState(_hidden.clear),
                  ),
                  _TextAction(
                    key: const Key('street-filter-none'),
                    label: _en ? 'Clear' : 'Bỏ chọn',
                    onTap: () => setState(() => _hidden.addAll(_all)),
                  ),
                ],
              ),
              const Divider(color: VSColors.goldBorder, height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: <Widget>[
                    for (final g in widget.groups) _group(g),
                  ],
                ),
              ),
              const SizedBox(height: VSSpacing.sm),
              _ApplyButton(
                key: const Key('street-filter-apply'),
                label: _en
                    ? 'Show $count streets'
                    : 'Xem $count đường',
                onTap: count == 0
                    ? null
                    : () => Navigator.of(context).pop(<StreetBucket>{..._hidden}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(StreetFilterGroup g) {
    final open = _open.contains(g.period);
    final title = g.title.resolve(widget.lang);
    final range = g.range?.resolve(widget.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          key: Key('street-filter-group-${g.period}'),
          onTap: () => setState(() {
            if (!_open.remove(g.period)) _open.add(g.period);
          }),
          child: Row(
            children: <Widget>[
              Checkbox(
                key: Key('street-filter-period-${g.period}'),
                tristate: true,
                value: _stateOf(g),
                activeColor: VSColors.gold,
                checkColor: VSColors.lacquer,
                side: const BorderSide(color: VSColors.gold, width: 1.2),
                onChanged: (_) => _togglePeriod(g),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: VSType.cardTitle),
                      if (range != null)
                        Text(
                          range,
                          style: VSType.caption
                              .copyWith(color: VSColors.inkMuted),
                        ),
                    ],
                  ),
                ),
              ),
              Text('${g.count}',
                  style:
                      VSType.caption.copyWith(color: VSColors.inkMuted)),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                color: VSColors.gold,
              ),
            ],
          ),
        ),
        if (open)
          for (final r in g.rows)
            InkWell(
              key: Key('street-filter-era-${g.period}-${r.bucket.era}'),
              onTap: () => _toggleRow(r),
              child: Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: !_hidden.contains(r.bucket),
                      activeColor: VSColors.gold,
                      checkColor: VSColors.lacquer,
                      side:
                          const BorderSide(color: VSColors.gold, width: 1.2),
                      onChanged: (_) => _toggleRow(r),
                    ),
                    Expanded(
                      child: Text(r.label.resolve(widget.lang),
                          style: VSType.bodySmall),
                    ),
                    Text('${r.count}',
                        style: VSType.caption
                            .copyWith(color: VSColors.inkMuted)),
                    const SizedBox(width: VSSpacing.sm),
                  ],
                ),
              ),
            ),
        const Divider(color: VSColors.goldBorder, height: 1),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: VSColors.goldBright,
          minimumSize: const Size(48, 40),
        ),
        child: Text(label),
      );
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? VSColors.goldSheen : null,
          color: on ? null : VSColors.inkPrimary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
        ),
        child: Text(
          label,
          style: VSType.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: on ? VSColors.lacquerRaised : VSColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
