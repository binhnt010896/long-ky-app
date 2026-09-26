import 'package:flutter/material.dart';

/// A vi/en pair, matching every `{vi, en}` field in the schemas. `vi` is
/// required by the schema; `en` is optional there but every real entry has
/// one, so both are shown side by side.
class LocalizedTextField extends StatelessWidget {
  const LocalizedTextField({
    required this.label,
    required this.vi,
    required this.en,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final TextEditingController vi;
  final TextEditingController en;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(label)),
          ),
          Expanded(
            child: TextField(
              controller: vi,
              maxLines: maxLines,
              decoration: const InputDecoration(labelText: 'vi', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: en,
              maxLines: maxLines,
              decoration: const InputDecoration(labelText: 'en', border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reads a `{vi, en}` map (or null) into a pair of controllers.
({TextEditingController vi, TextEditingController en}) localizedControllers(Object? field) {
  final map = field is Map<String, dynamic> ? field : const <String, dynamic>{};
  return (
    vi: TextEditingController(text: map['vi'] as String? ?? ''),
    en: TextEditingController(text: map['en'] as String? ?? ''),
  );
}

Map<String, String> localizedValue(TextEditingController vi, TextEditingController en) =>
    {'vi': vi.text, 'en': en.text};
