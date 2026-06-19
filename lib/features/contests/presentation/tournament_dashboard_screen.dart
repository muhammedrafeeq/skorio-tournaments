import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pitch_background.dart';
import '../../../core/widgets/nav_drawer.dart';
import '../../../core/widgets/top_bar.dart';
import '../../../core/widgets/animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../providers/tournaments_provider.dart';
import '../../auth/providers/auth_provider.dart';

class TournamentDashboardScreen extends ConsumerStatefulWidget {
  const TournamentDashboardScreen({super.key});

  @override
  ConsumerState<TournamentDashboardScreen> createState() => _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState extends ConsumerState<TournamentDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _showScheduleMatchDialog(BuildContext context, Tournament tournament) {
    if (tournament.teams.isEmpty) return;

    TournamentTeam? selectedHome = tournament.teams[0];
    TournamentTeam? selectedAway = tournament.teams.length > 1 ? tournament.teams[1] : tournament.teams[0];
    final venueController = TextEditingController(text: "Stadium Pitch A");
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131318),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              title: Text(
                "Schedule Match",
                style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Home Team"),
                    _buildDropdown<TournamentTeam>(
                      value: selectedHome,
                      items: tournament.teams,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedHome = val);
                        }
                      },
                      itemBuilder: (t) => Row(children: [Text(t.logoUrl), const SizedBox(width: 8), Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 15))]),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Away Team"),
                    _buildDropdown<TournamentTeam>(
                      value: selectedAway,
                      items: tournament.teams,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedAway = val);
                        }
                      },
                      itemBuilder: (t) => Row(children: [Text(t.logoUrl), const SizedBox(width: 8), Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 15))]),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Venue"),
                    _buildTextField(venueController, "e.g., Stadium Pitch A"),
                    const SizedBox(height: 12),
                    _buildLabel("Match Date"),
                    GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          setDialogState(() => selectedDate = pickedDate);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.calendar_month, color: SkorioColors.secondary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedHome == null || selectedAway == null) return;
                    if (selectedHome!.id == selectedAway!.id) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Home and Away teams must be different")),
                      );
                      return;
                    }

                    final newMatch = TournamentMatch(
                      id: 'match_manual_${DateTime.now().millisecondsSinceEpoch}',
                      homeTeamId: selectedHome!.id,
                      awayTeamId: selectedAway!.id,
                      date: selectedDate,
                      status: 'scheduled',
                      venue: venueController.text.trim(),
                    );

                    final updatedMatches = [...tournament.matches, newMatch];
                    final updatedTournament = tournament.copyWith(matches: updatedMatches);

                    // Update tournament state
                    try {
                      final client = sb.Supabase.instance.client;
                      await client
                          .from('tournaments')
                          .update(updatedTournament.toJson())
                          .eq('id', tournament.id);
                    } catch (e) {
                      debugPrint("Failed to update fixtures database: $e");
                    }

                    // Force trigger local state reload
                    await ref.read(tournamentsProvider.notifier).loadTournaments();

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Match scheduled successfully!"),
                          backgroundColor: SkorioColors.onSecondaryContainer,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SkorioColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("SCHEDULE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required Widget Function(T) itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF131318),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white30),
          isExpanded: true,
          onChanged: onChanged,
          items: items.map((t) => DropdownMenuItem(value: t, child: itemBuilder(t))).toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white54, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tournamentsProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SkorioColors.baseBg,
      appBar: TopBar(scaffoldKey: _scaffoldKey, activeTab: 'dashboard'),
      endDrawer: const NavDrawer(activeTab: 'dashboard'),
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient Background Glows
          Positioned(
            top: 40,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.secondary.withValues(alpha: 0.03),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: SkorioColors.secondary.withValues(alpha: 0.03)),
              ),
            ),
          ),

          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: SkorioColors.secondary),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dashboard Title
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 50),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOURNAMENT HUB 🏟️",
                                style: SkorioTextStyles.labelMd.copyWith(
                                  color: SkorioColors.secondary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Run local leagues, cups, standings, and match scores.",
                                style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 1. Quick Actions Row
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 100),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  label: "CREATE TOURNAMENT",
                                  icon: Icons.add_box_outlined,
                                  onTap: () => context.push('/tournaments/create'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  label: "SCHEDULE FIXTURE",
                                  icon: Icons.calendar_month_outlined,
                                  onTap: () {
                                    if (state.tournaments.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Create a tournament first")),
                                      );
                                      return;
                                    }
                                    _showScheduleMatchDialog(context, state.tournaments[0]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. Followed Tournaments Title
                        StaggeredEntrance(
                          delay: const Duration(milliseconds: 150),
                          child: Text(
                            "ACTIVE TOURNAMENTS",
                            style: SkorioTextStyles.labelMd.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        state.tournaments.isEmpty
                            ? _buildEmptyDashboardState(context)
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.tournaments.length,
                                itemBuilder: (context, idx) {
                                  final tour = state.tournaments[idx];
                                  return StaggeredEntrance(
                                    delay: Duration(milliseconds: 200 + (idx * 50)),
                                    child: _buildTournamentListItem(context, tour),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        borderColor: SkorioColors.secondary.withValues(alpha: 0.08),
        child: Column(
          children: [
            Icon(icon, color: SkorioColors.secondary, size: 24),
            const SizedBox(height: 10),
            Text(
              label,
              style: SkorioTextStyles.labelSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDashboardState(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            Text(
              "No Tournaments Found",
              style: SkorioTextStyles.labelMd.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              "Publish your first league or cup to get started.",
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/tournaments/create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("CREATE NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentListItem(BuildContext context, Tournament tour) {
    final liveMatches = tour.matches.where((m) => m.status == 'live').length;
    final scheduledMatches = tour.matches.where((m) => m.status == 'scheduled').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/tournaments/${tour.id}'),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: SkorioColors.secondary.withValues(alpha: 0.1),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SkorioColors.secondary.withValues(alpha: 0.1),
                  border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.emoji_events, color: SkorioColors.secondary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour.name,
                      style: SkorioTextStyles.labelMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${tour.sport.toUpperCase()} · ${tour.teams.length} Teams · ${tour.location}",
                      style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (liveMatches > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    "LIVE",
                    style: SkorioTextStyles.labelSm.copyWith(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (scheduledMatches > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SkorioColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    "$scheduledMatches FIX",
                    style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "DONE",
                    style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}
