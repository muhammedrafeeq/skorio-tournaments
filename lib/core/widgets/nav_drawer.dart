import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../theme/color_scheme.dart';
import '../theme/text_styles.dart';

class NavDrawer extends ConsumerWidget {
  final String activeTab;
  const NavDrawer({super.key, required this.activeTab});

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.value;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 16,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F19), Color(0xFF05050A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            left: BorderSide(color: Colors.white12, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Logo & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/skorio-logo.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.sports_soccer,
                                  color: SkorioColors.primary, size: 30),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SKORIO',
                        style: SkorioTextStyles.labelMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // User profile info block
              if (user != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha:0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withValues(alpha:0.3),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(user.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: SkorioTextStyles.labelMd.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.role == 'admin' ? 'ADMIN STAFF' : 'COMPETITOR',
                              style: SkorioTextStyles.labelSm.copyWith(
                                color: Colors.white30,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Navigation menu links
              Text(
                'NAVIGATION',
                style: SkorioTextStyles.labelSm.copyWith(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              _DrawerLinkButton(
                label: 'Contests Dashboard',
                icon: Icons.emoji_events_outlined,
                isActive: activeTab == 'contests',
                onTap: () { Navigator.of(context).pop(); context.go('/'); },
              ),
              _DrawerLinkButton(
                label: 'Community',
                icon: Icons.groups_outlined,
                isActive: activeTab == 'community',
                onTap: () { Navigator.of(context).pop(); context.go('/community'); },
              ),
              _DrawerLinkButton(
                label: 'My Profile',
                icon: Icons.person_outline,
                isActive: activeTab == 'profile',
                onTap: () { Navigator.of(context).pop(); context.go('/profile'); },
              ),
              _DrawerLinkButton(
                label: 'Daily Streak',
                icon: Icons.local_fire_department_outlined,
                color: const Color(0xFFFF6B35),
                isActive: activeTab == 'streak',
                onTap: () { Navigator.of(context).pop(); context.push('/streak'); },
              ),
              _DrawerLinkButton(
                label: 'Weekly Report Card',
                icon: Icons.bar_chart_outlined,
                color: const Color(0xFF43DF9E),
                onTap: () { Navigator.of(context).pop(); context.push('/report-card'); },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white12, height: 1),
              ),

              Text(
                'INFORMATION',
                style: SkorioTextStyles.labelSm.copyWith(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              _DrawerLinkButton(
                label: 'Privacy Policy',
                icon: Icons.description_outlined,
                color: Colors.purple[300],
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              _DrawerLinkButton(
                label: 'Terms & Conditions',
                icon: Icons.policy_outlined,
                color: Colors.blue[300],
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              _DrawerLinkButton(
                label: 'Contact Us',
                icon: Icons.mail_outline,
                color: Colors.amber[300],
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),

              const Spacer(),

              // Sign Out button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.redAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha:0.06),
                    side: BorderSide(color: Colors.red.withValues(alpha:0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerLinkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerLinkButton({
    required this.label,
    required this.icon,
    this.isActive = false,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? SkorioColors.primary : Colors.white70;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? SkorioColors.primary.withValues(alpha:0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? SkorioColors.primary
                    : (color ?? Colors.white54),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: SkorioTextStyles.labelSm.copyWith(
                  color: textColor,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
