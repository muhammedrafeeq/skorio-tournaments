import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart' show SkorioTextStyles;
import '../../../core/widgets/glass_card.dart';
import '../providers/tournaments_provider.dart';
import '../providers/match_events_provider.dart';
import '../../auth/providers/auth_provider.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;

  const LiveMatchScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(matchEventsProvider.notifier).watchMatch(widget.matchId);
    });
  }

  @override
  void dispose() {
    ref.read(matchEventsProvider.notifier).stopWatching();
    super.dispose();
  }

  bool _isAdmin(Tournament tournament, String? userId) {
    return tournament.creatorId == userId;
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsState = ref.watch(tournamentsProvider);
    final eventsState = ref.watch(matchEventsProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.value?.id;

    final tournament = tournamentsState.tournaments.firstWhere(
      (t) => t.id == widget.tournamentId,
      orElse: () => Tournament(
        id: '', name: '', sport: '', format: '', description: '',
        location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
        teams: [], matches: [], prizes: '', creatorId: '',
      ),
    );

    if (tournament.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Tournament not found')));
    }

    final match = tournament.matches.firstWhere(
      (m) => m.id == widget.matchId,
      orElse: () => TournamentMatch(
        id: '', homeTeamId: '', awayTeamId: '',
        date: DateTime.now(), status: 'scheduled', venue: '',
      ),
    );

    if (match.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Match not found')));
    }

    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'Home', logoUrl: '⚽', primaryColor: '', secondaryColor: '', players: []),
    );
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'Away', logoUrl: '⚽', primaryColor: '', secondaryColor: '', players: []),
    );

    final isAdmin = _isAdmin(tournament, userId);
    final isLive = match.status == 'live';

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      appBar: AppBar(
        backgroundColor: SkorioColors.surface,
        title: Text(tournament.name, style: SkorioTextStyles.labelMd),
        actions: [
          if (isLive)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('LIVE', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard
          _ScoreBoard(match: match, homeTeam: homeTeam, awayTeam: awayTeam),

          // Admin controls
          if (isAdmin) _AdminControls(
            tournament: tournament,
            match: match,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            isLive: isLive,
          ),

          // Event feed
          Expanded(
            child: eventsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : eventsState.events.isEmpty
                    ? _EmptyFeed(isLive: isLive)
                    : _EventFeed(events: eventsState.events, tournament: tournament),
          ),
        ],
      ),
    );
  }
}

// ─── Scoreboard ───────────────────────────────────────────────────────────────

class _ScoreBoard extends StatelessWidget {
  final TournamentMatch match;
  final TournamentTeam homeTeam;
  final TournamentTeam awayTeam;

  const _ScoreBoard({required this.match, required this.homeTeam, required this.awayTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SkorioColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(homeTeam.logoUrl, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(homeTeam.name, style: SkorioTextStyles.labelMd, textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${match.homeScore}  –  ${match.awayScore}',
              style: SkorioTextStyles.headlineLg.copyWith(
                color: SkorioColors.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 34,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(awayTeam.logoUrl, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(awayTeam.name, style: SkorioTextStyles.labelMd, textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Controls ───────────────────────────────────────────────────────────

class _AdminControls extends ConsumerWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final TournamentTeam homeTeam;
  final TournamentTeam awayTeam;
  final bool isLive;

  const _AdminControls({
    required this.tournament,
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: SkorioColors.surface.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Start / Stop match
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                await ref.read(tournamentsProvider.notifier).setMatchLive(
                  tournament.id, match.id, live: !isLive,
                );
                if (isLive) {
                  // Add full-time event
                  await ref.read(matchEventsProvider.notifier).addEvent(MatchEvent(
                    id: '',
                    matchId: match.id,
                    tournamentId: tournament.id,
                    type: MatchEventType.fullTime,
                    minute: 90,
                    playerName: '',
                    teamId: '',
                    createdAt: DateTime.now(),
                  ));
                } else {
                  await ref.read(matchEventsProvider.notifier).addEvent(MatchEvent(
                    id: '',
                    matchId: match.id,
                    tournamentId: tournament.id,
                    type: MatchEventType.kickoff,
                    minute: 0,
                    playerName: '',
                    teamId: '',
                    createdAt: DateTime.now(),
                  ));
                }
              },
              icon: Icon(isLive ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              label: Text(isLive ? 'End Match' : 'Start Match'),
              style: FilledButton.styleFrom(
                backgroundColor: isLive ? SkorioColors.errorContainer : SkorioColors.secondary,
                foregroundColor: isLive ? SkorioColors.onErrorContainer : SkorioColors.onSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Add event button
          if (isLive)
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showAddEventSheet(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Event'),
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.primaryContainer,
                  foregroundColor: SkorioColors.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddEventSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEventSheet(
        tournament: tournament,
        match: match,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
      ),
    );
  }
}

// ─── Add Event Sheet ──────────────────────────────────────────────────────────

class _AddEventSheet extends ConsumerStatefulWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final TournamentTeam homeTeam;
  final TournamentTeam awayTeam;

  const _AddEventSheet({
    required this.tournament,
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<_AddEventSheet> {
  MatchEventType _selectedType = MatchEventType.goal;
  TournamentTeam? _selectedTeam;
  TournamentPlayer? _selectedPlayer;
  TournamentPlayer? _assistPlayer;
  TournamentPlayer? _subOutPlayer;
  final _minuteController = TextEditingController(text: '45');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.homeTeam;
  }

  @override
  void dispose() {
    _minuteController.dispose();
    super.dispose();
  }

  List<TournamentPlayer> get _teamPlayers => _selectedTeam?.players ?? [];

  Future<void> _save() async {
    if (_selectedPlayer == null &&
        _selectedType != MatchEventType.kickoff &&
        _selectedType != MatchEventType.fullTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a player')),
      );
      return;
    }

    setState(() => _saving = true);

    final minute = int.tryParse(_minuteController.text) ?? 0;
    final event = MatchEvent(
      id: '',
      matchId: widget.match.id,
      tournamentId: widget.tournament.id,
      type: _selectedType,
      minute: minute,
      playerName: _selectedPlayer?.name ?? '',
      teamId: _selectedTeam?.id ?? '',
      assistPlayerName: _selectedType == MatchEventType.goal ? _assistPlayer?.name : null,
      subOutPlayerName: _selectedType == MatchEventType.substitution ? _subOutPlayer?.name : null,
      createdAt: DateTime.now(),
    );

    await ref.read(matchEventsProvider.notifier).addEvent(event);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: SkorioColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Add Match Event', style: SkorioTextStyles.headlineMd),
          const SizedBox(height: 20),

          // Event type chips
          Text('Event Type', style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              MatchEventType.goal,
              MatchEventType.yellowCard,
              MatchEventType.redCard,
              MatchEventType.substitution,
            ].map((type) {
              final selected = _selectedType == type;
              return ChoiceChip(
                label: Text('${type.emoji} ${type.label}'),
                selected: selected,
                onSelected: (_) => setState(() {
                  _selectedType = type;
                  _selectedPlayer = null;
                  _assistPlayer = null;
                  _subOutPlayer = null;
                }),
                selectedColor: SkorioColors.primaryContainer,
                labelStyle: TextStyle(
                  color: selected ? SkorioColors.onPrimaryContainer : SkorioColors.onSurface,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Team selector
          Text('Team', style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [widget.homeTeam, widget.awayTeam].map((team) {
              final selected = _selectedTeam?.id == team.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedTeam = team;
                    _selectedPlayer = null;
                    _assistPlayer = null;
                    _subOutPlayer = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? SkorioColors.primaryContainer : SkorioColors.surfaceBright,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(team.logoUrl, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(team.name, style: SkorioTextStyles.labelSm, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Minute
          TextField(
            controller: _minuteController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Minute',
              prefixIcon: const Icon(Icons.timer_outlined),
              filled: true,
              fillColor: SkorioColors.surfaceBright,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          // Player selector
          if (_selectedType != MatchEventType.kickoff && _selectedType != MatchEventType.fullTime) ...[
            Text(
              _selectedType == MatchEventType.substitution ? 'Player In' : 'Player',
              style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _PlayerDropdown(
              players: _teamPlayers,
              value: _selectedPlayer,
              hint: 'Select player',
              onChanged: (p) => setState(() => _selectedPlayer = p),
            ),
          ],

          // Assist (goals only)
          if (_selectedType == MatchEventType.goal) ...[
            const SizedBox(height: 12),
            Text('Assist (optional)', style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            _PlayerDropdown(
              players: _teamPlayers,
              value: _assistPlayer,
              hint: 'Select assist (optional)',
              onChanged: (p) => setState(() => _assistPlayer = p),
            ),
          ],

          // Sub out (substitution only)
          if (_selectedType == MatchEventType.substitution) ...[
            const SizedBox(height: 12),
            Text('Player Out', style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            _PlayerDropdown(
              players: _teamPlayers,
              value: _subOutPlayer,
              hint: 'Select player out',
              onChanged: (p) => setState(() => _subOutPlayer = p),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: SkorioColors.secondary,
                foregroundColor: SkorioColors.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Event', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerDropdown extends StatelessWidget {
  final List<TournamentPlayer> players;
  final TournamentPlayer? value;
  final String hint;
  final ValueChanged<TournamentPlayer?> onChanged;

  const _PlayerDropdown({
    required this.players,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TournamentPlayer>(
      initialValue: value,
      hint: Text(hint),
      dropdownColor: SkorioColors.surface,
      decoration: InputDecoration(
        filled: true,
        fillColor: SkorioColors.surfaceBright,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: players.map((p) {
        return DropdownMenuItem(
          value: p,
          child: Text('#${p.jerseyNumber} ${p.name}'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Event Feed ───────────────────────────────────────────────────────────────

class _EventFeed extends StatelessWidget {
  final List<MatchEvent> events;
  final Tournament tournament;

  const _EventFeed({required this.events, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final reversed = events.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: reversed.length,
      itemBuilder: (_, i) => _EventTile(event: reversed[i], tournament: tournament),
    );
  }
}

class _EventTile extends StatelessWidget {
  final MatchEvent event;
  final Tournament tournament;

  const _EventTile({required this.event, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final isKickoffOrFT = event.type == MatchEventType.kickoff || event.type == MatchEventType.fullTime;
    final team = tournament.teams.firstWhere(
      (t) => t.id == event.teamId,
      orElse: () => TournamentTeam(id: '', name: '', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );

    if (isKickoffOrFT) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${event.type.emoji}  ${event.type.label}',
                style: SkorioTextStyles.labelMd.copyWith(color: SkorioColors.outline),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              "${event.minute}'",
              style: SkorioTextStyles.labelMd.copyWith(
                color: SkorioColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(event.type.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.playerName.isEmpty ? event.type.label : event.playerName,
                  style: SkorioTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
                ),
                if (event.assistPlayerName != null && event.assistPlayerName!.isNotEmpty)
                  Text('Assist: ${event.assistPlayerName}', style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                if (event.subOutPlayerName != null && event.subOutPlayerName!.isNotEmpty)
                  Text('Out: ${event.subOutPlayerName}', style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.onSurfaceVariant)),
                if (team.name.isNotEmpty)
                  Text(team.name, style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.outline)),
              ],
            ),
          ),
          if (team.logoUrl.isNotEmpty)
            Text(team.logoUrl, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final bool isLive;
  const _EmptyFeed({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📭', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isLive ? 'No events yet' : 'Match not started',
            style: SkorioTextStyles.headlineMd.copyWith(color: SkorioColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            isLive ? 'Events will appear here in real-time' : 'Admin will start the match soon',
            style: SkorioTextStyles.bodyMd.copyWith(color: SkorioColors.outline),
          ),
        ],
      ),
    );
  }
}
