import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import 'street_data.dart';

/// True when the street map is already open somewhere behind the current page
/// (e.g. map → street card → character): the chip would only loop back to it.
bool streetMapIsOpen(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return false;
  bool inList(RouteMatchList list) => list.matches.any((m) =>
      m is ImperativeRouteMatch
          ? inList(m.matches)
          : m.matchedLocation == '/duong-pho');
  return inList(router.routerDelegate.currentConfiguration);
}

/// "Một con đường ở TP.HCM mang tên này → Xem trên bản đồ" — shown on a
/// Character/Event page only when that page is a target of an APPROVED
/// street. Renders nothing (not even spacing) otherwise, and while loading.
class StreetReverseChip extends ConsumerWidget {
  const StreetReverseChip({required this.type, required this.id, super.key});

  final StreetTargetType type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (streetMapIsOpen(context)) return const SizedBox.shrink();
    final streets = ref
            .watch(streetMappingProvider)
            .valueOrNull
            ?.streetsFor(type, id) ??
        const <MappedStreet>[];
    if (streets.isEmpty) return const SizedBox.shrink();
    final lang = ref.watch(langProvider);
    final n = streets.length;
    final label = lang == Lang.vi
        ? (n == 1
            ? 'Một con đường ở TP.HCM mang tên này'
            : '$n con đường ở TP.HCM mang tên này')
        : (n == 1
            ? 'A street in Ho Chi Minh City bears this name'
            : '$n streets in Ho Chi Minh City bear this name');
    final cta = lang == Lang.vi ? 'Xem trên bản đồ' : 'See on the map';
    return Padding(
      padding: const EdgeInsets.only(top: VSSpacing.xl),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(
            side: BorderSide(color: VSColors.goldBorder, width: 0.8)),
        child: InkWell(
          key: const Key('street-reverse-chip'),
          customBorder: const StadiumBorder(),
          onTap: () => context.push('/duong-pho?street=${streets.first.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: VSSpacing.lg, vertical: VSSpacing.md),
            child: Row(
              children: <Widget>[
                const Icon(Icons.signpost_outlined,
                    size: 18, color: VSColors.gold),
                const SizedBox(width: VSSpacing.sm),
                Expanded(
                  child: Text(label,
                      style: VSType.bodySmall.copyWith(color: VSColors.inkBody)),
                ),
                const SizedBox(width: VSSpacing.sm),
                Text('$cta →',
                    style: VSType.bodySmall.copyWith(color: VSColors.goldBright)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
