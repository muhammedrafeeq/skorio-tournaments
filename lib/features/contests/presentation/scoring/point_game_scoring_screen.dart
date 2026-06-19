import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scoring/point_game_scoring_provider.dart';
import '../../providers/tournaments_provider.dart';

class PointGameScoringScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;
  final String sport; // 'badminton' or 'table_tennis'

  const PointGameScoringScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.sport,
  });

  @override
  ConsumerState<PointGameScoringScreen> createState() => _PointGameScoringScreenState();
}

class _PointGameScoringScreenState extends ConsumerState<PointGameScoringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = widget.sport == 'badminton'
          ? PointGameConfig.badminton
          : PointGameConfig.tableTennis;
      ref.read(pointGameScoringProvider.notifier)
          .loadMatch(widget.tournamentId, widget.matchId, config);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pointGameScoringProvider);
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
        orElse: () => TournamentTeam(id: '', name: 'Home', logoUrl: '', primaryColor: '', secondaryColor: '', players: []));
    final awayTeam = tournament.teams.firstWhere((t) => t.id == state.awayTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Away', logoUrl: '', primaryColor: '', secondaryColor: '', players: []));

    final sportLabel = widget.sport == 'badminton' ? 'Badminton' : 'Table Tennis';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('$sportLabel Scoring'),
        actions: [
          if (!state.isComplete)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last point',
              onPressed: () => ref.read(pointGameScoringProvider.notifier).undoPoint(),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildScoreboard(state, homeTeam, awayTeam, theme),
          const Divider(height: 1),
          _buildSetGrid(state, homeTeam, awayTeam, theme),
          const SizedBox(height: 16),
          if (state.isComplete)
            _buildMatchComplete(state, homeTeam, awayTeam, theme)
          else
            _buildScoringButtons(state, homeTeam, awayTeam, theme),
        ],
      ),
    );
  }

  Widget _buildScoreboard(PointGameState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    final cur = state.currentSet;
    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(home.name, style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('${cur.homePoints}', style: const TextStyle(
                    color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
                Text('Sets: ${state.homeSetsWon}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Column(
            children: [
              Text('Set ${state.sets.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              const Text('–', style: TextStyle(color: Colors.white, fontSize: 32)),
              const SizedBox(height: 4),
              Text('${state.config.pointsPerSet} pts',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Text(away.name, style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('${cur.awayPoints}', style: const TextStyle(
                    color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
                Text('Sets: ${state.awaySetsWon}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetGrid(PointGameState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
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
                  const Padding(padding: EdgeInsets.all(6), child: Text('', style: TextStyle(fontSize: 12))),
                  ...List.generate(state.sets.length, (i) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('S${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  )),
                ],
              ),
              _buildSetRow(home.name, true, state),
              _buildSetRow(away.name, false, state),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildSetRow(String name, bool isHome, PointGameState state) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(6),
        child: Text(name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      ),
      ...state.sets.map((s) {
        final pts = isHome ? s.homePoints : s.awayPoints;
        final won = isHome
            ? (s.winnerId == state.homeTeamId)
            : (s.winnerId == state.awayTeamId);
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Text('$pts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: won ? FontWeight.bold : FontWeight.normal,
                color: won ? Colors.green : null,
              ),
              textAlign: TextAlign.center),
        );
      }),
    ]);
  }

  Widget _buildScoringButtons(PointGameState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: _ScoringButton(
                label: home.name,
                color: theme.colorScheme.primary,
                onTap: () => ref.read(pointGameScoringProvider.notifier).addPoint(isHome: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ScoringButton(
                label: away.name,
                color: Colors.deepOrange,
                onTap: () => ref.read(pointGameScoringProvider.notifier).addPoint(isHome: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchComplete(PointGameState state, TournamentTeam home, TournamentTeam away, ThemeData theme) {
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

class _ScoringButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ScoringButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.white, size: 48),
              const SizedBox(height: 12),
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
