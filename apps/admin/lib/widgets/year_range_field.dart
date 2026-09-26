import 'package:flutter/material.dart';

import 'localized_text_field.dart';

/// `yearRange = {display{vi,en}, startYear, endYear}`. Years are signed
/// (negative = BCE) in the schema; this shows a magnitude field plus a BCE
/// checkbox instead, since typing "-2879" is easy to get backwards.
class YearRangeField extends StatefulWidget {
  const YearRangeField({required this.initial, required this.onChanged, super.key});

  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> yearRange) onChanged;

  @override
  State<YearRangeField> createState() => _YearRangeFieldState();
}

class _YearRangeFieldState extends State<YearRangeField> {
  late final displayVi = TextEditingController(
    text: (widget.initial?['display'] as Map?)?['vi'] as String? ?? '',
  );
  late final displayEn = TextEditingController(
    text: (widget.initial?['display'] as Map?)?['en'] as String? ?? '',
  );
  late int startYear = widget.initial?['startYear'] as int? ?? 0;
  late int endYear = widget.initial?['endYear'] as int? ?? 0;
  late final startController = TextEditingController(text: '${startYear.abs()}');
  late final endController = TextEditingController(text: '${endYear.abs()}');
  late bool startBce = startYear < 0;
  late bool endBce = endYear < 0;

  void _emit() {
    final start = int.tryParse(startController.text) ?? 0;
    final end = int.tryParse(endController.text) ?? 0;
    widget.onChanged({
      'display': localizedValue(displayVi, displayEn),
      'startYear': startBce ? -start : start,
      'endYear': endBce ? -end : end,
    });
  }

  @override
  void initState() {
    super.initState();
    for (final c in [displayVi, displayEn, startController, endController]) {
      c.addListener(_emit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedTextField(label: 'Display', vi: displayVi, en: displayEn),
        Row(
          children: [
            const SizedBox(width: 100, child: Text('Years')),
            Expanded(
              child: TextField(
                controller: startController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Start', border: OutlineInputBorder()),
              ),
            ),
            Checkbox(
              value: startBce,
              onChanged: (v) => setState(() {
                startBce = v ?? false;
                _emit();
              }),
            ),
            const Text('BCE'),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: endController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'End', border: OutlineInputBorder()),
              ),
            ),
            Checkbox(
              value: endBce,
              onChanged: (v) => setState(() {
                endBce = v ?? false;
                _emit();
              }),
            ),
            const Text('BCE'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [displayVi, displayEn, startController, endController]) {
      c.dispose();
    }
    super.dispose();
  }
}
