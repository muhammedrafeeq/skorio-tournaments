import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pitch_background.dart';
import '../providers/tournaments_provider.dart';
import '../providers/career_stats_provider.dart';
import '../services/match_sheet_pdf.dart';
import '../../auth/providers/auth_provider.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _ensureTabController(bool hasBracket) {
    final expectedLength = hasBracket ? 5 : 4;
    if (_tabController.length != expectedLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: expectedLength,
        vsync: this,
        initialIndex: oldIndex < expectedLength ? oldIndex : 0,
      );
    }
  }

  void _showAssignRefereeSheet(BuildContext context, TournamentMatch match, Tournament tournament) {
    final nameController = TextEditingController(text: match.refereeName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Assign Referee', style: SkorioTextStyles.headlineMd),
              const SizedBox(height: 4),
              Text('${tournament.teams.firstWhere((t) => t.id == match.homeTeamId, orElse: () => TournamentTeam(id:'',name:'TBD',logoUrl:'',primaryColor:'',secondaryColor:'',players:[])).name} vs ${tournament.teams.firstWhere((t) => t.id == match.awayTeamId, orElse: () => TournamentTeam(id:'',name:'TBD',logoUrl:'',primaryColor:'',secondaryColor:'',players:[])).name}',
                style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Referee Name',
                  prefixIcon: const Icon(Icons.sports),
                  filled: true,
                  fillColor: SkorioColors.surfaceBright,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (match.refereeName.isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ref.read(tournamentsProvider.notifier).assignReferee(
                            tournament.id, match.id, refereeId: '', refereeName: '',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SkorioColors.errorContainer),
                          foregroundColor: SkorioColors.errorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  if (match.refereeName.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        await ref.read(tournamentsProvider.notifier).assignReferee(
                          tournament.id, match.id, refereeId: name.toLowerCase().replaceAll(' ', '_'), refereeName: name,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: SkorioColors.secondary,
                        foregroundColor: SkorioColors.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLineupSheet(BuildContext context, TournamentMatch match, Tournament tournament) {
    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentMatch = ref.read(tournamentsProvider).tournaments
                .firstWhere((t) => t.id == tournament.id, orElse: () => tournament)
                .matches.firstWhere((m) => m.id == match.id, orElse: () => match);

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text('Match Lineups', style: SkorioTextStyles.headlineMd),
                      const SizedBox(height: 4),
                      Text('${homeTeam.name} vs ${awayTeam.name}',
                        style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      for (final team in [homeTeam, awayTeam]) ...[
                        _buildLineupSection(ctx, currentMatch, tournament, team, setModalState),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLineupSection(BuildContext ctx, TournamentMatch match, Tournament tournament,
      TournamentTeam team, StateSetter setModalState) {
    final existing = match.lineups.firstWhere(
      (l) => l.teamId == team.id,
      orElse: () => MatchLineup(teamId: team.id, startingXI: [], substitutes: [], formation: '4-4-2', submittedAt: DateTime.now()),
    );
    final hasLineup = match.lineups.any((l) => l.teamId == team.id);
    final formationCtrl = TextEditingController(text: existing.formation);
    final startingCtrl = TextEditingController(text: existing.startingXI.join(', '));
    final subsCtrl = TextEditingController(text: existing.substitutes.join(', '));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasLineup ? SkorioColors.secondary.withValues(alpha: 0.3) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${team.logoUrl} ${team.name}',
                style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (hasLineup)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SkorioColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SUBMITTED', style: TextStyle(color: SkorioColors.secondary, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _lineupField(formationCtrl, 'Formation (e.g. 4-3-3)', Icons.grid_view),
          const SizedBox(height: 8),
          _lineupField(startingCtrl, 'Starting XI (comma-separated names)', Icons.sports_soccer),
          const SizedBox(height: 8),
          _lineupField(subsCtrl, 'Substitutes (comma-separated)', Icons.swap_horiz),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                foregroundColor: SkorioColors.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final lineup = MatchLineup(
                  teamId: team.id,
                  startingXI: startingCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  substitutes: subsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  formation: formationCtrl.text.trim().isEmpty ? '4-4-2' : formationCtrl.text.trim(),
                  submittedAt: DateTime.now(),
                );
                await ref.read(tournamentsProvider.notifier).submitLineup(tournament.id, match.id, lineup);
                setModalState(() {});
              },
              child: Text(hasLineup ? 'Update Lineup' : 'Submit Lineup',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineupField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 16),
        filled: true,
        fillColor: SkorioColors.surfaceBright,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _showH2HPicker(BuildContext context, Tournament tournament, TournamentTeam teamA) {
    final rivals = tournament.teams.where((t) => t.id != teamA.id).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('${teamA.logoUrl} ${teamA.name} — pick rival', style: SkorioTextStyles.headlineMd),
            const SizedBox(height: 4),
            Text('Long-press any team to compare head-to-head.',
              style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            ...rivals.map((teamB) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(teamB.logoUrl, style: const TextStyle(fontSize: 24)),
              title: Text(teamB.name, style: SkorioTextStyles.labelMd.copyWith(color: Colors.white)),
              trailing: const Icon(Icons.compare_arrows, color: SkorioColors.secondary, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/tournaments/${tournament.id}/h2h/${teamA.id}/${teamB.id}');
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPostponeSheet(BuildContext context, TournamentMatch match, Tournament tournament) {
    DateTime selectedDate = match.date.add(const Duration(days: 7));
    final reasonController = TextEditingController();

    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text('Postpone Match', style: SkorioTextStyles.headlineMd),
                  const SizedBox(height: 4),
                  Text('${homeTeam.name} vs ${awayTeam.name}',
                    style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                  if (match.postponements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rescheduling History', style: SkorioTextStyles.labelSm.copyWith(color: Colors.orange, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          ...match.postponements.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${_fmtDate(p.originalDate)} → ${_fmtDate(p.newDate)}: ${p.reason}',
                              style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant, fontSize: 11),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: SkorioColors.surfaceBright,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: SkorioColors.secondary),
                          const SizedBox(width: 12),
                          Text('New Date: ${_fmtDate(selectedDate)}',
                            style: SkorioTextStyles.labelMd.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason (e.g. weather, field unavailable)',
                      prefixIcon: const Icon(Icons.info_outline),
                      filled: true,
                      fillColor: SkorioColors.surfaceBright,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await ref.read(tournamentsProvider.notifier).postponeMatch(
                          tournament.id, match.id,
                          newDate: selectedDate,
                          reason: reasonController.text.trim().isEmpty ? 'No reason given' : reasonController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Confirm Postponement', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showResultEntryDialog(BuildContext context, TournamentMatch match, Tournament tournament) {
    final homeController = TextEditingController(text: match.homeScore.toString());
    final awayController = TextEditingController(text: match.awayScore.toString());
    final scorersController = TextEditingController(text: match.scorers.join(', '));
    final cardsController = TextEditingController(text: match.cards.join(', '));
    final motmController = TextEditingController(text: match.motm ?? '');

    final homeTeam = tournament.teams.firstWhere((t) => t.id == match.homeTeamId);
    final awayTeam = tournament.teams.firstWhere((t) => t.id == match.awayTeamId);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131318),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            "Enter Result",
            style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(homeTeam.logoUrl, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(homeTeam.name, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          _buildNumberField(homeController),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("VS", style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(awayTeam.logoUrl, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(awayTeam.name, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          _buildNumberField(awayController),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel("Scorers (comma separated player names)"),
                _buildTextField(scorersController, "e.g., Alex Thorne, Chris Evans"),
                const SizedBox(height: 12),
                _buildLabel("Cards (comma separated name:Yellow/Red)"),
                _buildTextField(cardsController, "e.g., Marcus Fox:Yellow, Tom Hardy:Red"),
                const SizedBox(height: 12),
                _buildLabel("Man of the Match"),
                _buildTextField(motmController, "e.g., Alex Thorne"),
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
                final hScore = int.tryParse(homeController.text.trim()) ?? 0;
                final aScore = int.tryParse(awayController.text.trim()) ?? 0;
                final scorers = scorersController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                final cards = cardsController.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
                final motm = motmController.text.trim().isEmpty ? null : motmController.text.trim();

                await ref.read(tournamentsProvider.notifier).updateMatchResult(
                      tournament.id,
                      match.id,
                      hScore,
                      aScore,
                      scorers: scorers,
                      cards: cards,
                      motm: motm,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Match results updated and standings recalculated!"),
                      backgroundColor: SkorioColors.onSecondaryContainer,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddFixtureDialog(BuildContext context, Tournament tournament) {
    String? homeTeamId;
    String? awayTeamId;
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));
    String phase = '';
    final venueCtrl = TextEditingController();

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
                "Add Fixture",
                style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Home Team"),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButton<String?>(
                        value: homeTeamId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF131318),
                        hint: const Text("Select home team", style: TextStyle(color: Colors.white38, fontSize: 15)),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        underline: Container(height: 1, color: Colors.white12),
                        onChanged: (v) => setDialogState(() => homeTeamId = v),
                        items: tournament.teams.map((team) => DropdownMenuItem<String?>(
                          value: team.id,
                          child: Text('${team.logoUrl} ${team.name}'),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Away Team"),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButton<String?>(
                        value: awayTeamId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF131318),
                        hint: const Text("Select away team", style: TextStyle(color: Colors.white38, fontSize: 15)),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        underline: Container(height: 1, color: Colors.white12),
                        onChanged: (v) => setDialogState(() => awayTeamId = v),
                        items: tournament.teams.map((team) => DropdownMenuItem<String?>(
                          value: team.id,
                          child: Text('${team.logoUrl} ${team.name}'),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Venue"),
                    TextField(
                      controller: venueCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "e.g. Main Ground - Pitch A",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Match Date"),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: scheduledDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(scheduledDate),
                        );
                        setDialogState(() {
                          scheduledDate = DateTime(
                            date.year, date.month, date.day,
                            time?.hour ?? scheduledDate.hour,
                            time?.minute ?? scheduledDate.minute,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: Colors.white54, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}  ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel("Phase"),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButton<String>(
                        value: phase,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF131318),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        underline: Container(height: 1, color: Colors.white12),
                        onChanged: (v) => setDialogState(() => phase = v ?? ''),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('League')),
                          DropdownMenuItem(value: 'r16', child: Text('Round of 16')),
                          DropdownMenuItem(value: 'qf', child: Text('Quarter Final')),
                          DropdownMenuItem(value: 'sf', child: Text('Semifinal')),
                          DropdownMenuItem(value: 'final', child: Text('Final')),
                          DropdownMenuItem(value: 'third', child: Text('3rd Place')),
                        ],
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
                  onPressed: () {
                    if (homeTeamId == null || awayTeamId == null || homeTeamId == awayTeamId) return;
                    final newMatch = TournamentMatch(
                      id: 'match_${DateTime.now().millisecondsSinceEpoch}',
                      homeTeamId: homeTeamId!,
                      awayTeamId: awayTeamId!,
                      date: scheduledDate,
                      status: 'scheduled',
                      venue: venueCtrl.text.trim().isEmpty ? 'TBD' : venueCtrl.text.trim(),
                      phase: phase,
                      groupId: '',
                    );
                    ref.read(tournamentsProvider.notifier).addMatchToTournament(tournament.id, newMatch);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SkorioColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("ADD FIXTURE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNumberField(TextEditingController controller) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white54, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tournamentsProvider);
    final tIdx = state.tournaments.indexWhere((t) => t.id == widget.tournamentId);

    if (tIdx == -1) {
      return Scaffold(
        backgroundColor: SkorioColors.baseBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Tournament not found", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.pop(), child: const Text("Go Back")),
            ],
          ),
        ),
      );
    }

    final tournament = state.tournaments[tIdx];
    final currentUser = ref.watch(authProvider).value;
    final isCreator = currentUser != null && tournament.creatorId == currentUser.id;
    final hasBracket = tournament.format == 'knockout' || tournament.format == 'group_knockout';
    _ensureTabController(hasBracket);

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient Background Glows
          Positioned(
            top: 40,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.secondary.withValues(alpha: 0.03),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: SkorioColors.secondary.withValues(alpha: 0.03)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildHeader(context, tournament),

                // Sub-tabs Selector
                _buildSubTabs(hasBracket),

                // Sub-tabs Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStandingsTab(tournament),
                      _buildFixturesTab(tournament, isCreator: isCreator),
                      _buildTeamsTab(tournament, isCreator: isCreator),
                      _buildStatsTab(tournament),
                      if (hasBracket) _buildBracketTab(tournament, isCreator: isCreator),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Tournament tournament) {
    final currentUser = ref.watch(authProvider).value;
    final isCreator = currentUser != null && tournament.creatorId == currentUser.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.name.toUpperCase(),
                  style: SkorioTextStyles.labelMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  "${tournament.sport.toUpperCase()} · ${tournament.location}",
                  style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCreator)
            IconButton(
              tooltip: 'Manage Co-Admins',
              icon: const Icon(Icons.supervisor_account_rounded, color: Colors.white54, size: 20),
              onPressed: () => _showCoAdminSheet(context, tournament),
            ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white54, size: 20),
            onPressed: () {
              final inviteCode = tournament.inviteCode.isNotEmpty ? '\nInvite Code: ${tournament.inviteCode}' : '';
              final text = '🏆 ${tournament.name}\n'
                  '${tournament.sport.toUpperCase()} · ${tournament.location}\n'
                  '${tournament.teams.length} teams · ${tournament.format.toUpperCase()} format$inviteCode\n\n'
                  'Follow on Skorio 📲';
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
        ],
      ),
    );
  }

  void _showCoAdminSheet(BuildContext context, Tournament tournament) {
    final userIdController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final t = ref.read(tournamentsProvider).tournaments.firstWhere(
              (x) => x.id == tournament.id, orElse: () => tournament);
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Co-Admin Management', style: SkorioTextStyles.headlineMd),
                  const SizedBox(height: 4),
                  Text('Co-admins can record results, manage fixtures, and assign referees.',
                    style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  if (t.coAdminIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No co-admins yet.', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30)),
                    )
                  else
                    ...t.coAdminIds.map((id) {
                      final logEntry = t.adminLog.lastWhere(
                        (l) => l.startsWith('$id:co_admin_added'), orElse: () => '');
                      final displayName = logEntry.isNotEmpty ? logEntry.split(':').last : id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, size: 16, color: Colors.white54)),
                        title: Text(displayName, style: SkorioTextStyles.labelMd.copyWith(color: Colors.white)),
                        subtitle: Text(id, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            await ref.read(tournamentsProvider.notifier).removeCoAdmin(tournament.id, id);
                            setModalState(() {});
                          },
                        ),
                      );
                    }),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      filled: true, fillColor: SkorioColors.surfaceBright,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: userIdController,
                    decoration: InputDecoration(
                      labelText: 'User ID',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true, fillColor: SkorioColors.surfaceBright,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SkorioColors.secondary,
                        foregroundColor: SkorioColors.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final uid = userIdController.text.trim();
                        final name = nameController.text.trim();
                        if (uid.isEmpty) return;
                        await ref.read(tournamentsProvider.notifier).addCoAdmin(tournament.id, uid, name.isEmpty ? uid : name);
                        userIdController.clear(); nameController.clear();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Co-Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubTabs(bool hasBracket) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: SkorioColors.secondary,
        labelColor: SkorioColors.secondary,
        unselectedLabelColor: Colors.white30,
        labelStyle: SkorioTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        isScrollable: hasBracket,
        tabs: [
          const Tab(text: "STANDINGS"),
          const Tab(text: "FIXTURES"),
          const Tab(text: "TEAMS"),
          const Tab(text: "LEADERS"),
          if (hasBracket) const Tab(text: "BRACKET"),
        ],
      ),
    );
  }

  // ─── 1. Standings Tab ────────────────────────────────────────────────────────

  Widget _buildStandingsTab(Tournament tournament) {
    if (tournament.format == 'group_knockout') {
      final groupStandings = ref.watch(tournamentsProvider.notifier).getGroupStandings(tournament.id);
      if (groupStandings.isEmpty) {
        return Center(
          child: Text("No group stage data yet", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24)),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groupStandings.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "GROUP ${entry.key}",
                    style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.secondary, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2),
                  ),
                ),
                _buildStandingsTable(entry.value, tournament),
                const SizedBox(height: 20),
              ],
            );
          }).toList(),
        ),
      );
    }

    final standings = ref.watch(tournamentsProvider.notifier).getStandings(tournament.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildStandingsTable(standings, tournament),
    );
  }

  Widget _buildStandingsTable(List<StandingsRecord> standings, Tournament tournament) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: SkorioColors.secondary.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered, color: SkorioColors.secondary, size: 16),
              const SizedBox(width: 8),
              Text(
                "POINTS TABLE",
                style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Standings Table Header
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text("#   TEAM", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              _buildTableCellHeader("P", 1),
              _buildTableCellHeader("W", 1),
              _buildTableCellHeader("D", 1),
              _buildTableCellHeader("L", 1),
              _buildTableCellHeader("GD", 1.2),
              _buildTableCellHeader("PTS", 1.5, align: Alignment.centerRight),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          // Standings Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: standings.length,
            itemBuilder: (context, idx) {
              final rec = standings[idx];
              return GestureDetector(
                onLongPress: () => _showH2HPicker(context, tournament, rec.team),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Team Name & Rank
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              "${idx + 1}",
                              style: TextStyle(
                                color: idx < 3 ? SkorioColors.secondary : Colors.white24,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(rec.team.logoUrl, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.team.name,
                              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats Columns
                    _buildTableCell("${rec.played}", 1),
                    _buildTableCell("${rec.won}", 1),
                    _buildTableCell("${rec.drawn}", 1),
                    _buildTableCell("${rec.lost}", 1),
                    _buildTableCell("${rec.gd > 0 ? "+" : ""}${rec.gd}", 1.2),
                    _buildTableCell(
                      "${rec.points}",
                      1.5,
                      align: Alignment.centerRight,
                      style: const TextStyle(color: SkorioColors.secondary, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
              ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableCellHeader(String text, double flex, {Alignment align = Alignment.center}) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Container(
        alignment: align,
        child: Text(
          text,
          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, double flex, {Alignment align = Alignment.center, TextStyle? style}) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Container(
        alignment: align,
        child: Text(
          text,
          style: style ?? SkorioTextStyles.labelSm.copyWith(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  // ─── 2. Fixtures Tab ────────────────────────────────────────────────────────

  Widget _buildFixturesTab(Tournament tournament, {required bool isCreator}) {
    return Stack(
      children: [
        if (tournament.matches.isEmpty)
          Center(
            child: Text("No fixtures yet. Tap + to add.", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24)),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tournament.matches.length,
            itemBuilder: (context, idx) {
        final match = tournament.matches[idx];
        final homeTeam = tournament.teams.firstWhere(
          (t) => t.id == match.homeTeamId,
          orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '❓', primaryColor: '0xFF474554', secondaryColor: '0xFF131318', players: []),
        );
        final awayTeam = tournament.teams.firstWhere(
          (t) => t.id == match.awayTeamId,
          orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '❓', primaryColor: '0xFF474554', secondaryColor: '0xFF131318', players: []),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: match.status == 'live' ? SkorioColors.secondary.withValues(alpha: 0.2) : Colors.white12,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      match.venue,
                      style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 9),
                    ),
                    _buildStatusBadge(match.status),
                  ],
                ),
                // Referee row
                if (match.refereeName.isNotEmpty || isCreator) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.sports, size: 12, color: Colors.white24),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          match.refereeName.isNotEmpty ? 'Referee: ${match.refereeName}' : 'No referee assigned',
                          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10),
                        ),
                      ),
                      if (isCreator && match.status == 'scheduled')
                        GestureDetector(
                          onTap: () => _showAssignRefereeSheet(context, match, tournament),
                          child: Text(
                            match.refereeName.isNotEmpty ? 'Change' : 'Assign',
                            style: SkorioTextStyles.labelSm.copyWith(
                              color: SkorioColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Lineup submission row
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.format_list_numbered, size: 12, color: Colors.white24),
                        const SizedBox(width: 6),
                        Text(
                          match.lineups.isEmpty
                              ? 'No lineups submitted'
                              : '${match.lineups.length}/2 lineup${match.lineups.length != 1 ? "s" : ""} submitted',
                          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showLineupSheet(context, match, tournament),
                          child: Text(
                            'View / Submit',
                            style: SkorioTextStyles.labelSm.copyWith(
                              color: SkorioColors.secondary.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Home
                    Expanded(
                      child: Column(
                        children: [
                          Text(homeTeam.logoUrl, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            homeTeam.name,
                            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Score Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match.status == 'completed' ? "${match.homeScore} - ${match.awayScore}" : "VS",
                        style: TextStyle(
                          color: match.status == 'completed' ? SkorioColors.secondary : Colors.white30,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    // Away
                    Expanded(
                      child: Column(
                        children: [
                          Text(awayTeam.logoUrl, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            awayTeam.name,
                            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Scorers
                if (match.status == 'completed' && match.scorers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.01),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_soccer, color: Colors.white24, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            match.scorers.join(', '),
                            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // PDF export for completed matches
                if (match.status == 'completed') ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => MatchSheetPdf.printMatchSheet(tournament, match),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 13, color: Colors.white30),
                          const SizedBox(width: 4),
                          Text('Export Sheet',
                            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
                // Match action buttons
                if (match.status != 'completed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Watch Live button (visible to everyone when match is live)
                      if (match.status == 'live') ...[
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => context.push('/tournaments/${tournament.id}/live/${match.id}'),
                              icon: const Icon(Icons.play_arrow, size: 14),
                              label: Text('WATCH LIVE', style: SkorioTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ),
                        if (isCreator) const SizedBox(width: 8),
                      ],
                      // Admin: Manage Live / Record Result
                      if (isCreator) ...[
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: SkorioColors.secondary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => match.status == 'live'
                                  ? context.push('/tournaments/${tournament.id}/live/${match.id}')
                                  : _showResultEntryDialog(context, match, tournament),
                              child: Text(
                                match.status == 'live' ? 'MANAGE LIVE' : 'RECORD RESULT',
                                style: SkorioTextStyles.labelSm.copyWith(
                                  color: SkorioColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (match.status == 'scheduled' || match.status == 'postponed') ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.orange.withValues(alpha: 0.6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _showPostponeSheet(context, match, tournament),
                              child: Text('POSTPONE',
                                style: SkorioTextStyles.labelSm.copyWith(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => context.push(
                                '/tournaments/${tournament.id}/matches/${match.id}/qr'),
                              child: const Icon(Icons.qr_code, size: 16, color: Colors.white54),
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              height: 32,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                onPressed: () => context.push(
                                  '/tournaments/${tournament.id}/matches/${match.id}/score'),
                                child: Text('SCORE',
                                    style: SkorioTextStyles.labelSm.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
            },
          ),
        if (isCreator)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'add_fixture',
              backgroundColor: SkorioColors.secondary,
              onPressed: () => _showAddFixtureDialog(context, tournament),
              child: const Icon(Icons.add, color: Colors.black),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.white24;
    String text = status.toUpperCase();

    if (status == 'live') {
      color = SkorioColors.secondary;
    } else if (status == 'completed') {
      color = Colors.white54;
    } else if (status == 'postponed') {
      color = Colors.orange;
    } else {
      text = "SCHEDULED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: SkorioTextStyles.labelSm.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: 8),
      ),
    );
  }

  // ─── 3. Teams Tab ──────────────────────────────────────────────────────────

  Widget _buildTeamsTab(Tournament tournament, {required bool isCreator}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: tournament.teams.length,
      itemBuilder: (context, idx) {
        final team = tournament.teams[idx];
        final colorVal = int.tryParse(team.primaryColor) ?? 0xFF43DF9E;
        final primaryColor = Color(colorVal);

        return GestureDetector(
          onTap: () => _showRosterSheet(context, team),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            borderColor: primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(team.logoUrl, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(
                  team.name,
                  style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${team.players.length} registered squad",
                  style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 12),
                ),
                if (isCreator) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      final link = 'skorio://tournaments/${tournament.id}/register/${team.id}';
                      SharePlus.instance.share(ShareParams(
                        text: '⚽ Join ${team.name} in ${tournament.name}!\n\nRegister here: $link',
                      ));
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 12, color: SkorioColors.secondary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('Share reg link',
                          style: SkorioTextStyles.labelSm.copyWith(
                            color: SkorioColors.secondary.withValues(alpha: 0.8), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRosterSheet(BuildContext context, TournamentTeam team) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(team.logoUrl, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    "${team.name} Squad Roster",
                    style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: team.players.isEmpty
                    ? Center(
                        child: Text("No roster uploaded", style: TextStyle(color: Colors.white24)),
                      )
                    : ListView.builder(
                        itemCount: team.players.length,
                        itemBuilder: (context, idx) {
                          final player = team.players[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/players/${Uri.encodeComponent(player.name)}');
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.white10,
                                    child: Text(
                                      "${player.jerseyNumber}",
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player.name,
                                          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          player.position,
                                          style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (player.isSuspended)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                                      ),
                                      child: const Text('SUSPENDED', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w700)),
                                    )
                                  else if (player.yellowCards > 0) ...[
                                    const Text('🟨', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 2),
                                    Text('${player.yellowCards}',
                                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    "${player.goals}G",
                                    style: TextStyle(color: SkorioColors.secondary, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 14, color: Colors.white24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 4. Leaders Tab ─────────────────────────────────────────────────────────

  Widget _buildStatsTab(Tournament tournament) {
    // Extract all players and sort
    final List<TournamentPlayer> allPlayers = [];
    for (var team in tournament.teams) {
      allPlayers.addAll(team.players);
    }

    if (allPlayers.isEmpty) {
      return Center(
        child: Text("No statistics compiled yet", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24)),
      );
    }

    final cs = ref.read(careerStatsProvider.notifier);
    final topScorers  = cs.topScorers(tournament.id);
    final topAssists  = cs.topAssists(tournament.id);
    final topMotm     = cs.topMotm(tournament.id);
    final mostCards   = cs.topCards(tournament.id);

    if (topScorers.isEmpty && topAssists.isEmpty && topMotm.isEmpty && mostCards.isEmpty) {
      return Center(
        child: Text("No statistics compiled yet", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeaderSection(context, "TOP GOAL SCORERS ⚽", topScorers, (l) => "${l.value} Goals"),
          const SizedBox(height: 16),
          _buildLeaderSection(context, "TOP ASSISTS 🎯", topAssists, (l) => "${l.value} Assists"),
          const SizedBox(height: 16),
          _buildLeaderSection(context, "MAN OF THE MATCH 👑", topMotm, (l) => "${l.value} Awards"),
          const SizedBox(height: 16),
          _buildLeaderSection(context, "DISCIPLINARY 🟨", mostCards, (l) => "${l.value} Cards"),
        ],
      ),
    );
  }

  Widget _buildLeaderSection(
    BuildContext context,
    String title,
    List<StatLeader> leaders,
    String Function(StatLeader) metricLabel,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: SkorioColors.secondary.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 12),
          leaders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("No records yet", style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24)),
                )
              : Column(
                  children: leaders.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final leader = entry.value;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push('/players/${Uri.encodeComponent(leader.playerName)}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              idx == 0 ? Icons.workspace_premium : idx == 1 ? Icons.stars : Icons.star_border,
                              color: idx == 0 ? SkorioColors.gold : idx == 1 ? SkorioColors.silver : SkorioColors.bronze,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(leader.teamLogo, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(leader.playerName,
                                      style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text(leader.teamName,
                                      style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.outline, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                              metricLabel(leader),
                              style: const TextStyle(color: SkorioColors.secondary, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 14, color: SkorioColors.outline),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ─── 5. Bracket Tab ──────────────────────────────────────────────────────────

  Widget _buildBracketTab(Tournament tournament, {required bool isCreator}) {
    final rounds = ref.watch(tournamentsProvider.notifier).getKnockoutRounds(tournament.id);
    final isGroupKnockout = tournament.format == 'group_knockout' || tournament.format == 'groups_knockout';

    // Check if all group matches are complete (so bracket can be generated)
    final groupMatches = tournament.matches.where((m) => m.phase == 'group').toList();
    final allGroupsDone = groupMatches.isNotEmpty && groupMatches.every((m) => m.status == 'completed');

    // Check if knockout slots are still TBD
    final hasTbdSlots = tournament.matches.any((m) => m.phase != 'group' && m.homeTeamId == 'tbd');

    if (rounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree_outlined, color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            Text(
              isGroupKnockout ? "Group stage in progress" : "No knockout matches yet",
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24),
            ),
            const SizedBox(height: 6),
            Text(
              isGroupKnockout ? "Complete all group matches to generate the bracket" : "Add matches with phase r16/qf/sf/final",
              style: SkorioTextStyles.labelSm.copyWith(color: Colors.white12, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (isCreator && isGroupKnockout && allGroupsDone) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(tournamentsProvider.notifier).generateKnockoutBracket(tournament.id);
                },
                icon: const Icon(Icons.account_tree),
                label: const Text('Generate Bracket'),
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.secondary,
                  foregroundColor: SkorioColors.onSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Show "Finalize Bracket" button if TBD slots exist and groups are done
    final showFinalizeButton = isCreator && isGroupKnockout && allGroupsDone && hasTbdSlots;

    const phaseLabels = {'r16': 'R16', 'qf': 'QF', 'sf': 'SEMI', 'final': 'FINAL'};
    const phaseColors = {
      'r16': Color(0xFF38BDF8),
      'qf': Color(0xFF60A5FA),
      'sf': Color(0xFFA78BFA),
      'final': Color(0xFFFBBF24),
    };

    return Column(
      children: [
        if (showFinalizeButton)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => ref.read(tournamentsProvider.notifier).generateKnockoutBracket(tournament.id),
                icon: const Icon(Icons.account_tree),
                label: const Text('Finalize Bracket from Groups'),
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.secondary,
                  foregroundColor: SkorioColors.onSecondary,
                ),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rounds.entries.map((entry) {
            final phase = entry.key;
            final matches = entry.value;
            final color = phaseColors[phase] ?? SkorioColors.secondary;
            final label = phaseLabels[phase] ?? phase.toUpperCase();

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 140,
                child: Column(
                  children: [
                    Text(
                      label,
                      style: SkorioTextStyles.labelSm.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...matches.map((match) {
                      final homeTeam = tournament.teams.where((t) => t.id == match.homeTeamId).firstOrNull;
                      final awayTeam = tournament.teams.where((t) => t.id == match.awayTeamId).firstOrNull;
                      final homeName = homeTeam?.name ?? 'TBD';
                      final awayName = awayTeam?.name ?? 'TBD';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: match.status == 'completed'
                                ? color.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: [
                            _bracketTeamRow(homeName, match.homeScore,
                                match.status == 'completed' && match.homeScore > match.awayScore, color),
                            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                            _bracketTeamRow(awayName, match.awayScore,
                                match.status == 'completed' && match.awayScore > match.homeScore, color),
                            if (match.status != 'completed' && isCreator)
                              GestureDetector(
                                onTap: () => _showResultEntryDialog(context, match, tournament),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  color: color.withValues(alpha: 0.08),
                                  child: Text(
                                    '+ RESULT',
                                    textAlign: TextAlign.center,
                                    style: SkorioTextStyles.labelSm.copyWith(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
        ),
      ],
    );
  }

  Widget _bracketTeamRow(String name, int score, bool isWinner, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      color: isWinner ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: SkorioTextStyles.labelSm.copyWith(
                color: isWinner ? Colors.white : Colors.white54,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: isWinner ? accentColor : Colors.white30,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
