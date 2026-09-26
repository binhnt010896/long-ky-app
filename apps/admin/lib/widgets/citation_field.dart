import 'package:flutter/material.dart';

import 'localized_text_field.dart';

/// A `citation` object (`{work, section{vi,en}, author}`) — only `work` is
/// required by the schema.
class CitationField extends StatefulWidget {
  const CitationField({required this.label, required this.initial, required this.onChanged, super.key});

  final String label;
  final Map<String, dynamic>? initial;
  final void Function(Map<String, dynamic> citation) onChanged;

  @override
  State<CitationField> createState() => _CitationFieldState();
}

class _CitationFieldState extends State<CitationField> {
  late final work = TextEditingController(text: widget.initial?['work'] as String? ?? '');
  late final author = TextEditingController(text: widget.initial?['author'] as String? ?? '');
  late final sectionVi = TextEditingController(
    text: (widget.initial?['section'] as Map?)?['vi'] as String? ?? '',
  );
  late final sectionEn = TextEditingController(
    text: (widget.initial?['section'] as Map?)?['en'] as String? ?? '',
  );

  void _emit() {
    widget.onChanged({
      'work': work.text,
      if (author.text.isNotEmpty) 'author': author.text,
      if (sectionVi.text.isNotEmpty || sectionEn.text.isNotEmpty)
        'section': localizedValue(sectionVi, sectionEn),
    });
  }

  @override
  void initState() {
    super.initState();
    for (final c in [work, author, sectionVi, sectionEn]) {
      c.addListener(_emit);
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        TextField(
          controller: work,
          decoration: const InputDecoration(
            labelText: 'Work (required), e.g. Đại Việt sử ký toàn thư',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        LocalizedTextField(label: 'Section', vi: sectionVi, en: sectionEn),
        TextField(
          controller: author,
          decoration: const InputDecoration(labelText: 'Author', border: OutlineInputBorder()),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [work, author, sectionVi, sectionEn]) {
      c.dispose();
    }
    super.dispose();
  }
}
