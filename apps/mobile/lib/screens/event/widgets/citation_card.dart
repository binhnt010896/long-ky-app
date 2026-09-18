import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The visible source citation — rendered on every event. Provenance is a
/// feature of Việt Sử, not fine print.
class CitationCard extends StatelessWidget {
  const CitationCard({required this.citation, required this.lang, super.key});

  final Citation citation;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final label = lang == Lang.vi ? 'NGUỒN' : 'SOURCE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: VSColors.goldWash,
        borderRadius: VSRadii.citationAll,
        border: Border.all(color: VSColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Transform.rotate(
                angle: 0.785398, // 45°
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    border: Border.all(color: VSColors.gold, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(width: VSSpacing.sm),
              Text(
                label,
                style: VSType.overline.copyWith(
                  color: VSColors.goldBright,
                  fontWeight: FontWeight.w600,
                  letterSpacing: VSType.track(0.36, 10),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: VSSpacing.sm),
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[VSColors.goldBorder, Color(0x00C9A24B)],
                    ),
                  ),
                  child: SizedBox(height: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSSpacing.sm + 1),
          Text(citation.work, style: VSType.title.copyWith(fontSize: 16)),
          if (citation.section != null) ...<Widget>[
            const SizedBox(height: VSSpacing.xxs),
            Text(
              citation.section!.resolve(lang),
              style: VSType.caption.copyWith(
                color: VSColors.inkMuted,
                letterSpacing: VSType.track(0.04, 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
