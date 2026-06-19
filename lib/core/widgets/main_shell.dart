import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/color_scheme.dart';
import '../services/offline_sync_service.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/tournaments/dashboard')) return 0;
    if (loc.startsWith('/tournaments/teams')) return 2;
    if (loc.startsWith('/tournaments') &&
        !loc.startsWith('/tournaments/dashboard') &&
        !loc.startsWith('/tournaments/teams')) return 1;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _currentIndex(context);
    final syncState = ref.watch(offlineSyncProvider);
    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Column(
        children: [
          if (!syncState.isOnline)
            Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    const Text('Offline — changes will sync when reconnected',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else if (syncState.isSyncing)
            Container(
              width: double.infinity,
              color: SkorioColors.secondary.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: SkorioColors.secondary)),
                  const SizedBox(width: 8),
                  Text('Syncing ${syncState.pendingCount} change${syncState.pendingCount != 1 ? "s" : ""}…',
                      style: const TextStyle(color: SkorioColors.secondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _BottomNav(currentIndex: idx),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final activeColor = SkorioColors.secondary;

    final items = [
      _TabItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', () => context.go('/tournaments/dashboard')),
      _TabItem(Icons.emoji_events_outlined, Icons.emoji_events, 'Tournaments', () => context.go('/tournaments')),
      _TabItem(Icons.groups_outlined, Icons.groups, 'Teams', () => context.go('/tournaments/teams')),
      _TabItem(Icons.person_outline, Icons.person, 'Profile', () => context.go('/profile')),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131318).withValues(alpha: 0.85),
            border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = currentIndex == i;
                  final color = isActive ? activeColor : SkorioColors.outline;
                  return Expanded(
                    child: GestureDetector(
                      onTap: item.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              key: ValueKey(isActive),
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: color,
                            ),
                            child: Text(item.label),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  const _TabItem(this.icon, this.activeIcon, this.label, this.onTap);
}
