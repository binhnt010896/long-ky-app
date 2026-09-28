import 'package:flutter/material.dart';

import 'localized_text_field.dart';

/// An event's `year` (`{display{vi,en}, value, approximate}`). Unlike
/// [YearRangeField] (a start/end span), this is a single point in time that
/// may have no fixed date at all — a legend with `value: null`.
class EventYearField extends StatefulWidget {
  const EventYearField({required this.initial, required this.onChanged, super.key});

  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> year) onChanged;

  @override
  State<EventYearField> createState() => _EventYearFieldState();
}

class _EventYearFieldState extends State<EventYearField> {
  late final displayVi = TextEditingController(
    text: (widget.initial?['display'] as Map?)?['vi'] as String? ?? '',
  );
  late final displayEn = TextEditingController(
    text: (widget.initial?['display'] as Map?)?['en'] as String? ?? '',
  );
  late bool _dated = widget.initial?['value'] != null;
  late final int _year = (widget.initial?['value'] as int?)?.abs() ?? 0;
  late bool _bce = ((widget.initial?['value'] as int?) ?? 0) < 0;
  late bool _approximate = widget.initial?['approximate'] as bool? ?? false;
  late final _yearController = TextEditingController(text: '$_year');
  late bool _displayEdited = widget.initial != null;

  void _suggestDisplay() {
    if (_displayEdited) return;
    if (!_dated) {
      displayVi.text = 'Huyền sử';
      displayEn.text = 'Legend';
    } else {
      final y = int.tryParse(_yearController.text) ?? 0;
      final prefix = _approximate ? '≈ ' : '';
      displayVi.text = _bce ? '$prefix$y TCN' : '$prefix$y';
      displayEn.text = _bce ? '$prefix$y BCE' : '$prefix$y CE';
    }
    _emit();
  }

  void _emit() {
    final y = int.tryParse(_yearController.text) ?? 0;
    widget.onChanged({
      'display': localizedValue(displayVi, displayEn),
      'value': _dated ? (_bce ? -y : y) : null,
      'approximate': _approximate,
    });
  }

  @override
  void initState() {
    super.initState();
    for (final c in [displayVi, displayEn]) {
      c.addListener(() {
        _displayEdited = true;
        _emit();
      });
    }
    _yearController.addListener(_suggestDisplay);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _dated,
          title: const Text('Has a numeric year'),
          subtitle: const Text('Off for a pure legend with no fixed date.'),
          onChanged: (v) => setState(() {
            _dated = v ?? false;
            _suggestDisplay();
          }),
        ),
        if (_dated)
          Row(
            children: [
              const SizedBox(width: 100, child: Text('Year')),
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              Checkbox(
                value: _bce,
                onChanged: (v) => setState(() {
                  _bce = v ?? false;
                  _suggestDisplay();
                }),
              ),
              const Text('BCE'),
              const SizedBox(width: 16),
              Checkbox(
                value: _approximate,
                onChanged: (v) => setState(() {
                  _approximate = v ?? false;
                  _suggestDisplay();
                }),
              ),
              const Text('≈ approximate'),
            ],
          ),
        LocalizedTextField(label: 'Display', vi: displayVi, en: displayEn),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [displayVi, displayEn, _yearController]) {
      c.dispose();
    }
    super.dispose();
  }
}
