import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scoring/tennis_scoring_provider.dart';
import '../../providers/tournaments_provider.dart';

class TennisScoringScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;

  const TennisScoringScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  ConsumerState<TennisScoringScreen> createState() => _TennisScoringScreenState();
}

class _TennisScoringScreenState extends ConsumerState<TennisScoringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tennisScoringProvider.notifier)
          .loadMatch(widget.tournamentId, widget.matchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tennisScoringProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tournament = ref.watch(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '',
              description: '', location: '', bannerUrl: '', winPts: 3,
              drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '',
              creatorId: ''));
    final homeTeam = tournament.teams.firstWhere((t) => t.id == state.homeTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Home', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));
    final awayTeam = tournament.teams.firstWhere((t) => t.id == state.awayTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Away', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tennis Scoring')),
      body: Column(
        children: [
          _buildScoreboard(state, homeTeam, awayTeam, theme),
          const Divider(height: 1),
          _buildSetGrid(state, homeTeam, awayTeam, theme),
          const SizedBox(height: 8),
          if (state.isComplete)
            _buildMatchComplete(state, homeTeam, awayTeam, theme)
          else
            _buildScoringButtons(state, homeTeam, awayTeam, theme),
        ],
      ),
    );
  }

  Widget _buildScoreboard(TennisMatchState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    final homeGame = state.inTiebreak
        ? '${state.currentTiebreak?.homePoints ?? 0}'
        : state.currentGame.homePoint.label;
    final awayGame = state.inTiebreak
        ? '${state.currentTiebreak?.awayPoints ?? 0}'
        : state.currentGame.awayPoint.label;

    // Deuce / advantage display
    String? statusLabel;
    if (!state.inTiebreak && state.currentGame.homePoint == TennisPoint.deuce) {
      if (state.currentGame.isAdvantageSide) {
        statusLabel = 'Adv ${home.name}';
      } else if (state.currentGame.homePoint == TennisPoint.deuce &&
          state.currentGame.awayPoint == TennisPoint.deuce) {
        statusLabel = 'Deuce';
      }
    }

    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          if (state.inTiebreak)
            Text('TIEBREAK', style: const TextStyle(
                color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          if (statusLabel != null)
            Text(statusLabel, style: const TextStyle(color: Colors.yellowAccent)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Column(children: [
                Text(home.name, style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(homeGame, style: const TextStyle(
                    color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
                Text('Sets: ${state.homeSetsWon}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              Column(children: [
                const Text('Game', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                const Text('–', style: TextStyle(color: Colors.white, fontSize: 28)),
              ]),
              Expanded(child: Column(children: [
                Text(away.name, style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(awayGame, style: const TextStyle(
                    color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
                Text('Sets: ${state.awaySetsWon}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetGrid(TennisMatchState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    if (state.sets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sets', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: theme.dividerColor),
            columnWidths: const {0: FlexColumnWidth(2)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                children: [
                  const Padding(padding: EdgeInsets.all(6), child: Text('')),
                  ...List.generate(state.sets.length, (i) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('S${i + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  )),
                ],
              ),
              _setRow(home.name, true, state),
              _setRow(away.name, false, state),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _setRow(String name, bool isHome, TennisMatchState state) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(6),
        child: Text(name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      ),
      ...state.sets.map((s) {
        final games = isHome ? s.homeGames : s.awayGames;
        final tbPts = isHome
            ? (s.tiebreak?.homePoints)
            : (s.tiebreak?.awayPoints);
        final won = isHome
            ? (s.winnerId == state.homeTeamId)
            : (s.winnerId == state.awayTeamId);
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$games',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: won ? FontWeight.bold : FontWeight.normal,
                    color: won ? Colors.green : null,
                  )),
              if (tbPts != null && s.hasTiebreak)
                Text('($tbPts)',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        );
      }),
    ]);
  }

  Widget _buildScoringButtons(TennisMatchState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _TennisScoreButton(
                label: home.name,
                color: theme.colorScheme.primary,
                onTap: () => ref.read(tennisScoringProvider.notifier).addPoint(isHome: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TennisScoreButton(
                label: away.name,
                color: Colors.deepOrange,
                onTap: () => ref.read(tennisScoringProvider.notifier).addPoint(isHome: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchComplete(TennisMatchState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    final winner = state.winnerId == state.homeTeamId ? home.name : away.name;
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 12),
            Text('Match Complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('$winner wins!',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('${state.homeSetsWon} – ${state.awaySetsWon} sets',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _TennisScoreButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TennisScoreButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_tennis, color: Colors.white, size: 44),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Tap to score', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
