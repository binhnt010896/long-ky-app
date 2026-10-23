import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/visit_store.dart';
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
///
/// When opening this very page is what first lit a street, the chip says so,
/// once ("Vừa thắp sáng: đường Lý Tự Trọng") — no toast, no sound.
class StreetReverseChip extends ConsumerStatefulWidget {
  const StreetReverseChip({required this.type, required this.id, super.key});

  final StreetTargetType type;
  final String id;

  @override
  ConsumerState<StreetReverseChip> createState() => _StreetReverseChipState();
}

class _StreetReverseChipState extends ConsumerState<StreetReverseChip> {
  /// Latched when [newlyLitProvider] names this page, so the message survives
  /// the provider being cleared (and the page rebuilding) but not a later
  /// visit: a new page state starts without it.
  List<MappedStreet> _lit = const <MappedStreet>[];

  String get _key => widget.type == StreetTargetType.event
      ? VisitKey.event(widget.id)
      : widget.type == StreetTargetType.person
          ? VisitKey.person(widget.id)
          : VisitKey.era(widget.id);

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final id = widget.id;
    final newly = ref.watch(newlyLitProvider);
    if (newly != null && newly.key == _key) {
      _lit = newly.streets;
      // Said once: clear it for the next page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(newlyLitProvider)?.key == _key) {
          ref.read(newlyLitProvider.notifier).state = null;
        }
      });
    }
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
    final litLabel = _lit.isEmpty
        ? null
        : lang == Lang.vi
            ? 'Vừa thắp sáng: đường ${_lit.first.name}${_lit.length > 1 ? ' và ${_lit.length - 1} đường khác' : ''}'
            : 'Just lit up: ${_lit.first.name}${_lit.length > 1 ? ' and ${_lit.length - 1} more' : ''}';
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
                Icon(litLabel == null ? Icons.signpost_outlined : Icons.auto_awesome,
                    size: 18,
                    color: litLabel == null ? VSColors.gold : VSColors.goldBright),
                const SizedBox(width: VSSpacing.sm),
                Expanded(
                  child: Text(litLabel ?? label,
                      key: litLabel == null ? null : const Key('street-lit-message'),
                      style: VSType.bodySmall.copyWith(
                          color: litLabel == null
                              ? VSColors.inkBody
                              : VSColors.goldBright)),
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
