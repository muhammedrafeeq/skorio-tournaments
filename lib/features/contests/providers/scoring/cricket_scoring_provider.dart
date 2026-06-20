import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tournaments_provider.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum BallEventType { dot, one, two, three, four, six, wide, noBall, bye, legBye, wicket }

enum WicketType { bowled, caught, lbw, runOut, stumped, hitWicket, retired }

extension BallEventTypeX on BallEventType {
  String get label {
    switch (this) {
      case BallEventType.dot:    return '•';
      case BallEventType.one:    return '1';
      case BallEventType.two:    return '2';
      case BallEventType.three:  return '3';
      case BallEventType.four:   return '4';
      case BallEventType.six:    return '6';
      case BallEventType.wide:   return 'Wd';
      case BallEventType.noBall: return 'Nb';
      case BallEventType.bye:    return 'B';
      case BallEventType.legBye: return 'Lb';
      case BallEventType.wicket: return 'W';
    }
  }

  // runs credited to batsman
  int runsToStriker(int extraRuns) {
    switch (this) {
      case BallEventType.one:   return 1;
      case BallEventType.two:   return 2;
      case BallEventType.three: return 3;
      case BallEventType.four:  return 4;
      case BallEventType.six:   return 6;
      default:                  return 0;
    }
  }

  // total runs added to innings score
  int totalRuns(int extraRuns) {
    switch (this) {
      case BallEventType.one:    return 1;
      case BallEventType.two:    return 2;
      case BallEventType.three:  return 3;
      case BallEventType.four:   return 4;
      case BallEventType.six:    return 6;
      case BallEventType.wide:   return 1 + extraRuns;
      case BallEventType.noBall: return 1 + extraRuns;
      case BallEventType.bye:    return extraRuns > 0 ? extraRuns : 1;
      case BallEventType.legBye: return extraRuns > 0 ? extraRuns : 1;
      default:                   return 0;
    }
  }

  // whether this delivery counts as a legal ball (advances ball count)
  bool get isLegalDelivery {
    return this != BallEventType.wide && this != BallEventType.noBall;
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class BallEvent {
  final BallEventType type;
  final int extraRuns;       // e.g. for no-ball + 3 runs = 3 extra
  final String batsman;
  final String bowler;
  final WicketType? wicketType;
  final String? fielder;     // catcher / run-out fielder / stumper
  final int overNumber;      // 0-indexed
  final int ballInOver;      // 0-5 legal ball index

  const BallEvent({
    required this.type,
    required this.batsman,
    required this.bowler,
    required this.overNumber,
    required this.ballInOver,
    this.extraRuns = 0,
    this.wicketType,
    this.fielder,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'extra_runs': extraRuns,
    'batsman': batsman,
    'bowler': bowler,
    'wicket_type': wicketType?.name,
    'fielder': fielder,
    'over_number': overNumber,
    'ball_in_over': ballInOver,
  };

  factory BallEvent.fromJson(Map<String, dynamic> j) => BallEvent(
    type: BallEventType.values.byName(j['type']),
    extraRuns: j['extra_runs'] ?? 0,
    batsman: j['batsman'] ?? '',
    bowler: j['bowler'] ?? '',
    overNumber: j['over_number'] ?? 0,
    ballInOver: j['ball_in_over'] ?? 0,
    wicketType: j['wicket_type'] != null
        ? WicketType.values.byName(j['wicket_type']) : null,
    fielder: j['fielder'],
  );
}

class BatterCard {
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isOut;
  final bool isStriker;
  final String? dismissal; // "c Smith b Jones"

  const BatterCard({
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.isStriker = false,
    this.dismissal,
  });

  double get strikeRate => balls > 0 ? (runs / balls * 100) : 0;

  BatterCard copyWith({
    int? runs, int? balls, int? fours, int? sixes,
    bool? isOut, bool? isStriker, String? dismissal,
  }) => BatterCard(
    name: name,
    runs: runs ?? this.runs,
    balls: balls ?? this.balls,
    fours: fours ?? this.fours,
    sixes: sixes ?? this.sixes,
    isOut: isOut ?? this.isOut,
    isStriker: isStriker ?? this.isStriker,
    dismissal: dismissal ?? this.dismissal,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'runs': runs, 'balls': balls, 'fours': fours, 'sixes': sixes,
    'is_out': isOut, 'is_striker': isStriker, 'dismissal': dismissal,
  };

  factory BatterCard.fromJson(Map<String, dynamic> j) => BatterCard(
    name: j['name'] ?? '', runs: j['runs'] ?? 0, balls: j['balls'] ?? 0,
    fours: j['fours'] ?? 0, sixes: j['sixes'] ?? 0, isOut: j['is_out'] ?? false,
    isStriker: j['is_striker'] ?? false, dismissal: j['dismissal'],
  );
}

class BowlerFigures {
  final String name;
  final int completedOvers;
  final int ballsBowled; // in current over (0-5)
  final int maidens;
  final int runsConceded;
  final int wickets;
  final int oversBowlingLimit; // 0 = no limit

  const BowlerFigures({
    required this.name,
    this.completedOvers = 0,
    this.ballsBowled = 0,
    this.maidens = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.oversBowlingLimit = 0,
  });

  bool get hasReachedLimit =>
      oversBowlingLimit > 0 && completedOvers >= oversBowlingLimit;

  String get figures =>
      '${completedOvers + (ballsBowled > 0 ? 1 : 0) - (ballsBowled > 0 ? 0 : 0)}'
      '–$runsConceded–$wickets'; // simplified

  String get displayOvers => ballsBowled > 0
      ? '$completedOvers.$ballsBowled' : '$completedOvers';

  double get economy => completedOvers > 0
      ? runsConceded / (completedOvers + ballsBowled / 6) : 0;

  BowlerFigures copyWith({
    int? completedOvers, int? ballsBowled, int? maidens,
    int? runsConceded, int? wickets,
  }) => BowlerFigures(
    name: name,
    completedOvers: completedOvers ?? this.completedOvers,
    ballsBowled: ballsBowled ?? this.ballsBowled,
    maidens: maidens ?? this.maidens,
    runsConceded: runsConceded ?? this.runsConceded,
    wickets: wickets ?? this.wickets,
    oversBowlingLimit: oversBowlingLimit,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'completed_overs': completedOvers, 'balls_bowled': ballsBowled,
    'maidens': maidens, 'runs_conceded': runsConceded, 'wickets': wickets,
    'overs_limit': oversBowlingLimit,
  };

  factory BowlerFigures.fromJson(Map<String, dynamic> j) => BowlerFigures(
    name: j['name'] ?? '', completedOvers: j['completed_overs'] ?? 0,
    ballsBowled: j['balls_bowled'] ?? 0, maidens: j['maidens'] ?? 0,
    runsConceded: j['runs_conceded'] ?? 0, wickets: j['wickets'] ?? 0,
    oversBowlingLimit: j['overs_limit'] ?? 0,
  );
}

class CricketInningsState {
  final String battingTeamId;
  final String bowlingTeamId;
  final int runs;
  final int wickets;
  final int completedOvers;
  final int ballsInOver; // 0-5 legal deliveries
  final List<BallEvent> balls;
  final List<BatterCard> batters;
  final List<BowlerFigures> bowlers;
  final String currentStrikerId;
  final String currentNonStrikerId;
  final String currentBowlerId;
  final bool isComplete;
  final int? target; // for 2nd innings
  final List<String> fallOfWickets; // ["1/23 (Smith, 4.2)", ...]
  final int extras;

  const CricketInningsState({
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.runs = 0,
    this.wickets = 0,
    this.completedOvers = 0,
    this.ballsInOver = 0,
    this.balls = const [],
    this.batters = const [],
    this.bowlers = const [],
    this.currentStrikerId = '',
    this.currentNonStrikerId = '',
    this.currentBowlerId = '',
    this.isComplete = false,
    this.target,
    this.fallOfWickets = const [],
    this.extras = 0,
  });

  String get oversDisplay => '$completedOvers.$ballsInOver';

  double get runRate => (completedOvers + ballsInOver / 6) > 0
      ? runs / (completedOvers + ballsInOver / 6) : 0;

  // balls in current over as event list for the over-by-over display
  List<BallEvent> get currentOverBalls =>
      balls.where((b) => b.overNumber == completedOvers).toList();

  CricketInningsState copyWith({
    int? runs, int? wickets, int? completedOvers, int? ballsInOver,
    List<BallEvent>? balls, List<BatterCard>? batters, List<BowlerFigures>? bowlers,
    String? currentStrikerId, String? currentNonStrikerId, String? currentBowlerId,
    bool? isComplete, int? target, List<String>? fallOfWickets, int? extras,
  }) => CricketInningsState(
    battingTeamId: battingTeamId,
    bowlingTeamId: bowlingTeamId,
    runs: runs ?? this.runs,
    wickets: wickets ?? this.wickets,
    completedOvers: completedOvers ?? this.completedOvers,
    ballsInOver: ballsInOver ?? this.ballsInOver,
    balls: balls ?? this.balls,
    batters: batters ?? this.batters,
    bowlers: bowlers ?? this.bowlers,
    currentStrikerId: currentStrikerId ?? this.currentStrikerId,
    currentNonStrikerId: currentNonStrikerId ?? this.currentNonStrikerId,
    currentBowlerId: currentBowlerId ?? this.currentBowlerId,
    isComplete: isComplete ?? this.isComplete,
    target: target ?? this.target,
    fallOfWickets: fallOfWickets ?? this.fallOfWickets,
    extras: extras ?? this.extras,
  );

  Map<String, dynamic> toJson() => {
    'batting_team_id': battingTeamId,
    'bowling_team_id': bowlingTeamId,
    'runs': runs, 'wickets': wickets,
    'completed_overs': completedOvers, 'balls_in_over': ballsInOver,
    'balls': balls.map((b) => b.toJson()).toList(),
    'batters': batters.map((b) => b.toJson()).toList(),
    'bowlers': bowlers.map((b) => b.toJson()).toList(),
    'striker_id': currentStrikerId, 'non_striker_id': currentNonStrikerId,
    'bowler_id': currentBowlerId, 'is_complete': isComplete,
    'target': target, 'fall_of_wickets': fallOfWickets, 'extras': extras,
  };

  factory CricketInningsState.fromJson(Map<String, dynamic> j) => CricketInningsState(
    battingTeamId: j['batting_team_id'] ?? '',
    bowlingTeamId: j['bowling_team_id'] ?? '',
    runs: j['runs'] ?? 0, wickets: j['wickets'] ?? 0,
    completedOvers: j['completed_overs'] ?? 0, ballsInOver: j['balls_in_over'] ?? 0,
    balls: (j['balls'] as List?)?.map((e) => BallEvent.fromJson(e)).toList() ?? [],
    batters: (j['batters'] as List?)?.map((e) => BatterCard.fromJson(e)).toList() ?? [],
    bowlers: (j['bowlers'] as List?)?.map((e) => BowlerFigures.fromJson(e)).toList() ?? [],
    currentStrikerId: j['striker_id'] ?? '', currentNonStrikerId: j['non_striker_id'] ?? '',
    currentBowlerId: j['bowler_id'] ?? '', isComplete: j['is_complete'] ?? false,
    target: j['target'], fallOfWickets: (j['fall_of_wickets'] as List?)?.cast<String>() ?? [],
    extras: j['extras'] ?? 0,
  );
}

class CricketMatchConfig {
  final int maxOvers;
  final int maxOversPerBowler; // 0 = no limit
  final int playersPerSide;
  final bool isTwoInnings;

  const CricketMatchConfig({
    this.maxOvers = 20,
    this.maxOversPerBowler = 4,
    this.playersPerSide = 11,
    this.isTwoInnings = false,
  });

  Map<String, dynamic> toJson() => {
    'max_overs': maxOvers, 'max_overs_per_bowler': maxOversPerBowler,
    'players_per_side': playersPerSide, 'is_two_innings': isTwoInnings,
  };

  factory CricketMatchConfig.fromJson(Map<String, dynamic> j) => CricketMatchConfig(
    maxOvers: j['max_overs'] ?? 20,
    maxOversPerBowler: j['max_overs_per_bowler'] ?? 4,
    playersPerSide: j['players_per_side'] ?? 11,
    isTwoInnings: j['is_two_innings'] ?? false,
  );
}

class CricketMatchState {
  final CricketMatchConfig config;
  final CricketInningsState innings1;
  final CricketInningsState? innings2;
  final int currentInnings; // 1 or 2
  final String? winnerId; // teamId or 'draw'
  final String? resultSummary; // "Team A won by 32 runs"

  const CricketMatchState({
    required this.config,
    required this.innings1,
    this.innings2,
    this.currentInnings = 1,
    this.winnerId,
    this.resultSummary,
  });

  CricketInningsState get currentInningsState =>
      currentInnings == 1 ? innings1 : (innings2 ?? innings1);

  CricketMatchState copyWith({
    CricketInningsState? innings1, CricketInningsState? innings2,
    int? currentInnings, String? winnerId, String? resultSummary,
  }) => CricketMatchState(
    config: config,
    innings1: innings1 ?? this.innings1,
    innings2: innings2 ?? this.innings2,
    currentInnings: currentInnings ?? this.currentInnings,
    winnerId: winnerId ?? this.winnerId,
    resultSummary: resultSummary ?? this.resultSummary,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'innings1': innings1.toJson(),
    'innings2': innings2?.toJson(),
    'current_innings': currentInnings,
    'winner_id': winnerId,
    'result_summary': resultSummary,
  };

  factory CricketMatchState.fromJson(Map<String, dynamic> j) => CricketMatchState(
    config: CricketMatchConfig.fromJson(j['config'] ?? {}),
    innings1: CricketInningsState.fromJson(j['innings1'] ?? {}),
    innings2: j['innings2'] != null ? CricketInningsState.fromJson(j['innings2']) : null,
    currentInnings: j['current_innings'] ?? 1,
    winnerId: j['winner_id'],
    resultSummary: j['result_summary'],
  );

  static CricketMatchState initial({
    required CricketMatchConfig config,
    required String battingTeamId,
    required String bowlingTeamId,
    required List<TournamentPlayer> battingPlayers,
    required List<TournamentPlayer> bowlingPlayers,
  }) {
    final batters = battingPlayers.map((p) =>
        BatterCard(name: p.name, isStriker: battingPlayers.indexOf(p) == 0)).toList();
    final bowlers = bowlingPlayers.map((p) =>
        BowlerFigures(name: p.name, oversBowlingLimit: config.maxOversPerBowler)).toList();
    return CricketMatchState(
      config: config,
      innings1: CricketInningsState(
        battingTeamId: battingTeamId,
        bowlingTeamId: bowlingTeamId,
        batters: batters,
        bowlers: bowlers,
        currentStrikerId: battingPlayers.isNotEmpty ? battingPlayers[0].name : '',
        currentNonStrikerId: battingPlayers.length > 1 ? battingPlayers[1].name : '',
        currentBowlerId: bowlingPlayers.isNotEmpty ? bowlingPlayers[0].name : '',
      ),
    );
  }
}

// ─── Notifier State ──────────────────────────────────────────────────────────

class CricketScoringState {
  final String tournamentId;
  final String matchId;
  final CricketMatchState? matchState;
  final bool isLoading;
  final String? error;
  final bool needsNewBowler; // true when over ends
  final bool needsNewBatsman; // true when wicket falls
  final bool needsTossSetup; // true before first ball

  const CricketScoringState({
    this.tournamentId = '',
    this.matchId = '',
    this.matchState,
    this.isLoading = false,
    this.error,
    this.needsNewBowler = false,
    this.needsNewBatsman = false,
    this.needsTossSetup = true,
  });

  CricketScoringState copyWith({
    String? tournamentId, String? matchId, CricketMatchState? matchState,
    bool? isLoading, String? error, bool? needsNewBowler,
    bool? needsNewBatsman, bool? needsTossSetup,
  }) => CricketScoringState(
    tournamentId: tournamentId ?? this.tournamentId,
    matchId: matchId ?? this.matchId,
    matchState: matchState ?? this.matchState,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    needsNewBowler: needsNewBowler ?? this.needsNewBowler,
    needsNewBatsman: needsNewBatsman ?? this.needsNewBatsman,
    needsTossSetup: needsTossSetup ?? this.needsTossSetup,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class CricketScoringNotifier extends Notifier<CricketScoringState> {
  @override
  CricketScoringState build() => const CricketScoringState();

  void loadMatch(String tournamentId, String matchId) {
    final tournament = ref.read(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '',
              location: '', bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0,
              teams: [], matches: [], prizes: '', creatorId: ''));
    final match = tournament.matches.firstWhere((m) => m.id == matchId,
        orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '',
            date: DateTime.now(), status: '', venue: ''));

    state = state.copyWith(tournamentId: tournamentId, matchId: matchId);

    if (match.sportData.containsKey('innings1')) {
      // Resume existing match
      final cricketState = CricketMatchState.fromJson(match.sportData);
      state = state.copyWith(matchState: cricketState, needsTossSetup: false);
    }
  }

  void setupMatch({
    required CricketMatchConfig config,
    required String battingTeamId,
    required String bowlingTeamId,
    required List<TournamentPlayer> battingPlayers,
    required List<TournamentPlayer> bowlingPlayers,
  }) {
    final cricketState = CricketMatchState.initial(
      config: config,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      battingPlayers: battingPlayers,
      bowlingPlayers: bowlingPlayers,
    );
    state = state.copyWith(matchState: cricketState, needsTossSetup: false);
    _persist();
  }

  void recordBall(BallEvent event) {
    final ms = state.matchState;
    if (ms == null) return;

    final innings = ms.currentInningsState;
    if (innings.isComplete) return;

    final ballRuns = event.type.totalRuns(event.extraRuns);
    final batterRuns = event.type.runsToStriker(event.extraRuns);
    final isLegal = event.type.isLegalDelivery;
    final isWicket = event.type == BallEventType.wicket;
    final isExtra = event.type == BallEventType.wide || event.type == BallEventType.noBall ||
        event.type == BallEventType.bye || event.type == BallEventType.legBye;

    // Update batter
    var batters = List<BatterCard>.from(innings.batters);
    final strikerIdx = batters.indexWhere((b) => b.name == innings.currentStrikerId);
    if (strikerIdx != -1) {
      final batter = batters[strikerIdx];
      var updated = batter.copyWith(
        runs: batter.runs + batterRuns,
        balls: batter.balls + (isLegal ? 1 : 0),
        fours: batter.fours + (event.type == BallEventType.four ? 1 : 0),
        sixes: batter.sixes + (event.type == BallEventType.six ? 1 : 0),
      );
      if (isWicket) {
        final dismissalText = _buildDismissal(event, batter.name);
        updated = updated.copyWith(isOut: true, isStriker: false, dismissal: dismissalText);
      }
      batters[strikerIdx] = updated;
    }

    // Update bowler
    var bowlers = List<BowlerFigures>.from(innings.bowlers);
    final bowlerIdx = bowlers.indexWhere((b) => b.name == innings.currentBowlerId);
    int newCompletedOvers = innings.completedOvers;
    int newBallsInOver = innings.ballsInOver;
    bool overComplete = false;

    if (bowlerIdx != -1) {
      final bowler = bowlers[bowlerIdx];
      int newBalls = bowler.ballsBowled + (isLegal ? 1 : 0);
      int newOvers = bowler.completedOvers;
      if (newBalls >= 6) { newBalls = 0; newOvers++; }
      // runs attributed to bowler = ball runs minus byes/leg byes
      final bowlerRuns = (event.type == BallEventType.bye || event.type == BallEventType.legBye)
          ? 0 : ballRuns;
      bowlers[bowlerIdx] = bowler.copyWith(
        ballsBowled: newBalls,
        completedOvers: newOvers,
        runsConceded: bowler.runsConceded + bowlerRuns,
        wickets: bowler.wickets + (isWicket ? 1 : 0),
      );
    }

    // Advance ball count
    if (isLegal) {
      newBallsInOver = innings.ballsInOver + 1;
      if (newBallsInOver >= 6) {
        newBallsInOver = 0;
        newCompletedOvers = innings.completedOvers + 1;
        overComplete = true;
      }
    }

    // Rotate strike on odd runs (only for legal deliveries ending the ball)
    bool rotateStrike = isLegal && (batterRuns % 2 == 1);
    String newStriker = innings.currentStrikerId;
    String newNonStriker = innings.currentNonStrikerId;
    if (rotateStrike) {
      newStriker = innings.currentNonStrikerId;
      newNonStriker = innings.currentStrikerId;
    }
    if (overComplete) {
      // At end of over, swap ends
      final tmp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = tmp;
    }

    // Fall of wickets
    var fow = List<String>.from(innings.fallOfWickets);
    if (isWicket) {
      fow.add('${innings.wickets + 1}/${innings.runs + ballRuns} (${event.batsman}, ${innings.completedOvers}.${innings.ballsInOver})');
    }

    // Check innings end
    final newWickets = innings.wickets + (isWicket ? 1 : 0);
    // fall back to config playersPerSide if no players registered
    final maxWickets = innings.batters.length > 1
        ? innings.batters.length - 1
        : ms.config.playersPerSide - 1;
    final newRuns = innings.runs + ballRuns;
    bool inningsEnds = newWickets >= maxWickets ||
        newCompletedOvers >= ms.config.maxOvers ||
        (ms.currentInnings == 2 && ms.innings2 != null && ms.innings2!.target != null &&
         newRuns >= (ms.innings2!.target ?? 999999));

    final updatedInnings = innings.copyWith(
      runs: newRuns,
      wickets: newWickets,
      completedOvers: newCompletedOvers,
      ballsInOver: newBallsInOver,
      balls: [...innings.balls, event],
      batters: batters,
      bowlers: bowlers,
      currentStrikerId: newStriker,
      currentNonStrikerId: newNonStriker,
      isComplete: inningsEnds,
      fallOfWickets: fow,
      extras: innings.extras + (isExtra ? ballRuns : 0),
    );

    CricketMatchState newMs;
    if (ms.currentInnings == 1) {
      newMs = ms.copyWith(innings1: updatedInnings);
    } else {
      newMs = ms.copyWith(innings2: updatedInnings);
    }

    // Determine match result if innings ends
    if (inningsEnds) {
      newMs = _resolveResult(newMs, ms.currentInnings);
    }

    state = state.copyWith(
      matchState: newMs,
      needsNewBowler: overComplete && !inningsEnds,
      needsNewBatsman: isWicket && !inningsEnds,
    );
    _persist();
  }

  void setBowler(String name) {
    final ms = state.matchState;
    if (ms == null) return;
    final innings = ms.currentInningsState;
    // Add bowler if not already in list
    var bowlers = List<BowlerFigures>.from(innings.bowlers);
    if (!bowlers.any((b) => b.name == name)) {
      bowlers.add(BowlerFigures(
        name: name,
        oversBowlingLimit: ms.config.maxOversPerBowler,
      ));
    }
    final updatedInnings = innings.copyWith(currentBowlerId: name, bowlers: bowlers);
    final newMs = ms.currentInnings == 1
        ? ms.copyWith(innings1: updatedInnings)
        : ms.copyWith(innings2: updatedInnings);
    state = state.copyWith(matchState: newMs, needsNewBowler: false);
    _persist();
  }

  void setNewBatsman(String name) {
    final ms = state.matchState;
    if (ms == null) return;
    final innings = ms.currentInningsState;
    var batters = List<BatterCard>.from(innings.batters);
    if (!batters.any((b) => b.name == name)) {
      batters.add(BatterCard(name: name, isStriker: true));
    } else {
      final idx = batters.indexWhere((b) => b.name == name);
      batters[idx] = batters[idx].copyWith(isStriker: true);
    }
    final updatedInnings = innings.copyWith(currentStrikerId: name, batters: batters);
    final newMs = ms.currentInnings == 1
        ? ms.copyWith(innings1: updatedInnings)
        : ms.copyWith(innings2: updatedInnings);
    state = state.copyWith(matchState: newMs, needsNewBatsman: false);
    _persist();
  }

  void startSecondInnings() {
    final ms = state.matchState;
    if (ms == null || !ms.config.isTwoInnings) return;
    final inn2 = CricketInningsState(
      battingTeamId: ms.innings1.bowlingTeamId,
      bowlingTeamId: ms.innings1.battingTeamId,
      target: ms.innings1.runs + 1,
      batters: ms.innings1.bowlers.map((b) => BatterCard(name: b.name)).toList(),
      bowlers: ms.innings1.batters.map((b) =>
          BowlerFigures(name: b.name, oversBowlingLimit: ms.config.maxOversPerBowler)).toList(),
    );
    state = state.copyWith(
      matchState: ms.copyWith(innings2: inn2, currentInnings: 2),
    );
    _persist();
  }

  void undoLastBall() {
    final ms = state.matchState;
    if (ms == null) return;
    final innings = ms.currentInningsState;
    if (innings.balls.isEmpty) return;

    final lastBall = innings.balls.last;
    final ballRuns = lastBall.type.totalRuns(lastBall.extraRuns);
    final batterRuns = lastBall.type.runsToStriker(lastBall.extraRuns);
    final isLegal = lastBall.type.isLegalDelivery;
    final wasWicket = lastBall.type == BallEventType.wicket;

    // Revert batter
    var batters = List<BatterCard>.from(innings.batters);
    final strikerIdx = batters.indexWhere((b) => b.name == lastBall.batsman);
    if (strikerIdx != -1) {
      final b = batters[strikerIdx];
      batters[strikerIdx] = b.copyWith(
        runs: (b.runs - batterRuns).clamp(0, 9999),
        balls: (b.balls - (isLegal ? 1 : 0)).clamp(0, 9999),
        fours: (b.fours - (lastBall.type == BallEventType.four ? 1 : 0)).clamp(0, 9999),
        sixes: (b.sixes - (lastBall.type == BallEventType.six ? 1 : 0)).clamp(0, 9999),
        isOut: wasWicket ? false : b.isOut,
        dismissal: wasWicket ? null : b.dismissal,
      );
    }

    // Revert bowler
    var bowlers = List<BowlerFigures>.from(innings.bowlers);
    final bowlerIdx = bowlers.indexWhere((b) => b.name == lastBall.bowler);
    if (bowlerIdx != -1) {
      final bw = bowlers[bowlerIdx];
      int newBalls = bw.ballsBowled - (isLegal ? 1 : 0);
      int newOvers = bw.completedOvers;
      if (newBalls < 0) { newBalls = 5; newOvers--; }
      final bowlerRuns = (lastBall.type == BallEventType.bye || lastBall.type == BallEventType.legBye)
          ? 0 : ballRuns;
      bowlers[bowlerIdx] = bw.copyWith(
        ballsBowled: newBalls.clamp(0, 5),
        completedOvers: newOvers.clamp(0, 9999),
        runsConceded: (bw.runsConceded - bowlerRuns).clamp(0, 9999),
        wickets: (bw.wickets - (wasWicket ? 1 : 0)).clamp(0, 9999),
      );
    }

    int newBallsInOver = innings.ballsInOver - (isLegal ? 1 : 0);
    int newCompletedOvers = innings.completedOvers;
    if (newBallsInOver < 0) { newBallsInOver = 5; newCompletedOvers--; }

    final updatedInnings = innings.copyWith(
      runs: (innings.runs - ballRuns).clamp(0, 9999),
      wickets: (innings.wickets - (wasWicket ? 1 : 0)).clamp(0, 9999),
      completedOvers: newCompletedOvers.clamp(0, 9999),
      ballsInOver: newBallsInOver,
      balls: innings.balls.sublist(0, innings.balls.length - 1),
      batters: batters,
      bowlers: bowlers,
      fallOfWickets: wasWicket && innings.fallOfWickets.isNotEmpty
          ? innings.fallOfWickets.sublist(0, innings.fallOfWickets.length - 1)
          : innings.fallOfWickets,
    );

    final newMs = ms.currentInnings == 1
        ? ms.copyWith(innings1: updatedInnings)
        : ms.copyWith(innings2: updatedInnings);
    state = state.copyWith(matchState: newMs, needsNewBowler: false, needsNewBatsman: false);
    _persist();
  }

  CricketMatchState _resolveResult(CricketMatchState ms, int inningsJustEnded) {
    if (inningsJustEnded == 1 && ms.config.isTwoInnings) return ms; // need 2nd innings
    final inn1 = ms.innings1;
    final inn2 = ms.innings2 ?? inn1;
    String? winner;
    String summary;
    if (inn1.runs > inn2.runs) {
      winner = inn1.battingTeamId;
      summary = 'won by ${inn1.runs - inn2.runs} runs';
    } else if (inn2.runs > inn1.runs) {
      winner = inn2.battingTeamId;
      final wicketsLeft = (inn2.batters.length - 1) - inn2.wickets;
      summary = 'won by $wicketsLeft wickets';
    } else {
      winner = 'tie';
      summary = 'Match tied';
    }
    return ms.copyWith(winnerId: winner, resultSummary: summary);
  }

  void _persist() {
    final ms = state.matchState;
    if (ms == null) return;
    final data = ms.toJson();
    ref.read(tournamentsProvider.notifier)
        .updateSportData(state.tournamentId, state.matchId, data)
        .then((_) {})
        .catchError((e) { debugPrint('Cricket persist error: $e'); return null; });
  }

  String _buildDismissal(BallEvent event, String batsmanName) {
    switch (event.wicketType) {
      case WicketType.bowled:    return 'b ${event.bowler}';
      case WicketType.caught:    return 'c ${event.fielder ?? ''} b ${event.bowler}';
      case WicketType.lbw:       return 'lbw b ${event.bowler}';
      case WicketType.runOut:    return 'run out (${event.fielder ?? ''})';
      case WicketType.stumped:   return 'st ${event.fielder ?? ''} b ${event.bowler}';
      case WicketType.hitWicket: return 'hit wicket b ${event.bowler}';
      case WicketType.retired:   return 'retired';
      default:                   return 'out';
    }
  }
}

final cricketScoringProvider = NotifierProvider<CricketScoringNotifier, CricketScoringState>(
  CricketScoringNotifier.new,
);
