import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../widgets/pressable.dart';

/// One event row on the era timeline: a node on the gold spine plus the card.
///
/// [active] is the event currently at the reading position (elevated, gold
/// border, lit node). [lit] marks the spine/node as "reached" — everything up to
/// and including the active event, forming the gold progress spine.
class TimelineEventCard extends StatelessWidget {
  const TimelineEventCard({
    required this.event,
    required this.active,
    required this.lit,
    required this.lang,
    required this.onTap,
    this.read = false,
    super.key,
  });

  final HistoryEvent event;
  final bool active;
  final bool lit;
  final Lang lang;
  final VoidCallback onTap;

  /// The reader has opened this event before: its node fills in gold and the
  /// card carries a small "read" tick, so a long list shows what is left.
  final bool read;

  @override
  Widget build(BuildContext context) {
    final nodeSize = active ? 12.0 : (read ? 9.0 : 7.0);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Stack(
              children: <Widget>[
                // Spine segment — gold when reached, faint otherwise.
                Positioned(
                  left: 7,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: lit
                          ? VSColors.gold.withValues(alpha: 0.6)
                          : VSColors.gold.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                // Node dot.
                Positioned(
                  left: 7.75 - nodeSize / 2,
                  top: 20,
                  child: Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active || read
                          ? VSColors.goldBright
                          : (lit
                              ? VSColors.gold.withValues(alpha: 0.6)
                              : VSColors.gold.withValues(alpha: 0.3)),
                      border: active
                          ? Border.all(color: VSColors.lacquer, width: 2)
                          : null,
                      boxShadow: active
                          ? const <BoxShadow>[
                              BoxShadow(color: VSColors.goldGlow, blurRadius: 12),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Pressable(
              onTap: onTap,
              child: AnimatedContainer(
                duration: VSMotion.control,
                margin: const EdgeInsets.only(bottom: VSSpacing.md),
                padding: EdgeInsets.all(active ? VSSpacing.lg : VSSpacing.md - 3),
                decoration: BoxDecoration(
                  // Near-opaque lacquer so the summary text stays readable
                  // over even the brightest era scene — see the contrast note
                  // on era_timeline_screen.dart's TiltedBackdrop scrim.
                  color: VSColors.lacquer.withValues(alpha: active ? 0.9 : 0.82),
                  borderRadius: VSRadii.cardAll,
                  border: Border.all(
                    color: active
                        ? VSColors.gold.withValues(alpha: 0.4)
                        : VSColors.inkPrimary.withValues(alpha: 0.08),
                  ),
                  boxShadow: active
                      ? const <BoxShadow>[
                          BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 40,
                              offset: Offset(0, 16)),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            event.year.display.resolve(lang),
                            style: VSType.caption.copyWith(
                              color: VSColors.gold,
                              fontWeight: FontWeight.w500,
                              letterSpacing: VSType.track(0.14, 11),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (read)
                          ReadMark(lang: lang),
                      ],
                    ),
                    const SizedBox(height: VSSpacing.xs),
                    Text(event.title.resolve(lang), style: VSType.cardTitle),
                    const SizedBox(height: VSSpacing.xs),
                    Text(
                      event.summary.resolve(lang),
                      style: VSType.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "read" tick beside an event the reader has already opened. An
/// icon plus the word, so it never rests on colour alone.
class ReadMark extends StatelessWidget {
  const ReadMark({required this.lang, this.showLabel = true, super.key});

  final Lang lang;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final label = lang == Lang.vi ? 'Đã đọc' : 'Read';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_circle, size: 13, color: VSColors.gold),
          if (showLabel) ...<Widget>[
            const SizedBox(width: 4),
            Text(
              label,
              style: VSType.caption.copyWith(
                color: VSColors.gold,
                fontSize: 11,
                letterSpacing: VSType.track(0.06, 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
