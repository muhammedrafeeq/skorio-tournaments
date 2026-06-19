import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/scoring/chess_scoring_provider.dart';
import '../../providers/tournaments_provider.dart';

class ChessScoringScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;

  const ChessScoringScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  ConsumerState<ChessScoringScreen> createState() => _ChessScoringScreenState();
}

class _ChessScoringScreenState extends ConsumerState<ChessScoringScreen> {
  final _notesController = TextEditingController();
  final _pgnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chessScoringProvider.notifier)
          .loadMatch(widget.tournamentId, widget.matchId);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pgnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chessScoringProvider);
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
        orElse: () => TournamentTeam(id: '', name: 'White', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));
    final awayTeam = tournament.teams.firstWhere((t) => t.id == state.awayTeamId,
        orElse: () => TournamentTeam(id: '', name: 'Black', logoUrl: '',
            primaryColor: '', secondaryColor: '', players: []));

    if (_notesController.text.isEmpty && (state.notes?.isNotEmpty ?? false)) {
      _notesController.text = state.notes ?? '';
    }
    if (_pgnController.text.isEmpty && (state.pgn?.isNotEmpty ?? false)) {
      _pgnController.text = state.pgn ?? '';
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Chess Scoring')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlayers(homeTeam, awayTeam, state, theme),
            const SizedBox(height: 24),
            _buildResultSection(state, theme),
            const SizedBox(height: 24),
            _buildTimeControl(state, theme),
            const SizedBox(height: 24),
            _buildNotesSection(state, theme),
            const SizedBox(height: 24),
            _buildPgnSection(state, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayers(TournamentTeam home, TournamentTeam away, ChessMatchState state, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _PlayerCard(
            name: home.name,
            side: 'White',
            color: Colors.white,
            borderColor: Colors.grey.shade400,
            isWinner: state.result == ChessResult.whiteWins,
            isDraw: state.result == ChessResult.draw,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text(state.result.shortLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (state.moveCount != null)
                Text('${state.moveCount} moves',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: _PlayerCard(
            name: away.name,
            side: 'Black',
            color: Colors.grey.shade800,
            borderColor: Colors.grey.shade600,
            isWinner: state.result == ChessResult.blackWins,
            isDraw: state.result == ChessResult.draw,
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(ChessMatchState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Result', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ChessResult.values.map((r) {
            final selected = state.result == r;
            return ChoiceChip(
              label: Text(r.label),
              selected: selected,
              onSelected: (_) {
                if (r != ChessResult.ongoing) {
                  _showTerminationDialog(r);
                } else {
                  ref.read(chessScoringProvider.notifier)
                      .setResult(r);
                }
              },
            );
          }).toList(),
        ),
        if (state.termination != null) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.flag, size: 16),
            label: Text(state.termination!.label),
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
        ],
      ],
    );
  }

  void _showTerminationDialog(ChessResult result) {
    final validTerminations = _terminationsFor(result);
    showDialog(
      context: context,
      builder: (ctx) {
        ChessTermination? selected = validTerminations.first;
        final moveCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('${result.label} — How?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...validTerminations.map((t) => RadioListTile<ChessTermination>(
                  value: t,
                  groupValue: selected,
                  title: Text(t.label),
                  onChanged: (v) => setS(() => selected = v),
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: moveCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Move count (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final moves = int.tryParse(moveCtrl.text);
                  ref.read(chessScoringProvider.notifier).setResult(
                    result,
                    termination: selected,
                    moveCount: moves,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ChessTermination> _terminationsFor(ChessResult result) {
    switch (result) {
      case ChessResult.whiteWins:
      case ChessResult.blackWins:
        return [
          ChessTermination.checkmate,
          ChessTermination.resignation,
          ChessTermination.timeout,
          ChessTermination.abandoned,
        ];
      case ChessResult.draw:
        return [
          ChessTermination.stalemate,
          ChessTermination.insufficientMaterial,
          ChessTermination.fiftyMoveRule,
          ChessTermination.repetition,
          ChessTermination.agreement,
        ];
      case ChessResult.ongoing:
        return [ChessTermination.abandoned];
    }
  }

  Widget _buildTimeControl(ChessMatchState state, ThemeData theme) {
    final presets = [
      (label: 'Classical', minutes: 90, inc: 30),
      (label: 'Rapid', minutes: 15, inc: 10),
      (label: 'Blitz', minutes: 5, inc: 3),
      (label: 'Bullet', minutes: 1, inc: 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time Control', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: presets.map((p) {
            final selected = state.timeControlMinutes == p.minutes &&
                (state.timeIncrementSeconds ?? 0) == p.inc;
            return ChoiceChip(
              label: Text('${p.label}\n${p.minutes}min+${p.inc}s'),
              selected: selected,
              onSelected: (_) => ref.read(chessScoringProvider.notifier)
                  .setTimeControl(minutes: p.minutes, incrementSeconds: p.inc),
            );
          }).toList(),
        ),
        if (state.timeControlMinutes != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${state.timeControlMinutes} min + ${state.timeIncrementSeconds ?? 0}s increment',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildNotesSection(ChessMatchState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Match Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add notes about the game...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref.read(chessScoringProvider.notifier).setNotes(v),
        ),
      ],
    );
  }

  Widget _buildPgnSection(ChessMatchState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PGN Notation', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('(optional)', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pgnController,
          maxLines: 6,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: '1. e4 e5 2. Nf3 Nc6...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref.read(chessScoringProvider.notifier).setPgn(v),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final String side;
  final Color color;
  final Color borderColor;
  final bool isWinner;
  final bool isDraw;

  const _PlayerCard({
    required this.name,
    required this.side,
    required this.color,
    required this.borderColor,
    required this.isWinner,
    required this.isDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? Colors.amber : (isDraw ? Colors.blue : borderColor),
          width: isWinner || isDraw ? 2 : 1,
        ),
        boxShadow: isWinner
            ? [const BoxShadow(color: Colors.amber, blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        children: [
          Text(side,
              style: TextStyle(
                fontSize: 11,
                color: side == 'White' ? Colors.black54 : Colors.white60,
              )),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: side == 'White' ? Colors.black87 : Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            ),
          if (isDraw)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.handshake_outlined, color: Colors.blueAccent, size: 18),
            ),
        ],
      ),
    );
  }
}
