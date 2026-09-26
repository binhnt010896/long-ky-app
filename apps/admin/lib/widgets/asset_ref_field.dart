import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../util/media_urls.dart';

/// Read-only display of an [AssetRef]-shaped map (`{id, type, flagship,
/// reduced, ...}`) — a thumbnail plus a link into the Media Library, which
/// owns the actual replace flow (so upload logic lives in exactly one
/// place instead of being duplicated into every form that shows an image).
class AssetRefField extends StatelessWidget {
  const AssetRefField({
    required this.label,
    required this.assetRef,
    required this.manifest,
    this.caption,
    this.size = 160,
    super.key,
  });

  final String label;
  final Map<String, dynamic>? assetRef;
  final MediaManifest manifest;

  /// A short note under the label, e.g. clarifying when a legacy field is
  /// actually used — shown only when non-null, never invented per-field.
  final String? caption;
  final double size;

  String? get _sourcePath =>
      (assetRef?['flagship'] as String?) ?? (assetRef?['reduced'] as String?);

  @override
  Widget build(BuildContext context) {
    final path = _sourcePath;
    final url = path == null ? null : manifest.urlFor(path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(caption!, style: Theme.of(context).textTheme.bodySmall),
            )
          else
            const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: path == null
                    ? null
                    : () => context.push('/media?focus=${Uri.encodeComponent(path)}'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: path == null
                      ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 32))
                      : (url == null
                            ? const Center(child: Icon(Icons.error_outline, size: 32))
                            : Image.network(url, fit: BoxFit.cover)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(path ?? 'not set', style: Theme.of(context).textTheme.bodySmall),
                    if (path != null && url == null)
                      Text(
                        'Not published yet',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    if (path != null)
                      TextButton(
                        onPressed: () =>
                            context.push('/media?focus=${Uri.encodeComponent(path)}'),
                        child: const Text('Manage in Media Library'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
