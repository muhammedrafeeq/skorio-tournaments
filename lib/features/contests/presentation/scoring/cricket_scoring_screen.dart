import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../providers/tournaments_provider.dart';
import '../../providers/scoring/cricket_scoring_provider.dart';

class CricketScoringScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;
  const CricketScoringScreen({super.key, required this.tournamentId, required this.matchId});

  @override
  ConsumerState<CricketScoringScreen> createState() => _CricketScoringScreenState();
}

class _CricketScoringScreenState extends ConsumerState<CricketScoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cricketScoringProvider.notifier).loadMatch(widget.tournamentId, widget.matchId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cricketScoringProvider);

    if (state.needsTossSetup || state.matchState == null) {
      return _SetupScreen(tournamentId: widget.tournamentId, matchId: widget.matchId);
    }

    final ms = state.matchState!;
    final innings = ms.currentInningsState;

    // Listen for bowler/batsman selection triggers — fires only on state change, not every rebuild
    ref.listen<CricketScoringState>(cricketScoringProvider, (prev, next) {
      if (next.matchState == null) return;
      final newMs = next.matchState!;
      if (next.needsNewBowler && !(prev?.needsNewBowler ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSelectBowlerDialog(context, newMs);
        });
      } else if (next.needsNewBatsman && !(prev?.needsNewBatsman ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSelectBatsmanDialog(context, newMs);
        });
      }
    });

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ms, innings),
            _buildScoreBoard(ms, innings),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildBallInput(context, innings, ms),
                  _buildBattingCard(innings),
                  _buildBowlingCard(innings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CricketMatchState ms, CricketInningsState innings) {
    final tournament = ref.watch(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: ''));
    final battingTeam = tournament.teams.firstWhere(
      (t) => t.id == innings.battingTeamId,
      orElse: () => TournamentTeam(id: '', name: innings.battingTeamId,
          logoUrl: '🏏', primaryColor: '', secondaryColor: '', players: []));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => context.pop()),
          Expanded(
            child: Text(
              ms.config.isTwoInnings
                  ? 'Innings ${ms.currentInnings} — ${battingTeam.name}'
                  : battingTeam.name,
              style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white54),
            onPressed: () => ref.read(cricketScoringProvider.notifier).undoLastBall(),
          ),
          if (ms.currentInnings == 1 && ms.config.isTwoInnings && innings.isComplete)
            TextButton(
              onPressed: () => ref.read(cricketScoringProvider.notifier).startSecondInnings(),
              child: const Text('2nd Inn', style: TextStyle(color: SkorioColors.secondary)),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard(CricketMatchState ms, CricketInningsState innings) {
    final striker = innings.batters.firstWhere(
      (b) => b.name == innings.currentStrikerId && !b.isOut,
      orElse: () => BatterCard(name: innings.currentStrikerId));
    final bowler = innings.bowlers.firstWhere(
      (b) => b.name == innings.currentBowlerId,
      orElse: () => BowlerFigures(name: innings.currentBowlerId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SkorioColors.secondary.withValues(alpha: 0.12), Colors.transparent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${innings.runs}/${innings.wickets}',
                style: const TextStyle(color: Colors.white, fontSize: 40,
                    fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Text('(${innings.oversDisplay})',
                style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 4),
          if (innings.target != null)
            Text('Target: ${innings.target}  •  Need ${(innings.target! - innings.runs).clamp(0, 9999)} off '
                '${((ms.config.maxOvers - innings.completedOvers) * 6 - innings.ballsInOver).clamp(0, 9999)} balls',
              style: SkorioTextStyles.labelSm.copyWith(color: SkorioColors.secondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniStat('🏏 ${striker.name}',
                  '${striker.runs}(${striker.balls})  SR: ${striker.strikeRate.toStringAsFixed(1)}')),
              Container(width: 1, height: 32, color: Colors.white10),
              Expanded(child: _miniStat('🎳 ${bowler.name}',
                  '${bowler.displayOvers}-${bowler.wickets}-${bowler.runsConceded}'
                  '  Eco: ${bowler.economy.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: 8),
          // Current over balls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('This over: ', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30)),
              ...innings.currentOverBalls.map((b) => Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _ballColor(b.type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _ballColor(b.type).withValues(alpha: 0.5)),
                ),
                child: Text(b.type.label,
                  style: TextStyle(color: _ballColor(b.type), fontSize: 11, fontWeight: FontWeight.w700)),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SkorioTextStyles.labelSm.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        Text(sub, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white38, fontSize: 10)),
      ],
    ),
  );

  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
    child: TabBar(
      controller: _tabs,
      indicatorColor: SkorioColors.secondary,
      labelColor: SkorioColors.secondary,
      unselectedLabelColor: Colors.white30,
      labelStyle: SkorioTextStyles.labelSm.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
      tabs: const [Tab(text: 'SCORING'), Tab(text: 'BATTING'), Tab(text: 'BOWLING')],
    ),
  );

  Widget _buildBallInput(BuildContext context, CricketInningsState innings, CricketMatchState ms) {
    if (innings.isComplete) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ms.resultSummary ?? 'Innings complete',
              style: SkorioTextStyles.headlineLg.copyWith(color: SkorioColors.secondary),
              textAlign: TextAlign.center),
            if (ms.winnerId != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SkorioColors.secondary,
                  foregroundColor: SkorioColors.onSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.pop(),
                child: const Text('Finish Match', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      );
    }

    final ballTypes = [
      BallEventType.dot, BallEventType.one, BallEventType.two,
      BallEventType.three, BallEventType.four, BallEventType.six,
      BallEventType.wide, BallEventType.noBall, BallEventType.bye,
      BallEventType.legBye, BallEventType.wicket,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: ballTypes.map((type) {
              final isWicket = type == BallEventType.wicket;
              return GestureDetector(
                onTap: () {
                  if (isWicket) {
                    _showWicketDialog(context, innings, ms);
                  } else {
                    ref.read(cricketScoringProvider.notifier).recordBall(BallEvent(
                      type: type,
                      batsman: innings.currentStrikerId,
                      bowler: innings.currentBowlerId,
                      overNumber: innings.completedOvers,
                      ballInOver: innings.ballsInOver,
                    ));
                  }
                },
                child: Container(
                  width: 70, height: 60,
                  decoration: BoxDecoration(
                    color: _ballColor(type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ballColor(type).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(type.label,
                        style: TextStyle(color: _ballColor(type), fontSize: 18,
                            fontWeight: FontWeight.w900)),
                      Text(_ballSubLabel(type),
                        style: TextStyle(color: _ballColor(type).withValues(alpha: 0.7),
                            fontSize: 9)),
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

  Widget _buildBattingCard(CricketInningsState innings) {
    final batters = innings.batters.where((b) => b.balls > 0 || b.isOut || b.name == innings.currentStrikerId || b.name == innings.currentNonStrikerId).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _tableHeader(['BATTER', 'R', 'B', '4s', '6s', 'SR']),
        ...batters.map((b) {
          final isStriker = b.name == innings.currentStrikerId;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
            child: Row(
              children: [
                Expanded(flex: 5, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (isStriker) const Text('* ', style: TextStyle(color: SkorioColors.secondary, fontWeight: FontWeight.w900)),
                      Expanded(child: Text(b.name,
                        style: SkorioTextStyles.labelSm.copyWith(
                          color: b.isOut ? Colors.white30 : Colors.white,
                          fontWeight: isStriker ? FontWeight.bold : FontWeight.normal),
                        overflow: TextOverflow.ellipsis)),
                    ]),
                    if (b.dismissal != null)
                      Text(b.dismissal!,
                        style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 9)),
                  ],
                )),
                _tableCell('${b.runs}', bold: true, color: b.runs >= 50 ? SkorioColors.secondary : Colors.white),
                _tableCell('${b.balls}'),
                _tableCell('${b.fours}'),
                _tableCell('${b.sixes}'),
                _tableCell(b.strikeRate.toStringAsFixed(1)),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          Text('Extras: ${innings.extras}', style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30)),
          const Spacer(),
          Text('FOW: ${innings.fallOfWickets.join("  ")}',
            style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 10),
            overflow: TextOverflow.ellipsis),
        ]),
      ],
    );
  }

  Widget _buildBowlingCard(CricketInningsState innings) {
    final bowlers = innings.bowlers.where((b) => b.ballsBowled > 0 || b.completedOvers > 0).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _tableHeader(['BOWLER', 'O', 'M', 'R', 'W', 'ECO']),
        ...bowlers.map((b) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
          child: Row(
            children: [
              Expanded(flex: 5, child: Text(b.name,
                style: SkorioTextStyles.labelSm.copyWith(
                  color: b.name == innings.currentBowlerId ? SkorioColors.secondary : Colors.white),
                overflow: TextOverflow.ellipsis)),
              _tableCell(b.displayOvers),
              _tableCell('${b.maidens}'),
              _tableCell('${b.runsConceded}'),
              _tableCell('${b.wickets}', bold: true, color: b.wickets >= 3 ? SkorioColors.secondary : Colors.white),
              _tableCell(b.economy.toStringAsFixed(2)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _tableHeader(List<String> cols) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(flex: 5, child: Text(cols[0],
        style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 11))),
      ...cols.skip(1).map((c) => Expanded(child: Text(c, textAlign: TextAlign.center,
        style: SkorioTextStyles.labelSm.copyWith(color: Colors.white24, fontSize: 11)))),
    ]),
  );

  Widget _tableCell(String v, {bool bold = false, Color? color}) => Expanded(
    child: Text(v, textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? Colors.white70, fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
  );

  void _showWicketDialog(BuildContext context, CricketInningsState innings, CricketMatchState ms) {
    WicketType selectedType = WicketType.bowled;
    final fielderCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: SkorioColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: SkorioColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Wicket', style: SkorioTextStyles.headlineMd),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8,
                children: WicketType.values.map((t) => ChoiceChip(
                  label: Text(t.name, style: TextStyle(fontSize: 12,
                    color: selectedType == t ? SkorioColors.onSecondary : Colors.white70)),
                  selected: selectedType == t,
                  selectedColor: SkorioColors.secondary,
                  backgroundColor: Colors.white10,
                  onSelected: (_) => setSt(() => selectedType = t),
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fielderCtrl,
                decoration: InputDecoration(
                  labelText: 'Fielder (catcher / run-out / stumper)',
                  filled: true, fillColor: SkorioColors.surfaceBright,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(cricketScoringProvider.notifier).recordBall(BallEvent(
                      type: BallEventType.wicket,
                      batsman: innings.currentStrikerId,
                      bowler: innings.currentBowlerId,
                      overNumber: innings.completedOvers,
                      ballInOver: innings.ballsInOver,
                      wicketType: selectedType,
                      fielder: fielderCtrl.text.trim().isEmpty ? null : fielderCtrl.text.trim(),
                    ));
                  },
                  child: const Text('Record Wicket', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                )),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectBowlerDialog(BuildContext context, CricketMatchState ms) {
    final innings = ms.currentInningsState;
    final bowlingTeamId = innings.bowlingTeamId;
    final tournament = ref.read(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: ''));
    final bowlingTeam = tournament.teams.firstWhere(
      (t) => t.id == bowlingTeamId,
      orElse: () => TournamentTeam(id: '', name: '', logoUrl: '', primaryColor: '', secondaryColor: '', players: []));
    final eligibleBowlers = bowlingTeam.players.where((p) {
      final bf = innings.bowlers.firstWhere((b) => b.name == p.name,
          orElse: () => BowlerFigures(name: p.name, oversBowlingLimit: ms.config.maxOversPerBowler));
      return !bf.hasReachedLimit && p.name != innings.currentBowlerId;
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SkorioColors.surface,
        title: Text('Select Bowler', style: SkorioTextStyles.headlineMd),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: eligibleBowlers.map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(cricketScoringProvider.notifier).setBowler(p.name);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showSelectBatsmanDialog(BuildContext context, CricketMatchState ms) {
    final innings = ms.currentInningsState;
    final battingTeamId = innings.battingTeamId;
    final tournament = ref.read(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: ''));
    final battingTeam = tournament.teams.firstWhere(
      (t) => t.id == battingTeamId,
      orElse: () => TournamentTeam(id: '', name: '', logoUrl: '', primaryColor: '', secondaryColor: '', players: []));
    final available = battingTeam.players.where((p) {
      final card = innings.batters.firstWhere((b) => b.name == p.name,
          orElse: () => BatterCard(name: p.name));
      return !card.isOut && p.name != innings.currentStrikerId && p.name != innings.currentNonStrikerId;
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SkorioColors.surface,
        title: Text('New Batsman', style: SkorioTextStyles.headlineMd),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: available.map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(cricketScoringProvider.notifier).setNewBatsman(p.name);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  Color _ballColor(BallEventType type) {
    switch (type) {
      case BallEventType.four:   return Colors.blue;
      case BallEventType.six:    return SkorioColors.secondary;
      case BallEventType.wide:   return Colors.orange;
      case BallEventType.noBall: return Colors.orange;
      case BallEventType.wicket: return Colors.red;
      case BallEventType.dot:    return Colors.white24;
      default:                   return Colors.white70;
    }
  }

  String _ballSubLabel(BallEventType type) {
    switch (type) {
      case BallEventType.dot:    return 'Dot';
      case BallEventType.wide:   return 'Wide';
      case BallEventType.noBall: return 'No Ball';
      case BallEventType.bye:    return 'Bye';
      case BallEventType.legBye: return 'Leg Bye';
      case BallEventType.wicket: return 'Wicket';
      default:                   return 'Runs';
    }
  }
}

// ─── Setup Screen ─────────────────────────────────────────────────────────────

class _SetupScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;
  const _SetupScreen({required this.tournamentId, required this.matchId});

  @override
  ConsumerState<_SetupScreen> createState() => _SetupScreenState();
}

// Cricket player roles
enum CricketRole { bat, bowl, ar, wk }

extension CricketRoleX on CricketRole {
  String get label {
    switch (this) {
      case CricketRole.bat:  return 'BAT';
      case CricketRole.bowl: return 'BOWL';
      case CricketRole.ar:   return 'AR';
      case CricketRole.wk:   return 'WK';
    }
  }
  String get full {
    switch (this) {
      case CricketRole.bat:  return 'Batsman';
      case CricketRole.bowl: return 'Bowler';
      case CricketRole.ar:   return 'All-Rounder';
      case CricketRole.wk:   return 'Wicket-Keeper';
    }
  }
  Color get color {
    switch (this) {
      case CricketRole.bat:  return Colors.blue;
      case CricketRole.bowl: return Colors.orange;
      case CricketRole.ar:   return Colors.purple;
      case CricketRole.wk:   return Colors.green;
    }
  }
}

class _CricketPlayer {
  final String name;
  final int jersey;
  CricketRole role;
  _CricketPlayer({required this.name, required this.jersey, this.role = CricketRole.bat});
}

class _SetupScreenState extends ConsumerState<_SetupScreen> {
  int _maxOvers = 20;
  int _maxOversPerBowler = 4;
  String? _battingTeamId;
  String? _bowlingTeamId;

  // per-team player lists built from roster, editable roles
  Map<String, List<_CricketPlayer>> _squadMap = {};

  void _initSquads(TournamentTeam home, TournamentTeam away) {
    for (final team in [home, away]) {
      if (!_squadMap.containsKey(team.id)) {
        _squadMap[team.id] = team.players.map((p) {
          CricketRole role = CricketRole.bat;
          final pos = p.position.toLowerCase();
          if (pos.contains('bowl')) { role = CricketRole.bowl; }
          else if (pos.contains('all') || pos.contains('ar')) { role = CricketRole.ar; }
          else if (pos.contains('wk') || pos.contains('keeper') || pos.contains('wicket')) { role = CricketRole.wk; }
          return _CricketPlayer(name: p.name, jersey: p.jerseyNumber, role: role);
        }).toList();
      }
    }
  }

  void _addPlayer(String teamId) {
    final nameCtrl = TextEditingController();
    final jerseyCtrl = TextEditingController();
    CricketRole role = CricketRole.bat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: SkorioColors.surface,
          title: const Text('Add Player', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Player Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jerseyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Jersey #',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft,
                child: Text('Role', style: TextStyle(color: Colors.white54, fontSize: 12))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: CricketRole.values.map((r) => ChoiceChip(
                  label: Text(r.full, style: TextStyle(fontSize: 12,
                      color: role == r ? Colors.white : Colors.white70)),
                  selected: role == r,
                  selectedColor: r.color.withValues(alpha: 0.7),
                  backgroundColor: Colors.white10,
                  onSelected: (_) => setS(() => role = r),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  _squadMap[teamId] ??= [];
                  _squadMap[teamId]!.add(_CricketPlayer(
                    name: name,
                    jersey: int.tryParse(jerseyCtrl.text) ?? 0,
                    role: role,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tournament = ref.watch(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == widget.tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: ''));
    final match = tournament.matches.firstWhere((m) => m.id == widget.matchId,
        orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '',
            date: DateTime.now(), status: '', venue: ''));
    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'Home', logoUrl: '🏏', primaryColor: '', secondaryColor: '', players: []));
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'Away', logoUrl: '🏏', primaryColor: '', secondaryColor: '', players: []));

    _battingTeamId ??= match.homeTeamId;
    _bowlingTeamId ??= match.awayTeamId;
    _initSquads(homeTeam, awayTeam);

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => context.pop()),
                Text('Match Setup', style: SkorioTextStyles.headlineMd.copyWith(color: Colors.white)),
              ]),
              const SizedBox(height: 24),

              // ── Overs Settings ───────────────────────────────────────────
              Text('OVERS SETTINGS', style: SkorioTextStyles.labelSm.copyWith(
                  color: Colors.white30, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _oversStepper('Total Overs', _maxOvers, 1, 50,
                        (v) => setState(() => _maxOvers = v)),
                    const Divider(color: Colors.white10),
                    _oversStepper('Max Overs/Bowler', _maxOversPerBowler, 0, 20,
                        (v) => setState(() => _maxOversPerBowler = v),
                        hint: '0 = no limit'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Toss ────────────────────────────────────────────────────
              Text('TOSS — WHO BATS FIRST?', style: SkorioTextStyles.labelSm.copyWith(
                  color: Colors.white30, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [homeTeam, awayTeam].map((team) {
                final isBatting = _battingTeamId == team.id;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _battingTeamId = team.id;
                      _bowlingTeamId = team.id == match.homeTeamId
                          ? match.awayTeamId : match.homeTeamId;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isBatting
                            ? SkorioColors.secondary.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBatting ? SkorioColors.secondary : Colors.white12,
                          width: isBatting ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(team.logoUrl, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(team.name,
                            style: SkorioTextStyles.labelMd.copyWith(
                              color: isBatting ? SkorioColors.secondary : Colors.white54,
                              fontWeight: isBatting ? FontWeight.w700 : FontWeight.normal),
                            textAlign: TextAlign.center),
                          if (isBatting)
                            const Text('BATTING', style: TextStyle(
                              color: SkorioColors.secondary, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 24),

              // ── Squad Builder ────────────────────────────────────────────
              for (final team in [homeTeam, awayTeam]) ...[
                _buildSquadSection(team),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SkorioColors.secondary,
                    foregroundColor: SkorioColors.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _battingTeamId == null ? null : () {
                    final battingTeam = tournament.teams.firstWhere(
                      (t) => t.id == _battingTeamId, orElse: () => homeTeam);
                    final bowlingTeam = tournament.teams.firstWhere(
                      (t) => t.id == _bowlingTeamId, orElse: () => awayTeam);

                    // Convert _CricketPlayer → TournamentPlayer for the provider
                    TournamentPlayer _toPlayer(_CricketPlayer p) => TournamentPlayer(
                      id: p.name, name: p.name,
                      jerseyNumber: p.jersey, position: p.role.label,
                    );

                    final battingPlayers = (_squadMap[battingTeam.id] ?? []).map(_toPlayer).toList();
                    final bowlingPlayers = (_squadMap[bowlingTeam.id] ?? []).map(_toPlayer).toList();

                    ref.read(cricketScoringProvider.notifier).setupMatch(
                      config: CricketMatchConfig(
                        maxOvers: _maxOvers,
                        maxOversPerBowler: _maxOversPerBowler,
                      ),
                      battingTeamId: battingTeam.id,
                      bowlingTeamId: bowlingTeam.id,
                      battingPlayers: battingPlayers,
                      bowlingPlayers: bowlingPlayers,
                    );
                  },
                  child: const Text('Start Match', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquadSection(TournamentTeam team) {
    final squad = _squadMap[team.id] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(team.name.toUpperCase(),
                style: SkorioTextStyles.labelSm.copyWith(
                    color: Colors.white30, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => _addPlayer(team.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SkorioColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SkorioColors.secondary.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, color: SkorioColors.secondary, size: 14),
                  const SizedBox(width: 4),
                  Text('Add Player', style: SkorioTextStyles.labelSm.copyWith(
                      color: SkorioColors.secondary, fontSize: 11)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (squad.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text('No players added. Tap + Add Player.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: squad.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: i < squad.length - 1 ? Colors.white10 : Colors.transparent)),
                  ),
                  child: Row(
                    children: [
                      // Jersey
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: Text('${p.jersey}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p.name,
                          style: SkorioTextStyles.labelMd.copyWith(color: Colors.white))),
                      // Role chips
                      Wrap(
                        spacing: 4,
                        children: CricketRole.values.map((r) {
                          final sel = p.role == r;
                          return GestureDetector(
                            onTap: () => setState(() => p.role = r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: sel ? r.color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: sel ? r.color.withValues(alpha: 0.7) : Colors.white12,
                                ),
                              ),
                              child: Text(r.label, style: TextStyle(
                                color: sel ? r.color : Colors.white30,
                                fontSize: 10, fontWeight: FontWeight.w700,
                              )),
                            ),
                          );
                        }).toList(),
                      ),
                      // Remove
                      GestureDetector(
                        onTap: () => setState(() => _squadMap[team.id]!.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, color: Colors.white24, size: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _oversStepper(String label, int value, int min, int max, ValueChanged<int> onChanged, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SkorioTextStyles.labelMd.copyWith(color: Colors.white)),
              if (hint != null)
                Text(hint, style: SkorioTextStyles.labelSm.copyWith(color: Colors.white30, fontSize: 10)),
            ],
          )),
          Row(children: [
            _stepBtn(Icons.remove, () { if (value > min) onChanged(value - 1); }),
            SizedBox(width: 48,
              child: Text('$value', textAlign: TextAlign.center,
                style: SkorioTextStyles.headlineMd.copyWith(color: SkorioColors.secondary,
                    fontWeight: FontWeight.w900))),
            _stepBtn(Icons.add, () { if (value < max) onChanged(value + 1); }),
          ]),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white54, size: 18),
    ),
  );
}
