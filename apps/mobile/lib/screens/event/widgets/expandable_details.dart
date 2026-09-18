import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// A "read more" control that reveals the fuller chronicle account for an event.
class ExpandableDetails extends StatefulWidget {
  const ExpandableDetails({
    required this.details,
    required this.lang,
    super.key,
  });

  final LocalizedText details;
  final Lang lang;

  @override
  State<ExpandableDetails> createState() => _ExpandableDetailsState();
}

class _ExpandableDetailsState extends State<ExpandableDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final vi = widget.lang == Lang.vi;
    final label = _open
        ? (vi ? 'THU GỌN' : 'SHOW LESS')
        : (vi ? 'ĐỌC THÊM' : 'READ MORE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: VSSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: VSType.overline.copyWith(
                    color: VSColors.goldBright,
                    letterSpacing: VSType.track(0.28, 11),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: VSSpacing.xs),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: VSMotion.control,
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: VSColors.goldBright),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: VSMotion.control,
          curve: VSMotion.standard,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: VSSpacing.sm),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: VSColors.goldBorder, width: 2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: VSSpacing.md),
                      child: Text(
                        widget.details.resolve(widget.lang),
                        style: VSType.body.copyWith(color: VSColors.inkBody),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
