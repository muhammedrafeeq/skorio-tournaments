import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/tournaments_provider.dart';

class HeadToHeadScreen extends ConsumerWidget {
  final String tournamentId;
  final String teamAId;
  final String teamBId;

  const HeadToHeadScreen({
    super.key,
    required this.tournamentId,
    required this.teamAId,
    required this.teamBId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentsProvider).tournaments;
    final tournament = tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
          location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '', creatorId: ''),
    );

    if (tournament.id.isEmpty) {
      return const Scaffold(
        backgroundColor: SkorioColors.baseBg,
        body: Center(child: Text('Tournament not found', style: TextStyle(color: Colors.white54))),
      );
    }

    final teamA = tournament.teams.firstWhere(
      (t) => t.id == teamAId,
      orElse: () => TournamentTeam(id: '', name: 'Team A', logoUrl: '⚽', primaryColor: '', secondaryColor: '', players: []),
    );
    final teamB = tournament.teams.firstWhere(
      (t) => t.id == teamBId,
      orElse: () => TournamentTeam(id: '', name: 'Team B', logoUrl: '⚽', primaryColor: '', secondaryColor: '', players: []),
    );

    final h2hMatches = tournament.matches.where((m) =>
      m.status == 'completed' &&
      ((m.homeTeamId == teamAId && m.awayTeamId == teamBId) ||
       (m.homeTeamId == teamBId && m.awayTeamId == teamAId)),
    ).toList()..sort((a, b) => b.date.compareTo(a.date));

    int aWins = 0, bWins = 0, draws = 0;
    int aGoals = 0, bGoals = 0;

    for (final m in h2hMatches) {
      final aIsHome = m.homeTeamId == teamAId;
      final aScore = aIsHome ? m.homeScore : m.awayScore;
      final bScore = aIsHome ? m.awayScore : m.homeScore;
      aGoals += aScore;
      bGoals += bScore;
      if (aScore > bScore) { aWins++; }
      else if (bScore > aScore) { bWins++; }
      else { draws++; }
    }

    final total = h2hMatches.length;

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Head-to-Head',
                      style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: total == 0
                  ? _buildEmpty(teamA, teamB)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildMatchupBanner(teamA, teamB),
                        const SizedBox(height: 16),
                        _buildSummaryCard(teamA, teamB, aWins, bWins, draws, total, aGoals, bGoals),
                        const SizedBox(height: 20),
                        Text('MATCH HISTORY',
                          style: SkorioTextStyles.labelSm.copyWith(
                            color: Colors.white30, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        ...h2hMatches.map((m) => _buildMatchRow(m, teamA, teamB)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(TournamentTeam teamA, TournamentTeam teamB) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${teamA.logoUrl} vs ${teamB.logoUrl}', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          Text('${teamA.name} vs ${teamB.name}',
            style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('No completed matches between these teams yet.',
            textAlign: TextAlign.center,
            style: SkorioTextStyles.bodyMd.copyWith(color: Colors.white30)),
        ],
      ),
    );
  }

  Widget _buildMatchupBanner(TournamentTeam teamA, TournamentTeam teamB) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(teamA.logoUrl, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(teamA.name,
                  textAlign: TextAlign.center,
                  style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text('VS', style: SkorioTextStyles.headlineLg.copyWith(
            color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 22)),
          Expanded(
            child: Column(
              children: [
                Text(teamB.logoUrl, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(teamB.name,
                  textAlign: TextAlign.center,
                  style: SkorioTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TournamentTeam teamA, TournamentTeam teamB,
      int aWins, int bWins, int draws, int total, int aGoals, int bGoals) {
    final aWinPct = total > 0 ? aWins / total : 0.0;
    final bWinPct = total > 0 ? bWins / total : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Win bar
          Row(
            children: [
              Text('$aWins', style: SkorioTextStyles.headlineLg.copyWith(
                color: SkorioColors.secondary, fontWeight: FontWeight.w900)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Flexible(
                            flex: (aWinPct * 100).round().clamp(1, 99),
                            child: Container(color: SkorioColors.secondary),
                          ),
                          Flexible(
                            flex: ((1 - aWinPct - bWinPct) * 100).round().clamp(0, 100),
                            child: Container(color: Colors.white24),
                          ),
                          Flexible(
                            flex: (bWinPct * 100).round().clamp(1, 99),
                            child: Container(color: SkorioColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text('$bWins', style: SkorioTextStyles.headlineLg.copyWith(
                color: SkorioColors.primary, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wins', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
              Text('$draws Draws', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
              Text('Wins', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statPair('$aGoals', 'Goals', '$bGoals'),
              _statPair('$total', 'Played', '$total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPair(String left, String label, String right) {
    return Row(
      children: [
        Text(left, style: SkorioTextStyles.headlineMd.copyWith(
          color: SkorioColors.secondary, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text(label, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30)),
        const SizedBox(width: 8),
        Text(right, style: SkorioTextStyles.headlineMd.copyWith(
          color: SkorioColors.primary, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildMatchRow(TournamentMatch match, TournamentTeam teamA, TournamentTeam teamB) {
    final aIsHome = match.homeTeamId == teamAId;
    final aScore = aIsHome ? match.homeScore : match.awayScore;
    final bScore = aIsHome ? match.awayScore : match.homeScore;

    Color resultColor = Colors.white24;
    String resultLabel = 'D';
    if (aScore > bScore) { resultColor = SkorioColors.secondary; resultLabel = 'W'; }
    else if (bScore > aScore) { resultColor = SkorioColors.primary; resultLabel = 'L'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: resultColor.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(child: Text(resultLabel,
              style: TextStyle(color: resultColor, fontSize: 11, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${teamA.name}  $aScore – $bScore  ${teamB.name}',
              style: SkorioTextStyles.labelMd.copyWith(color: Colors.white),
            ),
          ),
          Text(
            '${match.date.day}/${match.date.month}/${match.date.year}',
            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
