import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../telemetry/telemetry.dart';

/// The route a street target opens (existing routes — see app_router.dart).
/// An event opens by id alone (`/su-kien/:id`): the router sends one that sits
/// in an era on to `/era/:slug/event/:id`, and a standalone one has no era.
String routeForTarget(StreetTarget t) => switch (t.type) {
      // A standalone person has no era: they open by id alone.
      StreetTargetType.person => t.era.isEmpty
          ? '/nhan-vat/${t.id}'
          : '/era/${t.era}/figure/${t.id}',
      StreetTargetType.event => '/su-kien/${t.id}',
      StreetTargetType.era => '/era/${t.era}',
    };

/// The street card: the street's name, then one row per target it is named
/// after, each with a button that opens that Character / Event / Era page.
class StreetCard extends ConsumerWidget {
  const StreetCard({required this.street, required this.onClose, super.key});

  final MappedStreet street;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return Material(
      color: VSColors.lacquerRaised.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: VSRadii.cardAll,
        side: BorderSide(color: VSColors.gold.withValues(alpha: 0.5)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VSSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      street.name,
                      style: VSType.bodySmall.copyWith(
                          color: VSColors.goldBright,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    key: const Key('street-card-close'),
                    tooltip: lang == Lang.vi ? 'Đóng' : 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    color: VSColors.gold,
                    onPressed: onClose,
                  ),
                ],
              ),
              for (final t in street.targets)
                _TargetRow(street: street, target: t, lang: lang),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetRow extends ConsumerWidget {
  const _TargetRow(
      {required this.street, required this.target, required this.lang});

  final MappedStreet street;
  final StreetTarget target;
  final Lang lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An event resolves by id alone — it may sit in an era or be standalone.
    final found = target.type == StreetTargetType.event
        ? ref.watch(eventLocationProvider(target.id)).valueOrNull
        : null;
    // A standalone person (no era) resolves through the people registry.
    final standalone =
        target.type == StreetTargetType.person && target.era.isEmpty;
    final people = standalone ? ref.watch(peopleProvider).valueOrNull : null;
    final registered = people == null ? null : people[target.id];
    final era = target.type == StreetTargetType.event || standalone
        ? null
        : ref.watch(eraProvider(target.era)).valueOrNull;
    final missing = switch (target.type) {
      StreetTargetType.event => found == null,
      StreetTargetType.person when standalone => registered == null,
      _ => era == null,
    };
    if (missing) return const SizedBox.shrink();

    final String title;
    final String line;
    final String button;
    switch (target.type) {
      case StreetTargetType.person:
        final f = standalone ? registered : era!.figureById(target.id);
        if (f == null) return const SizedBox.shrink();
        title = f.name.resolve(lang);
        line = [
          f.epithet?.resolve(lang),
          f.bio?.resolve(lang),
        ].whereType<String>().where((s) => s.isNotEmpty).join(' — ');
        button = lang == Lang.vi ? 'Xem nhân vật' : 'View figure';
      case StreetTargetType.event:
        final e = found!.event;
        title = e.title.resolve(lang);
        line = e.year.display.resolve(lang);
        button = lang == Lang.vi ? 'Xem sự kiện' : 'View event';
      case StreetTargetType.era:
        title = era!.title.resolve(lang);
        line = era.yearRange.display.resolve(lang);
        button = lang == Lang.vi ? 'Xem thời kỳ' : 'View era';
    }

    return Padding(
      padding: const EdgeInsets.only(top: VSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: VSType.bodySmall
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
          if (line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: VSType.bodySmall
                      .copyWith(color: VSColors.gold.withValues(alpha: 0.85))),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('street-open-${target.type.name}-${target.id}'),
              style: TextButton.styleFrom(
                  foregroundColor: VSColors.goldBright,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 40)),
              onPressed: () {
                ref.read(telemetryProvider).event('street_open_detail',
                    <String, Object>{
                      'street_id': street.id,
                      'target': '${target.type.name}:${target.id}',
                    });
                context.push(routeForTarget(target));
              },
              child: Text('$button →'),
            ),
          ),
        ],
      ),
    );
  }
}
