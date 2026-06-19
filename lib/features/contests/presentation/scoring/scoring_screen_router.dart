import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tournaments_provider.dart';
import 'cricket_scoring_screen.dart';
import 'point_game_scoring_screen.dart';
import 'tennis_scoring_screen.dart';
import 'chess_scoring_screen.dart';

/// Reads the tournament's sport and dispatches to the correct scoring screen.
class ScoringScreenRouter extends ConsumerWidget {
  final String tournamentId;
  final String matchId;

  const ScoringScreenRouter({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '',
              description: '', location: '', bannerUrl: '', winPts: 3,
              drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '',
              creatorId: ''));

    if (tournament.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Tournament not found')));
    }

    final sport = tournament.sport.toLowerCase().trim();

    switch (sport) {
      case 'cricket':
        return CricketScoringScreen(
          tournamentId: tournamentId,
          matchId: matchId,
        );
      case 'badminton':
        return PointGameScoringScreen(
          tournamentId: tournamentId,
          matchId: matchId,
          sport: 'badminton',
        );
      case 'table tennis':
      case 'table_tennis':
      case 'tabletennis':
        return PointGameScoringScreen(
          tournamentId: tournamentId,
          matchId: matchId,
          sport: 'table_tennis',
        );
      case 'tennis':
        return TennisScoringScreen(
          tournamentId: tournamentId,
          matchId: matchId,
        );
      case 'chess':
        return ChessScoringScreen(
          tournamentId: tournamentId,
          matchId: matchId,
        );
      default:
        return _GenericScoreScreen(
          tournamentId: tournamentId,
          matchId: matchId,
          sport: tournament.sport,
        );
    }
  }
}

/// Simple +/- score entry for sports without a dedicated scoring engine.
class _GenericScoreScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;
  final String sport;

  const _GenericScoreScreen({
    required this.tournamentId,
    required this.matchId,
    required this.sport,
  });

  @override
  ConsumerState<_GenericScoreScreen> createState() => _GenericScoreScreenState();
}

class _GenericScoreScreenState extends ConsumerState<_GenericScoreScreen> {
  int _home = 0;
  int _away = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tournament = ref.watch(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '',
              description: '', location: '', bannerUrl: '', winPts: 3,
              drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '',
              creatorId: ''));
    final match = tournament.matches.firstWhere((m) => m.id == widget.matchId,
        orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '',
            date: DateTime.now(), status: '', venue: ''));
    final homeTeam = tournament.teams.firstWhere((t) => t.id == match.homeTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Home', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));
    final awayTeam = tournament.teams.firstWhere((t) => t.id == match.awayTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Away', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.sport} Scoring')),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              children: [
                _scoreColumn(homeTeam.name, _home, true, theme),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('–', style: const TextStyle(color: Colors.white, fontSize: 36)),
                ),
                _scoreColumn(awayTeam.name, _away, false, theme),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton.icon(
              onPressed: _confirmResult,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Result'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreColumn(String name, int score, bool isHome, ThemeData theme) {
    return Expanded(
      child: Column(
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('$score', style: const TextStyle(
              color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                onPressed: () {
                  if (isHome && _home > 0) { setState(() => _home--); }
                  if (!isHome && _away > 0) { setState(() => _away--); }
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: () {
                  if (isHome) setState(() => _home++);
                  else setState(() => _away++);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmResult() {
    ref.read(tournamentsProvider.notifier)
        .updateMatchResult(widget.tournamentId, widget.matchId, _home, _away);
    Navigator.pop(context);
  }
}
