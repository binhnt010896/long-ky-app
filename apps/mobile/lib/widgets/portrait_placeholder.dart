import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The stand-in for a person who has no portrait yet (a *held* portrait, or one
/// whose image is missing): a quiet lacquer tile with a faint head-and-shoulders
/// silhouette. No face is ever invented for someone who was photographed.
class PortraitPlaceholder extends StatelessWidget {
  const PortraitPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[VSColors.lacquerRaised, VSColors.lacquer],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: Icon(
            Icons.person_outline,
            size: box.biggest.shortestSide * 0.5,
            color: VSColors.gold.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}
