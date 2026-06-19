import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tournaments_provider.dart';

// ─── Config ──────────────────────────────────────────────────────────────────

class PointGameConfig {
  final int pointsPerSet;   // 21 for badminton, 11 for table tennis
  final int setsToWin;      // 2 for best-of-3, 3 for best-of-5
  final int winByTwo;       // 1 = must win by 2 (standard), 0 = exact
  final int maxPoints;      // cap (e.g. 30 for badminton deuce cap)

  const PointGameConfig({
    this.pointsPerSet = 21,
    this.setsToWin = 2,
    this.winByTwo = 1,
    this.maxPoints = 30,
  });

  int get totalSets => setsToWin * 2 - 1;

  Map<String, dynamic> toJson() => {
    'points_per_set': pointsPerSet,
    'sets_to_win': setsToWin,
    'win_by_two': winByTwo,
    'max_points': maxPoints,
  };

  factory PointGameConfig.fromJson(Map<String, dynamic> j) => PointGameConfig(
    pointsPerSet: j['points_per_set'] ?? 21,
    setsToWin: j['sets_to_win'] ?? 2,
    winByTwo: j['win_by_two'] ?? 1,
    maxPoints: j['max_points'] ?? 30,
  );

  static const badminton = PointGameConfig(pointsPerSet: 21, setsToWin: 2, winByTwo: 1, maxPoints: 30);
  static const tableTennis = PointGameConfig(pointsPerSet: 11, setsToWin: 3, winByTwo: 1, maxPoints: 0);
}

// ─── Models ──────────────────────────────────────────────────────────────────

class SetScore {
  final int homePoints;
  final int awayPoints;
  final bool isComplete;
  final String? winnerId; // homeTeamId or awayTeamId

  const SetScore({
    this.homePoints = 0,
    this.awayPoints = 0,
    this.isComplete = false,
    this.winnerId,
  });

  SetScore copyWith({int? homePoints, int? awayPoints, bool? isComplete, String? winnerId}) =>
      SetScore(
        homePoints: homePoints ?? this.homePoints,
        awayPoints: awayPoints ?? this.awayPoints,
        isComplete: isComplete ?? this.isComplete,
        winnerId: winnerId ?? this.winnerId,
      );

  Map<String, dynamic> toJson() => {
    'home_points': homePoints, 'away_points': awayPoints,
    'is_complete': isComplete, 'winner_id': winnerId,
  };

  factory SetScore.fromJson(Map<String, dynamic> j) => SetScore(
    homePoints: j['home_points'] ?? 0, awayPoints: j['away_points'] ?? 0,
    isComplete: j['is_complete'] ?? false, winnerId: j['winner_id'],
  );
}

class PointGameState {
  final PointGameConfig config;
  final String homeTeamId;
  final String awayTeamId;
  final List<SetScore> sets;
  final int homeSetsWon;
  final int awaySetsWon;
  final bool isComplete;
  final String? winnerId;

  const PointGameState({
    required this.config,
    required this.homeTeamId,
    required this.awayTeamId,
    this.sets = const [],
    this.homeSetsWon = 0,
    this.awaySetsWon = 0,
    this.isComplete = false,
    this.winnerId,
  });

  SetScore get currentSet => sets.isNotEmpty && !sets.last.isComplete
      ? sets.last
      : const SetScore();

  int get currentSetNumber => sets.length;

  PointGameState copyWith({
    List<SetScore>? sets, int? homeSetsWon, int? awaySetsWon,
    bool? isComplete, String? winnerId,
  }) => PointGameState(
    config: config, homeTeamId: homeTeamId, awayTeamId: awayTeamId,
    sets: sets ?? this.sets,
    homeSetsWon: homeSetsWon ?? this.homeSetsWon,
    awaySetsWon: awaySetsWon ?? this.awaySetsWon,
    isComplete: isComplete ?? this.isComplete,
    winnerId: winnerId ?? this.winnerId,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'home_team_id': homeTeamId, 'away_team_id': awayTeamId,
    'sets': sets.map((s) => s.toJson()).toList(),
    'home_sets_won': homeSetsWon, 'away_sets_won': awaySetsWon,
    'is_complete': isComplete, 'winner_id': winnerId,
  };

  factory PointGameState.fromJson(Map<String, dynamic> j) => PointGameState(
    config: PointGameConfig.fromJson(j['config'] ?? {}),
    homeTeamId: j['home_team_id'] ?? '', awayTeamId: j['away_team_id'] ?? '',
    sets: (j['sets'] as List?)?.map((s) => SetScore.fromJson(s)).toList() ?? [],
    homeSetsWon: j['home_sets_won'] ?? 0, awaySetsWon: j['away_sets_won'] ?? 0,
    isComplete: j['is_complete'] ?? false, winnerId: j['winner_id'],
  );

  static PointGameState initial({
    required PointGameConfig config,
    required String homeTeamId,
    required String awayTeamId,
  }) => PointGameState(
    config: config, homeTeamId: homeTeamId, awayTeamId: awayTeamId,
    sets: [const SetScore()],
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PointGameScoringNotifier extends Notifier<PointGameState?> {
  String _tournamentId = '';
  String _matchId = '';

  @override
  PointGameState? build() => null;

  void loadMatch(String tournamentId, String matchId, PointGameConfig config) {
    _tournamentId = tournamentId;
    _matchId = matchId;

    final tournament = ref.read(tournamentsProvider).tournaments
        .firstWhere((t) => t.id == tournamentId,
          orElse: () => Tournament(id: '', name: '', sport: '', format: '',
              description: '', location: '', bannerUrl: '', winPts: 3, drawPts: 1,
              lossPts: 0, teams: [], matches: [], prizes: '', creatorId: ''));
    final match = tournament.matches.firstWhere((m) => m.id == matchId,
        orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '',
            date: DateTime.now(), status: '', venue: ''));

    if (match.sportData.containsKey('sets')) {
      state = PointGameState.fromJson(match.sportData);
    } else {
      state = PointGameState.initial(
        config: config,
        homeTeamId: match.homeTeamId,
        awayTeamId: match.awayTeamId,
      );
    }
  }

  void addPoint({required bool isHome}) {
    final s = state;
    if (s == null || s.isComplete) return;

    var sets = List<SetScore>.from(s.sets);
    if (sets.isEmpty) sets.add(const SetScore());

    final current = sets.last;
    if (current.isComplete) return;

    var updated = current.copyWith(
      homePoints: current.homePoints + (isHome ? 1 : 0),
      awayPoints: current.awayPoints + (isHome ? 0 : 1),
    );

    // Check set win
    final String? setWinner = _checkSetWin(updated, s.config, s.homeTeamId, s.awayTeamId);
    if (setWinner != null) {
      updated = updated.copyWith(isComplete: true, winnerId: setWinner);
    }

    sets[sets.length - 1] = updated;

    int newHomeSets = s.homeSetsWon + (setWinner == s.homeTeamId ? 1 : 0);
    int newAwaySets = s.awaySetsWon + (setWinner == s.awayTeamId ? 1 : 0);

    bool matchOver = newHomeSets >= s.config.setsToWin || newAwaySets >= s.config.setsToWin;
    String? matchWinner = newHomeSets >= s.config.setsToWin ? s.homeTeamId
        : newAwaySets >= s.config.setsToWin ? s.awayTeamId : null;

    // Start new set if not over
    if (setWinner != null && !matchOver) sets.add(const SetScore());

    state = s.copyWith(
      sets: sets,
      homeSetsWon: newHomeSets,
      awaySetsWon: newAwaySets,
      isComplete: matchOver,
      winnerId: matchWinner,
    );
    _persist();
  }

  void undoPoint() {
    final s = state;
    if (s == null) return;

    var sets = List<SetScore>.from(s.sets);
    if (sets.isEmpty) return;

    // If last set just started (0-0) and there's a previous one, remove it
    if (sets.last.homePoints == 0 && sets.last.awayPoints == 0 && sets.length > 1) {
      sets.removeLast();
    }

    // Reopen completed set if needed
    var last = sets.last;
    if (last.isComplete) {
      last = last.copyWith(isComplete: false, winnerId: null);
    }

    // Subtract last point (we don't know who scored, so subtract from higher scorer)
    if (last.homePoints > last.awayPoints) {
      last = last.copyWith(homePoints: last.homePoints - 1);
    } else if (last.awayPoints > last.homePoints) {
      last = last.copyWith(awayPoints: last.awayPoints - 1);
    } else if (last.homePoints > 0) {
      last = last.copyWith(homePoints: last.homePoints - 1);
    }

    sets[sets.length - 1] = last;

    // Recalculate sets won
    int h = 0, a = 0;
    for (final set in sets) {
      if (set.isComplete) {
        if (set.winnerId == s.homeTeamId) { h++; }
        else if (set.winnerId == s.awayTeamId) { a++; }
      }
    }

    state = s.copyWith(sets: sets, homeSetsWon: h, awaySetsWon: a,
        isComplete: false, winnerId: null);
    _persist();
  }

  String? _checkSetWin(SetScore set, PointGameConfig config, String homeId, String awayId) {
    bool homeWins = set.homePoints >= config.pointsPerSet &&
        (config.winByTwo == 0 || set.homePoints - set.awayPoints >= 2);
    bool awayWins = set.awayPoints >= config.pointsPerSet &&
        (config.winByTwo == 0 || set.awayPoints - set.homePoints >= 2);

    // Cap at maxPoints
    if (config.maxPoints > 0) {
      if (set.homePoints >= config.maxPoints) homeWins = true;
      if (set.awayPoints >= config.maxPoints) awayWins = true;
    }

    if (homeWins) return homeId;
    if (awayWins) return awayId;
    return null;
  }

  void _persist() {
    final s = state;
    if (s == null) return;
    ref.read(tournamentsProvider.notifier)
        .updateSportData(_tournamentId, _matchId, s.toJson())
        .then((_) {})
        .catchError((e) { debugPrint('PointGame persist error: $e'); return null; });
  }
}

final pointGameScoringProvider = NotifierProvider<PointGameScoringNotifier, PointGameState?>(
  PointGameScoringNotifier.new,
);
