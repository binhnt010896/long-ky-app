import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The red "unseen" badge pinned to the top-right corner of a chrome button.
class NewDot extends StatelessWidget {
  const NewDot({this.size = 10, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VSColors.notice,
        border: Border.all(color: VSColors.lacquer, width: 1.5),
      ),
    );
  }
}
