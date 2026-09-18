import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

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
    super.key,
  });

  final HistoryEvent event;
  final bool active;
  final bool lit;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nodeSize = active ? 12.0 : 7.0;
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
                      color: active
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                duration: VSMotion.control,
                margin: const EdgeInsets.only(bottom: VSSpacing.md),
                padding: EdgeInsets.all(active ? VSSpacing.lg : VSSpacing.md - 3),
                decoration: BoxDecoration(
                  color: VSColors.inkPrimary
                      .withValues(alpha: active ? 0.07 : 0.03),
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
                    Text(
                      event.year.display.resolve(lang),
                      style: VSType.caption.copyWith(
                        color: VSColors.gold,
                        fontWeight: FontWeight.w500,
                        letterSpacing: VSType.track(0.14, 11),
                        fontSize: 11,
                      ),
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
