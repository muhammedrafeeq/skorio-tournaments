import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tournaments_provider.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

enum TennisPoint { love, fifteen, thirty, forty, deuce, advantage }

extension TennisPointX on TennisPoint {
  String get label {
    switch (this) {
      case TennisPoint.love:      return '0';
      case TennisPoint.fifteen:   return '15';
      case TennisPoint.thirty:    return '30';
      case TennisPoint.forty:     return '40';
      case TennisPoint.deuce:     return 'Deuce';
      case TennisPoint.advantage: return 'Adv';
    }
  }
}

class TennisGame {
  final TennisPoint homePoint;
  final TennisPoint awayPoint;
  final bool isAdvantageSide; // true = home has advantage
  final String? winnerId;

  const TennisGame({
    this.homePoint = TennisPoint.love,
    this.awayPoint = TennisPoint.love,
    this.isAdvantageSide = false,
    this.winnerId,
  });

  TennisGame copyWith({
    TennisPoint? homePoint, TennisPoint? awayPoint,
    bool? isAdvantageSide, String? winnerId,
  }) => TennisGame(
    homePoint: homePoint ?? this.homePoint,
    awayPoint: awayPoint ?? this.awayPoint,
    isAdvantageSide: isAdvantageSide ?? this.isAdvantageSide,
    winnerId: winnerId ?? this.winnerId,
  );

  Map<String, dynamic> toJson() => {
    'home_point': homePoint.name, 'away_point': awayPoint.name,
    'advantage_side': isAdvantageSide, 'winner_id': winnerId,
  };

  factory TennisGame.fromJson(Map<String, dynamic> j) => TennisGame(
    homePoint: TennisPoint.values.byName(j['home_point'] ?? 'love'),
    awayPoint: TennisPoint.values.byName(j['away_point'] ?? 'love'),
    isAdvantageSide: j['advantage_side'] ?? false,
    winnerId: j['winner_id'],
  );
}

class TennisTiebreak {
  final int homePoints;
  final int awayPoints;
  final String? winnerId;

  const TennisTiebreak({this.homePoints = 0, this.awayPoints = 0, this.winnerId});

  TennisTiebreak copyWith({int? homePoints, int? awayPoints, String? winnerId}) =>
      TennisTiebreak(
        homePoints: homePoints ?? this.homePoints,
        awayPoints: awayPoints ?? this.awayPoints,
        winnerId: winnerId ?? this.winnerId,
      );

  Map<String, dynamic> toJson() => {
    'home_points': homePoints, 'away_points': awayPoints, 'winner_id': winnerId,
  };

  factory TennisTiebreak.fromJson(Map<String, dynamic> j) => TennisTiebreak(
    homePoints: j['home_points'] ?? 0,
    awayPoints: j['away_points'] ?? 0,
    winnerId: j['winner_id'],
  );
}

class TennisSet {
  final int homeGames;
  final int awayGames;
  final TennisTiebreak? tiebreak;
  final String? winnerId;

  const TennisSet({
    this.homeGames = 0, this.awayGames = 0,
    this.tiebreak, this.winnerId,
  });

  bool get hasTiebreak => tiebreak != null;

  TennisSet copyWith({
    int? homeGames, int? awayGames,
    TennisTiebreak? tiebreak, String? winnerId,
  }) => TennisSet(
    homeGames: homeGames ?? this.homeGames,
    awayGames: awayGames ?? this.awayGames,
    tiebreak: tiebreak ?? this.tiebreak,
    winnerId: winnerId ?? this.winnerId,
  );

  Map<String, dynamic> toJson() => {
    'home_games': homeGames, 'away_games': awayGames,
    'tiebreak': tiebreak?.toJson(), 'winner_id': winnerId,
  };

  factory TennisSet.fromJson(Map<String, dynamic> j) => TennisSet(
    homeGames: j['home_games'] ?? 0, awayGames: j['away_games'] ?? 0,
    tiebreak: j['tiebreak'] != null ? TennisTiebreak.fromJson(j['tiebreak']) : null,
    winnerId: j['winner_id'],
  );
}

class TennisMatchState {
  final String homeTeamId;
  final String awayTeamId;
  final int setsToWin;          // 2 for best-of-3, 3 for best-of-5
  final bool finalSetTiebreak;  // false = advantage final set
  final List<TennisSet> sets;
  final TennisGame currentGame;
  final bool inTiebreak;
  final TennisTiebreak? currentTiebreak;
  final int homeSetsWon;
  final int awaySetsWon;
  final bool isComplete;
  final String? winnerId;

  const TennisMatchState({
    required this.homeTeamId,
    required this.awayTeamId,
    this.setsToWin = 2,
    this.finalSetTiebreak = true,
    this.sets = const [],
    this.currentGame = const TennisGame(),
    this.inTiebreak = false,
    this.currentTiebreak,
    this.homeSetsWon = 0,
    this.awaySetsWon = 0,
    this.isComplete = false,
    this.winnerId,
  });

  TennisMatchState copyWith({
    List<TennisSet>? sets, TennisGame? currentGame, bool? inTiebreak,
    TennisTiebreak? currentTiebreak, int? homeSetsWon, int? awaySetsWon,
    bool? isComplete, String? winnerId,
  }) => TennisMatchState(
    homeTeamId: homeTeamId, awayTeamId: awayTeamId,
    setsToWin: setsToWin, finalSetTiebreak: finalSetTiebreak,
    sets: sets ?? this.sets,
    currentGame: currentGame ?? this.currentGame,
    inTiebreak: inTiebreak ?? this.inTiebreak,
    currentTiebreak: currentTiebreak ?? this.currentTiebreak,
    homeSetsWon: homeSetsWon ?? this.homeSetsWon,
    awaySetsWon: awaySetsWon ?? this.awaySetsWon,
    isComplete: isComplete ?? this.isComplete,
    winnerId: winnerId ?? this.winnerId,
  );

  Map<String, dynamic> toJson() => {
    'home_team_id': homeTeamId, 'away_team_id': awayTeamId,
    'sets_to_win': setsToWin, 'final_set_tiebreak': finalSetTiebreak,
    'sets': sets.map((s) => s.toJson()).toList(),
    'current_game': currentGame.toJson(),
    'in_tiebreak': inTiebreak,
    'current_tiebreak': currentTiebreak?.toJson(),
    'home_sets_won': homeSetsWon, 'away_sets_won': awaySetsWon,
    'is_complete': isComplete, 'winner_id': winnerId,
  };

  factory TennisMatchState.fromJson(Map<String, dynamic> j) => TennisMatchState(
    homeTeamId: j['home_team_id'] ?? '', awayTeamId: j['away_team_id'] ?? '',
    setsToWin: j['sets_to_win'] ?? 2, finalSetTiebreak: j['final_set_tiebreak'] ?? true,
    sets: (j['sets'] as List?)?.map((s) => TennisSet.fromJson(s)).toList() ?? [],
    currentGame: j['current_game'] != null
        ? TennisGame.fromJson(j['current_game']) : const TennisGame(),
    inTiebreak: j['in_tiebreak'] ?? false,
    currentTiebreak: j['current_tiebreak'] != null
        ? TennisTiebreak.fromJson(j['current_tiebreak']) : null,
    homeSetsWon: j['home_sets_won'] ?? 0, awaySetsWon: j['away_sets_won'] ?? 0,
    isComplete: j['is_complete'] ?? false, winnerId: j['winner_id'],
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class TennisScoringNotifier extends Notifier<TennisMatchState?> {
  String _tournamentId = '';
  String _matchId = '';

  @override
  TennisMatchState? build() => null;

  void loadMatch(String tournamentId, String matchId, {int setsToWin = 2, bool finalSetTiebreak = true}) {
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

    if (match.sportData.containsKey('home_team_id')) {
      state = TennisMatchState.fromJson(match.sportData);
    } else {
      state = TennisMatchState(
        homeTeamId: match.homeTeamId,
        awayTeamId: match.awayTeamId,
        setsToWin: setsToWin,
        finalSetTiebreak: finalSetTiebreak,
        sets: [const TennisSet()],
      );
    }
  }

  void addPoint({required bool isHome}) {
    final s = state;
    if (s == null || s.isComplete) return;

    // Handle tiebreak
    if (s.inTiebreak) {
      _addTiebreakPoint(s, isHome);
      return;
    }

    // Advance game score
    final game = s.currentGame;
    final bool deuce = game.homePoint == TennisPoint.deuce;
    final bool homeAdv = deuce && game.isAdvantageSide;
    final bool awayAdv = deuce && !game.isAdvantageSide;

    TennisGame? updatedGame;
    String? gameWinnerId;

    if (deuce) {
      if (isHome && awayAdv) {
        updatedGame = game.copyWith(isAdvantageSide: false); // back to deuce
      } else if (!isHome && homeAdv) {
        updatedGame = game.copyWith(isAdvantageSide: false);
      } else if (isHome) {
        // home gets advantage
        updatedGame = game.copyWith(isAdvantageSide: true);
      } else {
        // away gets advantage
        updatedGame = game.copyWith(isAdvantageSide: false);
      }
      // If currently advantage, scoring again wins the game
      if (isHome && homeAdv) { gameWinnerId = s.homeTeamId; }
      if (!isHome && awayAdv) { gameWinnerId = s.awayTeamId; }
    } else {
      final currentHome = game.homePoint;
      final currentAway = game.awayPoint;

      TennisPoint nextHome = currentHome;
      TennisPoint nextAway = currentAway;

      if (isHome) {
        nextHome = _nextPoint(currentHome);
        if (nextHome == TennisPoint.forty && currentAway == TennisPoint.forty) {
          nextHome = TennisPoint.deuce;
          nextAway = TennisPoint.deuce;
        }
      } else {
        nextAway = _nextPoint(currentAway);
        if (nextAway == TennisPoint.forty && currentHome == TennisPoint.forty) {
          nextHome = TennisPoint.deuce;
          nextAway = TennisPoint.deuce;
        }
      }

      // Win game: was at 40, opponent not at 40/deuce
      if (isHome && currentHome == TennisPoint.forty && currentAway != TennisPoint.forty) {
        gameWinnerId = s.homeTeamId;
      } else if (!isHome && currentAway == TennisPoint.forty && currentHome != TennisPoint.forty) {
        gameWinnerId = s.awayTeamId;
      } else {
        updatedGame = game.copyWith(homePoint: nextHome, awayPoint: nextAway);
      }
    }

    if (gameWinnerId != null) {
      _registerGameWin(s, gameWinnerId);
    } else {
      state = s.copyWith(currentGame: updatedGame ?? game);
      _persist();
    }
  }

  void _addTiebreakPoint(TennisMatchState s, bool isHome) {
    var tb = s.currentTiebreak ?? const TennisTiebreak();
    tb = tb.copyWith(
      homePoints: tb.homePoints + (isHome ? 1 : 0),
      awayPoints: tb.awayPoints + (isHome ? 0 : 1),
    );

    String? tbWinner;
    if (tb.homePoints >= 7 && tb.homePoints - tb.awayPoints >= 2) {
      tbWinner = s.homeTeamId;
    } else if (tb.awayPoints >= 7 && tb.awayPoints - tb.homePoints >= 2) {
      tbWinner = s.awayTeamId;
    }

    if (tbWinner != null) {
      tb = tb.copyWith(winnerId: tbWinner);
      _registerGameWin(s.copyWith(inTiebreak: false, currentTiebreak: tb), tbWinner,
          isTiebreak: true, tiebreakResult: tb);
    } else {
      state = s.copyWith(currentTiebreak: tb);
      _persist();
    }
  }

  void _registerGameWin(TennisMatchState s, String winnerId,
      {bool isTiebreak = false, TennisTiebreak? tiebreakResult}) {
    var sets = List<TennisSet>.from(s.sets);
    if (sets.isEmpty) { sets.add(const TennisSet()); }

    var currentSet = sets.last;
    final isHome = winnerId == s.homeTeamId;
    currentSet = currentSet.copyWith(
      homeGames: currentSet.homeGames + (isHome ? 1 : 0),
      awayGames: currentSet.awayGames + (isHome ? 0 : 1),
      tiebreak: isTiebreak ? tiebreakResult : currentSet.tiebreak,
    );

    // Check set win: 6 games, win by 2 (or 7-6 via tiebreak)
    String? setWinner;
    if (isTiebreak) {
      setWinner = winnerId;
    } else if (currentSet.homeGames >= 6 && currentSet.homeGames - currentSet.awayGames >= 2) {
      setWinner = s.homeTeamId;
    } else if (currentSet.awayGames >= 6 && currentSet.awayGames - currentSet.homeGames >= 2) {
      setWinner = s.awayTeamId;
    }

    if (setWinner != null) { currentSet = currentSet.copyWith(winnerId: setWinner); }
    sets[sets.length - 1] = currentSet;

    int newHomeSets = s.homeSetsWon + (setWinner == s.homeTeamId ? 1 : 0);
    int newAwaySets = s.awaySetsWon + (setWinner == s.awayTeamId ? 1 : 0);
    bool matchOver = newHomeSets >= s.setsToWin || newAwaySets >= s.setsToWin;
    String? matchWinner = newHomeSets >= s.setsToWin ? s.homeTeamId
        : newAwaySets >= s.setsToWin ? s.awayTeamId : null;

    if (setWinner != null && !matchOver) { sets.add(const TennisSet()); }

    // Check tiebreak condition: 6-6 in set
    final newSet = sets.isNotEmpty && !sets.last.winnerId.toString().isNotEmpty ? sets.last : null;
    bool enterTiebreak = !matchOver && newSet != null &&
        newSet.homeGames == 6 && newSet.awayGames == 6;

    // Final set: no tiebreak unless configured
    bool isFinalSet = newHomeSets + newAwaySets == s.setsToWin * 2 - 2;
    if (isFinalSet && !s.finalSetTiebreak) { enterTiebreak = false; }

    state = s.copyWith(
      sets: sets,
      currentGame: const TennisGame(),
      inTiebreak: enterTiebreak,
      currentTiebreak: enterTiebreak ? const TennisTiebreak() : null,
      homeSetsWon: newHomeSets,
      awaySetsWon: newAwaySets,
      isComplete: matchOver,
      winnerId: matchWinner,
    );
    _persist();
  }

  TennisPoint _nextPoint(TennisPoint current) {
    switch (current) {
      case TennisPoint.love:    return TennisPoint.fifteen;
      case TennisPoint.fifteen: return TennisPoint.thirty;
      case TennisPoint.thirty:  return TennisPoint.forty;
      default:                  return current;
    }
  }

  void _persist() {
    final s = state;
    if (s == null) return;
    ref.read(tournamentsProvider.notifier)
        .updateSportData(_tournamentId, _matchId, s.toJson())
        .then((_) {})
        .catchError((e) { debugPrint('Tennis persist error: $e'); return null; });
  }
}

final tennisScoringProvider = NotifierProvider<TennisScoringNotifier, TennisMatchState?>(
  TennisScoringNotifier.new,
);
