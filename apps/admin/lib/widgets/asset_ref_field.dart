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
    super.key,
  });

  final String label;
  final Map<String, dynamic>? assetRef;
  final MediaManifest manifest;

  String? get _sourcePath =>
      (assetRef?['flagship'] as String?) ?? (assetRef?['reduced'] as String?);

  @override
  Widget build(BuildContext context) {
    final path = _sourcePath;
    final url = path == null ? null : manifest.urlFor(path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(label))),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: path == null
                ? const Icon(Icons.image_not_supported_outlined)
                : (url == null
                      ? const Center(child: Icon(Icons.error_outline, size: 20))
                      : Image.network(url, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path ?? 'not set', style: Theme.of(context).textTheme.bodySmall),
                if (path != null && url == null)
                  Text('Not published yet', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (path != null)
                  TextButton(
                    onPressed: () => context.push('/media?focus=${Uri.encodeComponent(path)}'),
                    child: const Text('Manage in Media Library'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
