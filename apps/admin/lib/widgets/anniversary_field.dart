import 'package:flutter/material.dart';

/// An event's optional `anniversary` (`{month, day, calendar}`): the day of the
/// year the mobile app's "Hôm nay" shows it on. Solar is the Gregorian date;
/// lunar is the Vietnamese lunar calendar (pre-modern dates in the chronicles
/// are lunar, e.g. Giỗ Tổ Hùng Vương is 10/3 âm lịch). A lunar date is a
/// regular month, never a leap one.
class AnniversaryField extends StatefulWidget {
  const AnniversaryField({required this.initial, required this.onChanged, super.key});

  final Map<String, dynamic>? initial;

  /// Null when the event has no anniversary.
  final void Function(Map<String, dynamic>? anniversary) onChanged;

  @override
  State<AnniversaryField> createState() => _AnniversaryFieldState();
}

class _AnniversaryFieldState extends State<AnniversaryField> {
  late bool _on = widget.initial != null;
  late int _month = (widget.initial?['month'] as int?) ?? 1;
  late String _calendar = (widget.initial?['calendar'] as String?) ?? 'solar';
  late final _day = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!['day']}',
  );

  void _emit() {
    widget.onChanged(_on
        ? <String, dynamic>{
            'month': _month,
            // A blank or bad day goes out as 0 so the draft's validation flags
            // it, rather than the field quietly dropping the anniversary.
            'day': int.tryParse(_day.text.trim()) ?? 0,
            'calendar': _calendar,
          }
        : null);
  }

  @override
  void initState() {
    super.initState();
    _day.addListener(_emit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _on,
          title: const Text('Remembered on a day of the year (Hôm nay)'),
          subtitle: const Text(
              'The app shows this event on that day. Leave off if it has no anniversary.'),
          onChanged: (v) => setState(() {
            _on = v ?? false;
            _emit();
          }),
        ),
        if (_on)
          Row(
            children: [
              const SizedBox(width: 100, child: Text('Day / month')),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const ValueKey('anniversary-day'),
                  controller: _day,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: 'Day'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('anniversary-month'),
                  initialValue: _month,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), labelText: 'Month'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m')),
                  ],
                  onChanged: (v) => setState(() {
                    _month = v ?? 1;
                    _emit();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                key: const ValueKey('anniversary-calendar'),
                segments: const [
                  ButtonSegment(value: 'solar', label: Text('Solar')),
                  ButtonSegment(value: 'lunar', label: Text('Lunar')),
                ],
                selected: {_calendar},
                onSelectionChanged: (s) => setState(() {
                  _calendar = s.first;
                  _emit();
                }),
              ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }
}
