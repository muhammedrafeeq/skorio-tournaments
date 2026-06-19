import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/pitch_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/auth_provider.dart';
import '../providers/achievements_provider.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../contests/providers/tournaments_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Map<String, dynamic>> _xpLogs = [];
  bool _isLoadingLogs = true;

  final List<Map<String, dynamic>> _milestones = [
    {'level': 5, 'title': 'Grey Card Border', 'desc': 'Unlocks grey border customisation for squad cards', 'icon': Icons.portrait_outlined},
    {'level': 10, 'title': 'Bronze Predictor Badge', 'desc': 'Unlocks Bronze theme and badge on profile', 'icon': Icons.workspace_premium_outlined},
    {'level': 15, 'title': 'Blue Card Border', 'desc': 'Unlocks blue border customisation for squad cards', 'icon': Icons.portrait_outlined},
    {'level': 20, 'title': 'Silver Predictor & Leagues', 'desc': 'Unlocks Silver badge and custom private leagues', 'icon': Icons.stars_outlined},
    {'level': 25, 'title': 'Purple Card Border', 'desc': 'Unlocks purple border customisation for squad cards', 'icon': Icons.portrait_outlined},
    {'level': 30, 'title': 'Gold Predictor Badge', 'desc': 'Unlocks Gold profile theme and special badges', 'icon': Icons.workspace_premium_rounded},
    {'level': 35, 'title': 'Premium Avatar Frame', 'desc': 'Unlocks customizable glowing profile frames', 'icon': Icons.face_retouching_natural_outlined},
    {'level': 40, 'title': 'Platinum Predictor Badge', 'desc': 'Unlocks Platinum theme with extra UI animations', 'icon': Icons.workspace_premium_rounded},
    {'level': 45, 'title': 'Elite League Access', 'desc': 'Unlocks entry into the Elite Competitors tournament', 'icon': Icons.emoji_events_outlined},
    {'level': 50, 'title': 'Legendary Predictor & Golden Border', 'desc': 'Ultimate badge, special sound effects, and gold card border', 'icon': Icons.emoji_events_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchXpLogs();
  }

  Future<void> _fetchXpLogs() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final client = sb.Supabase.instance.client;
      final response = await client
          .from('xp_log')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);
      
      if (mounted) {
        setState(() {
          _xpLogs = List<Map<String, dynamic>>.from(response);
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch XP logs, using mock logs: $e");
      if (mounted) {
        setState(() {
          _xpLogs = [
            {'action': 'Submit Prediction', 'amount': 10, 'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
            {'action': 'Flag Quiz Correct Flags', 'amount': 15, 'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
            {'action': 'Who Am I Game Played', 'amount': 10, 'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
            {'action': 'Trivia Correct Answers', 'amount': 40, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
            {'action': 'Daily Login', 'amount': 5, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
          ];
          _isLoadingLogs = false;
        });
      }
    }
  }

  // String _getInitials(String name) {
  //   if (name.isEmpty) return "U";
  //   final parts = name.trim().split(RegExp(r'\s+'));
  //   if (parts.length >= 2) {
  //     return (parts[0][0] + parts[1][0]).toUpperCase();
  //   }
  //   return name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase();
  // }

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value;
    final achievementsState = ref.watch(achievementsProvider);
    final isTournament = ref.watch(appModeProvider).mode == AppMode.tournament;

    if (user == null) {
      return const Scaffold(
        backgroundColor: SkorioColors.baseBg,
        body: Center(
          child: CircularProgressIndicator(color: SkorioColors.primary),
        ),
      );
    }

    if (isTournament) {
      return _buildTournamentProfile(context, user);
    }

    final xpInCurrentLevel = user.xp % 100;
    final progress = xpInCurrentLevel / 100.0;

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient glowing backdrops
          Positioned(
            top: 40,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.primary.withValues(alpha:0.04),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: SkorioColors.primary.withValues(alpha:0.04)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Custom Page Header (AppBar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MY ATHLETE PROFILE',
                        style: SkorioTextStyles.labelMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_outlined, color: SkorioColors.primary, size: 22),
                        tooltip: 'Notifications Settings',
                      ),
                      IconButton(
                        onPressed: () => context.push('/points-shop'),
                        icon: const Icon(Icons.shopping_bag_outlined, color: SkorioColors.primary, size: 22),
                        tooltip: 'Points Shop',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. User Stats Glass Card
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 50),
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Circular Level Indicator
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 84,
                                      height: 84,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 5,
                                        valueColor: const AlwaysStoppedAnimation<Color>(SkorioColors.primary),
                                        backgroundColor: Colors.white.withValues(alpha:0.05),
                                      ),
                                    ),
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF1E1E2C),
                                        border: Border.all(
                                          color: user.activeBorder == 'neon_blue'
                                              ? Colors.cyanAccent
                                              : user.activeBorder == 'royal_purple'
                                                  ? Colors.purpleAccent
                                                  : user.activeBorder == 'golden_champion'
                                                      ? Colors.amberAccent
                                                      : Colors.white10,
                                          width: user.activeBorder != 'none' ? 2.5 : 1.0,
                                        ),
                                        boxShadow: [
                                          if (user.activeBorder == 'neon_blue')
                                            BoxShadow(
                                              color: Colors.cyanAccent.withOpacity(0.35),
                                              blurRadius: 18,
                                              spreadRadius: 1.5,
                                            )
                                          else if (user.activeBorder == 'royal_purple')
                                            BoxShadow(
                                              color: Colors.purpleAccent.withOpacity(0.35),
                                              blurRadius: 18,
                                              spreadRadius: 1.5,
                                            )
                                          else if (user.activeBorder == 'golden_champion')
                                            BoxShadow(
                                              color: Colors.amberAccent.withOpacity(0.4),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            )
                                          else
                                            BoxShadow(
                                              color: SkorioColors.primary.withValues(alpha:0.15),
                                              blurRadius: 15,
                                              spreadRadius: 1,
                                            ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'LEVEL',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white38,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          Text(
                                            '${user.level}',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),

                                // Profile Data
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.role == 'admin' ? 'SYSTEM ADMINISTRATOR' : 'PREDICTION COMPETITOR',
                                        style: SkorioTextStyles.labelSm.copyWith(
                                          color: Colors.white38,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildQuickStat(Icons.sports_score, '${user.points} pts', 'POINTS'),
                                          const SizedBox(width: 24),
                                          _buildQuickStat(Icons.bolt, '${user.xp} XP', 'TOTAL XP'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Linear XP Progress Bar Card
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 100),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'LEVEL PROGRESS',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white30,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        if (user.xpBoostExpiresAt != null &&
                                            DateTime.now().isBefore(user.xpBoostExpiresAt!)) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF064E3B),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF047857).withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              '2X BOOST',
                                              style: GoogleFonts.outfit(
                                                color: Colors.tealAccent,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${xpInCurrentLevel} / 100 XP',
                                      style: GoogleFonts.outfit(
                                        color: SkorioColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    backgroundColor: Colors.white.withValues(alpha:0.04),
                                    valueColor: const AlwaysStoppedAnimation<Color>(SkorioColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Achievements & Badges Grid Section
                        Text(
                          'ACHIEVEMENTS & BADGES',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 110),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: achievementsState.allAchievements.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.95,
                              ),
                              itemBuilder: (context, index) {
                                final ach = achievementsState.allAchievements[index];
                                final unlocked = achievementsState.earnedKeys.contains(ach.key);
                                final badgeColor = _getBadgeColor(ach.key, unlocked);

                                return GestureDetector(
                                  onTap: () => _showAchievementDetail(
                                    ach,
                                    unlocked,
                                    achievementsState.earnedDates[ach.key],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: unlocked ? badgeColor.withOpacity(0.04) : Colors.white.withOpacity(0.01),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: unlocked
                                            ? badgeColor.withOpacity(0.35)
                                            : Colors.white.withOpacity(0.05),
                                        width: 1.5,
                                      ),
                                      boxShadow: unlocked
                                          ? [
                                              BoxShadow(
                                                color: badgeColor.withOpacity(0.08),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _getIconData(ach.iconName),
                                              color: unlocked ? badgeColor : Colors.white24,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Text(
                                                ach.name,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  color: unlocked ? Colors.white : Colors.white38,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!unlocked)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: const Icon(
                                              Icons.lock_outline,
                                              color: Colors.white24,
                                              size: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4. Milestone Roadmaps Header
                        Text(
                          'LEVEL MILESTONE ROADMAP',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Milestone List
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.01),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha:0.03)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _milestones.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                            itemBuilder: (context, index) {
                              final mile = _milestones[index];
                              final unlocked = user.level >= mile['level'];
                              final accentColor = unlocked ? SkorioColors.primary : Colors.white24;

                              return StaggeredEntrance(
                                delay: Duration(milliseconds: 120 + index * 40),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: unlocked ? SkorioColors.primary.withValues(alpha:0.12) : Colors.white.withValues(alpha:0.03),
                                          border: Border.all(color: unlocked ? SkorioColors.primary.withValues(alpha:0.35) : Colors.white10),
                                        ),
                                        child: Icon(
                                          mile['icon'],
                                          color: accentColor,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mile['title'],
                                              style: GoogleFonts.outfit(
                                                color: unlocked ? Colors.white : Colors.white38,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              mile['desc'],
                                              style: GoogleFonts.outfit(
                                                color: Colors.white38,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: unlocked ? const Color(0xFF064E3B) : Colors.white.withValues(alpha:0.02),
                                          borderRadius: BorderRadius.circular(100),
                                          border: Border.all(color: unlocked ? const Color(0xFF047857).withValues(alpha:0.25) : Colors.white10),
                                        ),
                                        child: Text(
                                          unlocked ? 'UNLOCKED' : 'LVL ${mile['level']}',
                                          style: GoogleFonts.outfit(
                                            color: unlocked ? const Color(0xFF34D399) : Colors.white24,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 5. XP Activity Logs
                        Text(
                          'RECENT XP ACTIVITY LOGS',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _isLoadingLogs
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(color: SkorioColors.primary),
                                ),
                              )
                            : GlassCard(
                                padding: const EdgeInsets.all(12),
                                child: _xpLogs.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 20.0),
                                        child: Center(
                                          child: Text(
                                            'No recent activities logged.',
                                            style: TextStyle(color: Colors.white24, fontSize: 12),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _xpLogs.length,
                                        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                                        itemBuilder: (context, index) {
                                          final log = _xpLogs[index];
                                          final amount = log['amount'] ?? 0;
                                          final action = log['action'] ?? 'Unknown Action';
                                          final dateStr = log['created_at'] ?? '';

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      action,
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatTimeAgo(dateStr),
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white30,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0F172A),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                                  ),
                                                  child: Text(
                                                    '+$amount XP',
                                                    style: GoogleFonts.outfit(
                                                      color: SkorioColors.primary,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentProfile(BuildContext context, dynamic user) {
    final initials = () {
      final parts = (user.name as String).trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
      final n = user.name as String;
      return n.substring(0, n.length > 2 ? 2 : n.length).toUpperCase();
    }();

    final settingsItems = [
      _SettingsItem(Icons.language_outlined, 'Change Language', 'English', () {}),
      _SettingsItem(Icons.privacy_tip_outlined, 'Privacy Policy', null, () {}),
      _SettingsItem(Icons.help_outline, 'Help & Support', null, () {}),
      _SettingsItem(Icons.info_outline, 'About Skorio', null, () {}),
    ];

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.secondary.withValues(alpha: 0.05),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: SkorioColors.secondary.withValues(alpha: 0.05)),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // Avatar
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.4), width: 2),
                      boxShadow: [BoxShadow(color: SkorioColors.secondary.withValues(alpha: 0.2), blurRadius: 20)],
                    ),
                    alignment: Alignment.center,
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name.toUpperCase(),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (user.phone as String).isNotEmpty ? user.phone : 'Tournament Organizer',
                    style: SkorioTextStyles.labelSm.copyWith(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: SkorioColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '🏟️ TOURNAMENT MODE',
                      style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.secondary, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Settings section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('SETTINGS', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ...settingsItems.asMap().entries.map((e) {
                          final item = e.value;
                          final isLast = e.key == settingsItems.length - 1;
                          return Column(
                            children: [
                              _buildSettingsRow(item.icon, item.label, item.value, item.onTap, SkorioColors.secondary),
                              if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Referee schedule
                  _buildRefereeSchedule(context, user),

                  // Danger zone
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('ACCOUNT', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: _buildSettingsRow(Icons.logout, 'Log Out', null, () async {
                      await ref.read(authProvider.notifier).logout();
                    }, Colors.redAccent),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefereeSchedule(BuildContext context, user) {
    final tournaments = ref.read(tournamentsProvider).tournaments;
    final refMatches = <({String tournamentName, TournamentMatch match, TournamentTeam home, TournamentTeam away})>[];

    for (final t in tournaments) {
      for (final m in t.matches) {
        if (m.refereeName.toLowerCase() == (user.name as String).toLowerCase() ||
            m.refereeId == user.id) {
          final home = t.teams.firstWhere(
            (te) => te.id == m.homeTeamId,
            orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '❓', primaryColor: '', secondaryColor: '', players: []),
          );
          final away = t.teams.firstWhere(
            (te) => te.id == m.awayTeamId,
            orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '❓', primaryColor: '', secondaryColor: '', players: []),
          );
          refMatches.add((tournamentName: t.name, match: m, home: home, away: away));
        }
      }
    }

    if (refMatches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REFEREE SCHEDULE', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: refMatches.map((entry) {
              final m = entry.match;
              final statusColor = m.status == 'live' ? Colors.red : m.status == 'completed' ? SkorioColors.outline : SkorioColors.secondary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.sports, size: 16, color: SkorioColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.home.name} vs ${entry.away.name}',
                            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            entry.tournamentName,
                            style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.outline, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.status.toUpperCase(),
                        style: SkorioTextStyles.labelSm.copyWith(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingsRow(IconData icon, String label, String? value, VoidCallback onTap, Color iconColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
            if (value != null) ...[
              Text(value, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: SkorioColors.primary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white30,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'schedule':
        return Icons.schedule;
      case 'dark_mode':
        return Icons.dark_mode;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'stars':
        return Icons.stars;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getBadgeColor(String key, bool unlocked) {
    if (!unlocked) return Colors.white38;
    switch (key) {
      case 'perfect_predictor':
        return Colors.amber;
      case 'early_bird':
        return Colors.blueAccent;
      case 'night_owl':
        return Colors.purpleAccent;
      case 'streak_7':
        return Colors.orangeAccent;
      case 'streak_30':
        return Colors.redAccent;
      case 'sportle_master':
        return Colors.tealAccent;
      default:
        return SkorioColors.primary;
    }
  }

  void _showAchievementDetail(Achievement ach, bool unlocked, String? earnedAt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final badgeColor = _getBadgeColor(ach.key, unlocked);
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF13131F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: Colors.white12),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom sheet indicator bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),

              // Glowing Badge Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor.withOpacity(unlocked ? 0.12 : 0.05),
                  border: Border.all(color: badgeColor.withOpacity(unlocked ? 0.4 : 0.1), width: 2),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: badgeColor.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _getIconData(ach.iconName),
                  color: unlocked ? badgeColor : Colors.white24,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Badge Name
              Text(
                ach.name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                ach.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // XP Reward indicator / Unlocked date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REWARD',
                      style: GoogleFonts.outfit(
                        color: Colors.white30,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '+${ach.xpReward} XP',
                      style: GoogleFonts.outfit(
                        color: SkorioColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (unlocked && earnedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Unlocked on ${_formatDate(earnedAt)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _SettingsItem(this.icon, this.label, this.value, this.onTap);
}
