import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/widgets/pitch_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/auth_provider.dart';

class PointsShopScreen extends ConsumerStatefulWidget {
  const PointsShopScreen({super.key});

  @override
  ConsumerState<PointsShopScreen> createState() => _PointsShopScreenState();
}

class _PointsShopScreenState extends ConsumerState<PointsShopScreen> {
  bool _isProcessing = false;
  Timer? _countdownTimer;
  Duration _xpBoostRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final user = ref.read(authProvider).value;
      if (user != null && user.xpBoostExpiresAt != null) {
        final remaining = user.xpBoostExpiresAt!.difference(DateTime.now());
        if (remaining.isNegative) {
          setState(() {
            _xpBoostRemaining = Duration.zero;
          });
        } else {
          setState(() {
            _xpBoostRemaining = remaining;
          });
        }
      } else {
        if (_xpBoostRemaining != Duration.zero) {
          setState(() {
            _xpBoostRemaining = Duration.zero;
          });
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00:00:00";
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  Future<void> _purchaseItem({
    required String title,
    required int cost,
    required Future<bool> Function() action,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    if (user.points < cost) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Insufficient points! You need $cost points for this purchase."),
          backgroundColor: SkorioColors.errorContainer,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13131F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          "Confirm Purchase",
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          "Are you sure you want to purchase $title for $cost points?",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SkorioColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              "Confirm",
              style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await action();

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  "Successfully purchased $title!",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: SkorioColors.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Purchase failed. Please try again."),
            backgroundColor: SkorioColors.errorContainer,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value;

    if (user == null) {
      return const Scaffold(
        backgroundColor: SkorioColors.baseBg,
        body: Center(
          child: CircularProgressIndicator(color: SkorioColors.primary),
        ),
      );
    }

    final isXpBoostActive = user.xpBoostExpiresAt != null && DateTime.now().isBefore(user.xpBoostExpiresAt!);

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient glowing backdrops
          Positioned(
            top: 60,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.04),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.amber.withOpacity(0.04)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AppBar Header
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
                        'POINTS SHOP',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 60),
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
                        // 1. Points Balance Card
                        StaggeredEntrance(
                          delay: Duration.zero,
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.amber.withOpacity(0.12),
                                    border: Border.all(color: Colors.amber.withOpacity(0.35)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.15),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YOUR POINTS BALANCE',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white30,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${user.points}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PTS',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white30,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Active Boost Status Bar (if any)
                        if (isXpBoostActive)
                          StaggeredEntrance(
                            delay: const Duration(milliseconds: 50),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF047857).withOpacity(0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF059669).withOpacity(0.08),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt, color: Colors.tealAccent, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '2X XP BOOST ACTIVE',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'All XP rewards are doubled',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_xpBoostRemaining),
                                    style: GoogleFonts.outfit(
                                      color: Colors.tealAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: [const FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (isXpBoostActive) const SizedBox(height: 24),

                        // 3. Shop Items Header
                        Text(
                          'GAME UTILITY ITEMS',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Utility items grid list
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                          children: [
                            _buildShopItemCard(
                              title: "Prediction Lifeline",
                              desc: "Reveal the percentage breakdown of community predictions.",
                              cost: 100,
                              icon: Icons.lightbulb_outline,
                              color: Colors.amberAccent,
                              ownedLabel: "${user.lifelinesCount} owned",
                              action: () => _purchaseItem(
                                title: "Prediction Lifeline",
                                cost: 100,
                                action: ref.read(authProvider.notifier).buyLifeline,
                              ),
                            ),
                            _buildShopItemCard(
                              title: "24h XP Boost",
                              desc: "Double all XP earned from mini-games and predictions for 24 hours.",
                              cost: 150,
                              icon: Icons.offline_bolt_outlined,
                              color: Colors.tealAccent,
                              ownedLabel: isXpBoostActive ? "Active" : "Ready to activate",
                              action: () => _purchaseItem(
                                title: "24h XP Boost",
                                cost: 150,
                                action: ref.read(authProvider.notifier).buyXpBoost,
                              ),
                            ),
                            _buildShopItemCard(
                              title: "Extra Game Ticket",
                              desc: "Reset the play count of any game to play beyond the daily limit.",
                              cost: 50,
                              icon: Icons.confirmation_number_outlined,
                              color: Colors.lightBlueAccent,
                              ownedLabel: "${user.extraTickets} owned",
                              action: () => _purchaseItem(
                                title: "Extra Game Ticket",
                                cost: 50,
                                action: ref.read(authProvider.notifier).buyExtraTicket,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // 4. Cosmetic Customisation Header
                        Text(
                          'PROFILE COSMETIC BORDERS',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Borders List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableBorders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final border = _availableBorders[index];
                            final isUnlocked = user.unlockedBorders.contains(border['id']);
                            final isEquipped = user.activeBorder == border['id'];

                            return GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Preview Indicator
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.02),
                                      border: Border.all(
                                        color: border['color'] as Color,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (border['color'] as Color).withOpacity(0.25),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.portrait, color: Colors.white70, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          border['name'] as String,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          border['desc'] as String,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white38,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Action Button
                                  _isProcessing
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(SkorioColors.primary),
                                          ),
                                        )
                                      : !isUnlocked
                                          ? ElevatedButton(
                                              onPressed: () => _purchaseItem(
                                                title: border['name'] as String,
                                                cost: border['cost'] as int,
                                                action: () => ref.read(authProvider.notifier).buyBorder(border['id'] as String, border['cost'] as int),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E293B),
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Colors.white10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${border['cost']}',
                                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : OutlinedButton(
                                              onPressed: isEquipped
                                                  ? null
                                                  : () async {
                                                      setState(() => _isProcessing = true);
                                                      await ref.read(authProvider.notifier).equipBorder(border['id'] as String);
                                                      if (mounted) setState(() => _isProcessing = false);
                                                    },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: isEquipped ? Colors.white24 : SkorioColors.primary),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              ),
                                              child: Text(
                                                isEquipped ? 'EQUIPPED' : 'EQUIP',
                                                style: GoogleFonts.outfit(
                                                  color: isEquipped ? Colors.white30 : SkorioColors.primary,
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: SkorioColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard({
    required String title,
    required String desc,
    required int cost,
    required IconData icon,
    required Color color,
    required String ownedLabel,
    required VoidCallback action,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Expanded(
            child: Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 9.5,
                height: 1.3,
              ),
            ),
          ),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ownedLabel,
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '$cost',
                    style: GoogleFonts.outfit(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Buy Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : action,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.12),
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.35)),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                "BUY",
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _availableBorders = [
    {
      'id': 'neon_blue',
      'name': 'Neon Blue Border',
      'desc': 'High-contrast glowing cyan border overlay.',
      'cost': 200,
      'color': Colors.cyanAccent,
    },
    {
      'id': 'royal_purple',
      'name': 'Royal Purple Border',
      'desc': 'Pulsing premium violet aura.',
      'cost': 300,
      'color': Colors.purpleAccent,
    },
    {
      'id': 'golden_champion',
      'name': 'Golden Champion Border',
      'desc': 'Shining gold gradient outline with sparkles.',
      'cost': 500,
      'color': Colors.amberAccent,
    },
  ];
}
