import 'package:flutter/material.dart';

/// A `#rrggbb` field with a live swatch preview.
class HexColorField extends StatefulWidget {
  const HexColorField({
    required this.label,
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? initial;
  final ValueChanged<String> onChanged;

  @override
  State<HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<HexColorField> {
  late final controller = TextEditingController(text: widget.initial ?? '#5f8f74');

  Color? get _color {
    final hex = controller.text.replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(widget.label)),
        SizedBox(
          width: 160,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '#rrggbb', border: OutlineInputBorder()),
            onChanged: (v) {
              setState(() {});
              widget.onChanged(v);
            },
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _color,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
