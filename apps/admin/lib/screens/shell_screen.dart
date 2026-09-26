import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../state/theme_prefs.dart';

const _destinations = [
  (path: '/', icon: Icons.dashboard_outlined, label: 'Dashboard'),
  (path: '/eras', icon: Icons.account_tree_outlined, label: 'Content'),
  (path: '/people', icon: Icons.people_outline, label: 'People'),
  (path: '/media', icon: Icons.image_outlined, label: 'Media'),
  (path: '/publish', icon: Icons.cloud_upload_outlined, label: 'Publish'),
];

enum _ShellMenuAction { appearance, signOut }

class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  int _selectedIndex(String location) {
    if (location.startsWith('/eras')) return 1;
    for (var i = 0; i < _destinations.length; i++) {
      if (location == _destinations[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (i) => context.go(_destinations[i].path),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/long-ky-logo.png', width: 40, height: 40),
                  ),
                  const SizedBox(height: 6),
                  Text('Long Ký', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  // A single menu, not two stacked IconButtons — the
                  // trailing area's height is whatever's left after the
                  // destinations above it, and in a short window two
                  // buttons could overflow it with the top one silently
                  // clipped. One icon always fits.
                  child: PopupMenuButton<_ShellMenuAction>(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      switch (action) {
                        case _ShellMenuAction.appearance:
                          showDialog<void>(
                            context: context,
                            builder: (context) => const _AppearanceDialog(),
                          );
                        case _ShellMenuAction.signOut:
                          ref.read(authControllerProvider).signOut();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _ShellMenuAction.appearance,
                        child: ListTile(
                          leading: Icon(Icons.palette_outlined),
                          title: Text('Appearance'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _ShellMenuAction.signOut,
                        child: ListTile(
                          leading: const Icon(Icons.logout),
                          title: Text(user?.email ?? 'Sign out'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AppearanceDialog extends ConsumerWidget {
  const _AppearanceDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePrefsProvider).valueOrNull;
    final controller = ref.read(themePrefsProvider.notifier);

    return AlertDialog(
      title: const Text('Appearance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Auto')),
            ],
            selected: {prefs?.themeMode ?? ThemeMode.system},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SizedBox(height: 16),
          Text('Accent colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final accent in CmsAccent.values)
                _AccentSwatch(
                  accent: accent,
                  selected: prefs?.accent == accent,
                  onTap: () => controller.setAccent(accent),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.accent, required this.selected, required this.onTap});

  final CmsAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                    : null,
              ),
              child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
            const SizedBox(height: 4),
            Text(accent.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
