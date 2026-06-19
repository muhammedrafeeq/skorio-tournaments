import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tournaments_provider.dart';

enum ChessResult { whiteWins, blackWins, draw, ongoing }

extension ChessResultX on ChessResult {
  String get label {
    switch (this) {
      case ChessResult.whiteWins: return 'White Wins (1–0)';
      case ChessResult.blackWins: return 'Black Wins (0–1)';
      case ChessResult.draw:      return 'Draw (½–½)';
      case ChessResult.ongoing:   return 'Ongoing';
    }
  }

  String get shortLabel {
    switch (this) {
      case ChessResult.whiteWins: return '1–0';
      case ChessResult.blackWins: return '0–1';
      case ChessResult.draw:      return '½–½';
      case ChessResult.ongoing:   return '*';
    }
  }
}

enum ChessTermination {
  checkmate, resignation, timeout, stalemate, insufficientMaterial,
  fiftyMoveRule, repetition, agreement, abandoned
}

extension ChessTerminationX on ChessTermination {
  String get label {
    switch (this) {
      case ChessTermination.checkmate:             return 'Checkmate';
      case ChessTermination.resignation:           return 'Resignation';
      case ChessTermination.timeout:               return 'Time Out';
      case ChessTermination.stalemate:             return 'Stalemate';
      case ChessTermination.insufficientMaterial:  return 'Insufficient Material';
      case ChessTermination.fiftyMoveRule:         return '50-Move Rule';
      case ChessTermination.repetition:            return 'Threefold Repetition';
      case ChessTermination.agreement:             return 'Draw by Agreement';
      case ChessTermination.abandoned:             return 'Abandoned';
    }
  }
}

class ChessMatchState {
  final String homeTeamId;  // white side
  final String awayTeamId;  // black side
  final ChessResult result;
  final ChessTermination? termination;
  final int? timeControlMinutes;  // e.g. 90, 30, 10, 3
  final int? timeIncrementSeconds;
  final int? moveCount;
  final String? pgn;              // optional PGN notation
  final String? notes;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ChessMatchState({
    required this.homeTeamId,
    required this.awayTeamId,
    this.result = ChessResult.ongoing,
    this.termination,
    this.timeControlMinutes,
    this.timeIncrementSeconds,
    this.moveCount,
    this.pgn,
    this.notes,
    this.startedAt,
    this.endedAt,
  });

  bool get isComplete => result != ChessResult.ongoing;

  ChessMatchState copyWith({
    ChessResult? result, ChessTermination? termination,
    int? timeControlMinutes, int? timeIncrementSeconds, int? moveCount,
    String? pgn, String? notes, DateTime? startedAt, DateTime? endedAt,
  }) => ChessMatchState(
    homeTeamId: homeTeamId, awayTeamId: awayTeamId,
    result: result ?? this.result,
    termination: termination ?? this.termination,
    timeControlMinutes: timeControlMinutes ?? this.timeControlMinutes,
    timeIncrementSeconds: timeIncrementSeconds ?? this.timeIncrementSeconds,
    moveCount: moveCount ?? this.moveCount,
    pgn: pgn ?? this.pgn,
    notes: notes ?? this.notes,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );

  Map<String, dynamic> toJson() => {
    'home_team_id': homeTeamId, 'away_team_id': awayTeamId,
    'result': result.name, 'termination': termination?.name,
    'time_control_minutes': timeControlMinutes,
    'time_increment_seconds': timeIncrementSeconds,
    'move_count': moveCount, 'pgn': pgn, 'notes': notes,
    'started_at': startedAt?.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
  };

  factory ChessMatchState.fromJson(Map<String, dynamic> j) => ChessMatchState(
    homeTeamId: j['home_team_id'] ?? '', awayTeamId: j['away_team_id'] ?? '',
    result: ChessResult.values.byName(j['result'] ?? 'ongoing'),
    termination: j['termination'] != null
        ? ChessTermination.values.byName(j['termination']) : null,
    timeControlMinutes: j['time_control_minutes'],
    timeIncrementSeconds: j['time_increment_seconds'],
    moveCount: j['move_count'], pgn: j['pgn'], notes: j['notes'],
    startedAt: j['started_at'] != null ? DateTime.parse(j['started_at']) : null,
    endedAt: j['ended_at'] != null ? DateTime.parse(j['ended_at']) : null,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ChessScoringNotifier extends Notifier<ChessMatchState?> {
  String _tournamentId = '';
  String _matchId = '';

  @override
  ChessMatchState? build() => null;

  void loadMatch(String tournamentId, String matchId) {
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

    if (match.sportData.containsKey('result')) {
      state = ChessMatchState.fromJson(match.sportData);
    } else {
      state = ChessMatchState(
        homeTeamId: match.homeTeamId,
        awayTeamId: match.awayTeamId,
        startedAt: DateTime.now(),
      );
    }
  }

  void setResult(ChessResult result, {ChessTermination? termination, int? moveCount}) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      result: result,
      termination: termination,
      moveCount: moveCount,
      endedAt: DateTime.now(),
    );
    _persistAndUpdateScore();
  }

  void setTimeControl({required int minutes, int incrementSeconds = 0}) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      timeControlMinutes: minutes,
      timeIncrementSeconds: incrementSeconds,
    );
    _persist();
  }

  void setNotes(String notes) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(notes: notes);
    _persist();
  }

  void setPgn(String pgn) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(pgn: pgn);
    _persist();
  }

  void _persistAndUpdateScore() {
    final s = state;
    if (s == null) return;
    _persist();
    // Update canonical homeScore/awayScore (1=win, 0=loss — draw uses 0 both sides in this system)
    int homeScore = 0, awayScore = 0;
    if (s.result == ChessResult.whiteWins) { homeScore = 1; }
    else if (s.result == ChessResult.blackWins) { awayScore = 1; }
    ref.read(tournamentsProvider.notifier).updateMatchResult(
      _tournamentId, _matchId, homeScore, awayScore,
      sportData: s.toJson(),
    );
  }

  void _persist() {
    final s = state;
    if (s == null) return;
    ref.read(tournamentsProvider.notifier)
        .updateSportData(_tournamentId, _matchId, s.toJson())
        .then((_) {})
        .catchError((e) { debugPrint('Chess persist error: $e'); return null; });
  }
}

final chessScoringProvider = NotifierProvider<ChessScoringNotifier, ChessMatchState?>(
  ChessScoringNotifier.new,
);
