import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';

const _destinations = [
  (path: '/', icon: Icons.dashboard_outlined, label: 'Dashboard'),
  (path: '/eras', icon: Icons.auto_stories_outlined, label: 'Eras'),
  (path: '/people', icon: Icons.people_outline, label: 'People'),
  (path: '/periods', icon: Icons.timeline_outlined, label: 'Periods'),
  (path: '/media', icon: Icons.image_outlined, label: 'Media'),
  (path: '/preview', icon: Icons.phone_iphone_outlined, label: 'Preview'),
  (path: '/publish', icon: Icons.cloud_upload_outlined, label: 'Publish'),
];

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
                  child: IconButton(
                    tooltip: user?.email ?? 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () => ref.read(authControllerProvider).signOut(),
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
