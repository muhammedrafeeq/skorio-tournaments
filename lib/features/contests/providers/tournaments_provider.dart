import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/services/offline_sync_service.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class TournamentPlayer {
  final String id;
  final String name;
  final int jerseyNumber;
  final String position;
  final int goals;
  final int assists;
  final int cards;        // total yellow/red cards
  final int yellowCards;  // accumulated yellows (resets after serving ban)
  final int redCards;
  final int motm;
  final bool isSuspended; // true = serving a 1-match ban
  final int suspendedForMatchNumber; // match number when ban is served

  const TournamentPlayer({
    required this.id,
    required this.name,
    required this.jerseyNumber,
    required this.position,
    this.goals = 0,
    this.assists = 0,
    this.cards = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.motm = 0,
    this.isSuspended = false,
    this.suspendedForMatchNumber = 0,
  });

  TournamentPlayer copyWith({
    String? id,
    String? name,
    int? jerseyNumber,
    String? position,
    int? goals,
    int? assists,
    int? cards,
    int? yellowCards,
    int? redCards,
    int? motm,
    bool? isSuspended,
    int? suspendedForMatchNumber,
  }) {
    return TournamentPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      position: position ?? this.position,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      cards: cards ?? this.cards,
      yellowCards: yellowCards ?? this.yellowCards,
      redCards: redCards ?? this.redCards,
      motm: motm ?? this.motm,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedForMatchNumber: suspendedForMatchNumber ?? this.suspendedForMatchNumber,
    );
  }

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      jerseyNumber: json['jersey_number'] ?? json['jerseyNumber'] ?? 0,
      position: json['position'] ?? 'MID',
      goals: json['goals'] ?? 0,
      assists: json['assists'] ?? 0,
      cards: json['cards'] ?? 0,
      yellowCards: json['yellow_cards'] ?? 0,
      redCards: json['red_cards'] ?? 0,
      motm: json['motm'] ?? 0,
      isSuspended: json['is_suspended'] ?? false,
      suspendedForMatchNumber: json['suspended_for_match'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'jersey_number': jerseyNumber,
      'position': position,
      'goals': goals,
      'assists': assists,
      'cards': cards,
      'yellow_cards': yellowCards,
      'red_cards': redCards,
      'motm': motm,
      'is_suspended': isSuspended,
      'suspended_for_match': suspendedForMatchNumber,
    };
  }
}

class TournamentTeam {
  final String id;
  final String name;
  final String logoUrl; // Emoji badge
  final String primaryColor;
  final String secondaryColor;
  final List<TournamentPlayer> players;

  const TournamentTeam({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.players,
  });

  TournamentTeam copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    List<TournamentPlayer>? players,
  }) {
    return TournamentTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      players: players ?? this.players,
    );
  }

  factory TournamentTeam.fromJson(Map<String, dynamic> json) {
    return TournamentTeam(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      logoUrl: json['logo_url'] ?? '⚽',
      primaryColor: json['primary_color'] ?? '0xFF43DF9E',
      secondaryColor: json['secondary_color'] ?? '0xFF131318',
      players: (json['players'] as List?)
              ?.map((p) => TournamentPlayer.fromJson(p))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'players': players.map((p) => p.toJson()).toList(),
    };
  }
}

class PostponementEntry {
  final DateTime originalDate;
  final DateTime newDate;
  final String reason;
  final DateTime loggedAt;

  const PostponementEntry({
    required this.originalDate,
    required this.newDate,
    required this.reason,
    required this.loggedAt,
  });

  factory PostponementEntry.fromJson(Map<String, dynamic> json) => PostponementEntry(
    originalDate: DateTime.parse(json['original_date']),
    newDate: DateTime.parse(json['new_date']),
    reason: json['reason'] ?? '',
    loggedAt: DateTime.parse(json['logged_at']),
  );

  Map<String, dynamic> toJson() => {
    'original_date': originalDate.toIso8601String(),
    'new_date': newDate.toIso8601String(),
    'reason': reason,
    'logged_at': loggedAt.toIso8601String(),
  };
}

class MatchLineup {
  final String teamId;
  final List<String> startingXI;   // player names/ids
  final List<String> substitutes;
  final String formation;          // e.g. "4-3-3"
  final DateTime submittedAt;

  const MatchLineup({
    required this.teamId,
    required this.startingXI,
    required this.substitutes,
    required this.formation,
    required this.submittedAt,
  });

  factory MatchLineup.fromJson(Map<String, dynamic> json) => MatchLineup(
    teamId: json['team_id'] ?? '',
    startingXI: (json['starting_xi'] as List?)?.map((e) => e.toString()).toList() ?? [],
    substitutes: (json['substitutes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    formation: json['formation'] ?? '4-4-2',
    submittedAt: DateTime.parse(json['submitted_at']),
  );

  Map<String, dynamic> toJson() => {
    'team_id': teamId,
    'starting_xi': startingXI,
    'substitutes': substitutes,
    'formation': formation,
    'submitted_at': submittedAt.toIso8601String(),
  };
}

class TournamentMatch {
  final String id;
  final String homeTeamId;
  final String awayTeamId;
  final int homeScore;
  final int awayScore;
  final DateTime date;
  final String status; // 'scheduled', 'live', 'completed', 'postponed'
  final String venue;
  final List<String> scorers; // list of player names/ids
  final List<String> cards;   // e.g. ["Marcus_F:Yellow", "NeyMagic:Yellow"]
  final String? motm;         // Player Name/Id
  final String phase;         // 'group', 'r16', 'qf', 'sf', 'final', '' (league)
  final String groupId;       // 'A', 'B', etc. for group stage, empty otherwise
  final String refereeId;     // user id of assigned referee
  final String refereeName;   // display name of referee
  final List<PostponementEntry> postponements;
  final List<MatchLineup> lineups; // submitted lineups (one per team)
  final Map<String, dynamic> sportData; // sport-specific rich scoring state

  const TournamentMatch({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeScore = 0,
    this.awayScore = 0,
    required this.date,
    required this.status,
    required this.venue,
    this.scorers = const [],
    this.cards = const [],
    this.motm,
    this.phase = '',
    this.groupId = '',
    this.refereeId = '',
    this.refereeName = '',
    this.postponements = const [],
    this.lineups = const [],
    this.sportData = const {},
  });

  TournamentMatch copyWith({
    String? id,
    String? homeTeamId,
    String? awayTeamId,
    int? homeScore,
    int? awayScore,
    DateTime? date,
    String? status,
    String? venue,
    List<String>? scorers,
    List<String>? cards,
    String? motm,
    String? phase,
    String? groupId,
    String? refereeId,
    String? refereeName,
    List<PostponementEntry>? postponements,
    List<MatchLineup>? lineups,
    Map<String, dynamic>? sportData,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      date: date ?? this.date,
      status: status ?? this.status,
      venue: venue ?? this.venue,
      scorers: scorers ?? this.scorers,
      cards: cards ?? this.cards,
      motm: motm ?? this.motm,
      phase: phase ?? this.phase,
      groupId: groupId ?? this.groupId,
      refereeId: refereeId ?? this.refereeId,
      refereeName: refereeName ?? this.refereeName,
      postponements: postponements ?? this.postponements,
      lineups: lineups ?? this.lineups,
      sportData: sportData ?? this.sportData,
    );
  }

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id']?.toString() ?? '',
      homeTeamId: json['home_team_id']?.toString() ?? json['homeTeamId']?.toString() ?? '',
      awayTeamId: json['away_team_id']?.toString() ?? json['awayTeamId']?.toString() ?? '',
      homeScore: json['home_score'] ?? 0,
      awayScore: json['away_score'] ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: json['status'] ?? 'scheduled',
      venue: json['venue'] ?? 'Pitch A',
      scorers: (json['scorers'] as List?)?.map((s) => s.toString()).toList() ?? [],
      cards: (json['cards'] as List?)?.map((c) => c.toString()).toList() ?? [],
      motm: json['motm']?.toString(),
      phase: json['phase'] ?? '',
      groupId: json['group_id'] ?? '',
      refereeId: json['referee_id'] ?? '',
      refereeName: json['referee_name'] ?? '',
      lineups: (json['lineups'] as List?)
              ?.map((e) => MatchLineup.fromJson(e)).toList() ?? const [],
      sportData: (json['sport_data'] as Map<String, dynamic>?) ?? const {},
      postponements: (json['postponements'] as List?)
              ?.map((e) => PostponementEntry.fromJson(e))
              .toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_team_id': homeTeamId,
      'away_team_id': awayTeamId,
      'home_score': homeScore,
      'away_score': awayScore,
      'date': date.toIso8601String(),
      'status': status,
      'venue': venue,
      'scorers': scorers,
      'cards': cards,
      'motm': motm,
      'phase': phase,
      'group_id': groupId,
      'referee_id': refereeId,
      'referee_name': refereeName,
      'lineups': lineups.map((l) => l.toJson()).toList(),
      'sport_data': sportData,
      'postponements': postponements.map((p) => p.toJson()).toList(),
    };
  }
}

/// Ordered list of tiebreaker criteria. First one that differs wins.
enum TiebreakerCriteria { points, headToHead, goalDifference, goalsFor, goalsAgainst, wins, coinFlip }

class Tournament {
  final String id;
  final String name;
  final String sport;
  final String format;
  final String description;
  final String location;
  final String bannerUrl;
  final int winPts;
  final int drawPts;
  final int lossPts;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final String prizes;
  final String creatorId;
  final bool isPublished;
  // Ordered tiebreaker criteria (first wins)
  final List<TiebreakerCriteria> tiebreakers;
  final String inviteCode;
  // Yellow cards needed to trigger a 1-match ban (0 = disabled)
  final int suspensionThreshold;
  // Co-admin user IDs who can manage this tournament
  final List<String> coAdminIds;
  // Role change / co-admin audit log entries (stored as "userId:role:timestamp")
  final List<String> adminLog;

  const Tournament({
    required this.id,
    required this.name,
    required this.sport,
    required this.format,
    required this.description,
    required this.location,
    required this.bannerUrl,
    required this.winPts,
    required this.drawPts,
    required this.lossPts,
    required this.teams,
    required this.matches,
    required this.prizes,
    required this.creatorId,
    this.isPublished = false,
    this.inviteCode = '',
    this.suspensionThreshold = 3,
    this.coAdminIds = const [],
    this.adminLog = const [],
    this.tiebreakers = const [
      TiebreakerCriteria.points,
      TiebreakerCriteria.headToHead,
      TiebreakerCriteria.goalDifference,
      TiebreakerCriteria.goalsFor,
    ],
  });

  Tournament copyWith({
    String? id,
    String? name,
    String? sport,
    String? format,
    String? description,
    String? location,
    String? bannerUrl,
    int? winPts,
    int? drawPts,
    int? lossPts,
    List<TournamentTeam>? teams,
    List<TournamentMatch>? matches,
    String? prizes,
    String? creatorId,
    bool? isPublished,
    String? inviteCode,
    int? suspensionThreshold,
    List<String>? coAdminIds,
    List<String>? adminLog,
    List<TiebreakerCriteria>? tiebreakers,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      format: format ?? this.format,
      description: description ?? this.description,
      location: location ?? this.location,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      winPts: winPts ?? this.winPts,
      drawPts: drawPts ?? this.drawPts,
      lossPts: lossPts ?? this.lossPts,
      teams: teams ?? this.teams,
      matches: matches ?? this.matches,
      prizes: prizes ?? this.prizes,
      creatorId: creatorId ?? this.creatorId,
      isPublished: isPublished ?? this.isPublished,
      inviteCode: inviteCode ?? this.inviteCode,
      suspensionThreshold: suspensionThreshold ?? this.suspensionThreshold,
      coAdminIds: coAdminIds ?? this.coAdminIds,
      adminLog: adminLog ?? this.adminLog,
      tiebreakers: tiebreakers ?? this.tiebreakers,
    );
  }

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      sport: json['sport'] ?? 'football',
      format: json['format'] ?? 'league',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      bannerUrl: json['banner_url'] ?? '',
      winPts: json['win_pts'] ?? 3,
      drawPts: json['draw_pts'] ?? 1,
      lossPts: json['loss_pts'] ?? 0,
      teams: (json['teams'] as List?)?.map((t) => TournamentTeam.fromJson(t)).toList() ?? [],
      matches: (json['matches'] as List?)?.map((m) => TournamentMatch.fromJson(m)).toList() ?? [],
      prizes: json['prizes'] ?? '',
      creatorId: json['creator_id'] ?? '',
      isPublished: json['is_published'] ?? false,
      inviteCode: json['invite_code'] ?? '',
      suspensionThreshold: json['suspension_threshold'] ?? 3,
      coAdminIds: (json['co_admin_ids'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      adminLog: (json['admin_log'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      tiebreakers: (json['tiebreakers'] as List?)
              ?.map((e) => TiebreakerCriteria.values.byName(e.toString()))
              .toList() ??
          const [
            TiebreakerCriteria.points,
            TiebreakerCriteria.headToHead,
            TiebreakerCriteria.goalDifference,
            TiebreakerCriteria.goalsFor,
          ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sport': sport,
      'format': format,
      'description': description,
      'location': location,
      'banner_url': bannerUrl,
      'win_pts': winPts,
      'draw_pts': drawPts,
      'loss_pts': lossPts,
      'teams': teams.map((t) => t.toJson()).toList(),
      'matches': matches.map((m) => m.toJson()).toList(),
      'prizes': prizes,
      'creator_id': creatorId,
      'is_published': isPublished,
      'invite_code': inviteCode,
      'suspension_threshold': suspensionThreshold,
      'co_admin_ids': coAdminIds,
      'admin_log': adminLog,
      'tiebreakers': tiebreakers.map((t) => t.name).toList(),
    };
  }
}

class StandingsRecord {
  final TournamentTeam team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int gf; // Goals For / Runs For
  final int ga; // Goals Against / Runs Against
  final int gd; // Goal Difference / NRR
  final int points;
  final List<String> form; // Last 5 results, e.g. ['W', 'D', 'W']

  const StandingsRecord({
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.gf,
    required this.ga,
    required this.gd,
    required this.points,
    required this.form,
  });
}

// ─── State ───────────────────────────────────────────────────────────────────

class TournamentsState {
  final List<Tournament> tournaments;
  final bool isLoading;
  final String? error;

  const TournamentsState({
    required this.tournaments,
    this.isLoading = false,
    this.error,
  });

  TournamentsState copyWith({
    List<Tournament>? tournaments,
    bool? isLoading,
    String? error,
  }) {
    return TournamentsState(
      tournaments: tournaments ?? this.tournaments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TournamentsNotifier extends Notifier<TournamentsState> {
  @override
  TournamentsState build() {
    Future.microtask(() => loadTournaments());
    return const TournamentsState(tournaments: [], isLoading: false);
  }

  Future<void> loadTournaments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.from('tournaments').select();

      final list = (response as List).map((t) => Tournament.fromJson(t)).toList();
      state = TournamentsState(tournaments: list, isLoading: false);
    } catch (e) {
      debugPrint("Failed to load tournaments from Supabase, loading mock: $e");
      state = TournamentsState(
        tournaments: _getMockTournaments(),
        isLoading: false,
      );
    }
  }

  /// Creates a new tournament and generates matches if round-robin format
  Future<bool> createTournament(Tournament tournament) async {
    state = state.copyWith(isLoading: true, error: null);
    
    var processedTournament = tournament.copyWith(inviteCode: _generateInviteCode());
    if (tournament.format == 'league' && tournament.teams.length >= 2) {
      final generatedMatches = _generateRoundRobinFixtures(tournament.teams);
      processedTournament = processedTournament.copyWith(matches: generatedMatches);
    } else if ((tournament.format == 'groups_knockout' || tournament.format == 'group_knockout') &&
        tournament.teams.length >= 4) {
      final generatedMatches = _generateGroupStageFixtures(tournament.teams);
      processedTournament = processedTournament.copyWith(matches: generatedMatches);
    }

    final client = sb.Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? 'mock-user-id';
    final finalTournament = processedTournament.copyWith(creatorId: userId);

    final syncState = ref.read(offlineSyncProvider);
    if (!syncState.isOnline) {
      // Queue for later sync
      await ref.read(offlineSyncProvider.notifier).enqueue(SyncOperation(
        id: 'sync_create_${finalTournament.id}',
        type: SyncOpType.insert,
        table: 'tournaments',
        recordId: finalTournament.id,
        data: finalTournament.toJson(),
        createdAt: DateTime.now(),
      ));
      final updatedList = [finalTournament, ...state.tournaments];
      state = TournamentsState(tournaments: updatedList, isLoading: false);
      return true;
    }

    try {
      await client.from('tournaments').insert(finalTournament.toJson());
      await loadTournaments();
      return true;
    } catch (e) {
      debugPrint("Failed to save tournament to database, running locally: $e");
      final updatedList = [finalTournament, ...state.tournaments];
      state = TournamentsState(tournaments: updatedList, isLoading: false);
      return true;
    }
  }

  /// Updates a match score and recalculates the team standings and player statistics
  Future<bool> updateMatchResult(
    String tournamentId,
    String matchId,
    int homeScore,
    int awayScore, {
    List<String> scorers = const [],
    List<String> cards = const [],
    String? motm,
    Map<String, dynamic>? sportData,
  }) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;

    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id == matchId) {
        return m.copyWith(
          homeScore: homeScore,
          awayScore: awayScore,
          status: 'completed',
          scorers: scorers,
          cards: cards,
          motm: motm,
          sportData: sportData ?? m.sportData,
        );
      }
      return m;
    }).toList();

    // Recalculate Player stats dynamically on completion
    final updatedTeams = _recalculatePlayerStats(
      tournament.teams, updatedMatches,
      suspensionThreshold: tournament.suspensionThreshold,
    );

    final updatedTournament = tournament.copyWith(
      matches: updatedMatches,
      teams: updatedTeams,
    );

    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);

    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  // Standings Calculation Helper
  List<StandingsRecord> getStandings(String tournamentId) {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return [];

    final tournament = state.tournaments[tIdx];
    final Map<String, _TeamAccumulator> acc = {};

    // Init accumulators
    for (var team in tournament.teams) {
      acc[team.id] = _TeamAccumulator(team: team);
    }

    // Accumulate finished matches
    for (var match in tournament.matches) {
      if (match.status == 'completed') {
        final home = acc[match.homeTeamId];
        final away = acc[match.awayTeamId];

        if (home != null && away != null) {
          home.played++;
          away.played++;

          home.gf += match.homeScore;
          home.ga += match.awayScore;
          away.gf += match.awayScore;
          away.ga += match.homeScore;

          if (match.homeScore > match.awayScore) {
            home.won++;
            home.points += tournament.winPts;
            home.form.add('W');

            away.lost++;
            away.points += tournament.lossPts;
            away.form.add('L');
          } else if (match.awayScore > match.homeScore) {
            away.won++;
            away.points += tournament.winPts;
            away.form.add('W');

            home.lost++;
            home.points += tournament.lossPts;
            home.form.add('L');
          } else {
            home.drawn++;
            home.points += tournament.drawPts;
            home.form.add('D');

            away.drawn++;
            away.points += tournament.drawPts;
            away.form.add('D');
          }
        }
      }
    }

    // Convert to records and sort
    final records = acc.values.map((a) {
      // Keep only last 5 form elements
      final formList = a.form.length > 5 ? a.form.sublist(a.form.length - 5) : a.form;
      return StandingsRecord(
        team: a.team,
        played: a.played,
        won: a.won,
        drawn: a.drawn,
        lost: a.lost,
        gf: a.gf,
        ga: a.ga,
        gd: a.gf - a.ga,
        points: a.points,
        form: formList,
      );
    }).toList();

    records.sort((x, y) => _compareByTiebreakers(x, y, tournament));
    return records;
  }

  int _compareByTiebreakers(StandingsRecord x, StandingsRecord y, Tournament tournament) {
    for (final rule in tournament.tiebreakers) {
      final cmp = _applyCriteria(rule, x, y, tournament);
      if (cmp != 0) return cmp;
    }
    return x.team.name.compareTo(y.team.name);
  }

  int _applyCriteria(TiebreakerCriteria rule, StandingsRecord x, StandingsRecord y, Tournament tournament) {
    switch (rule) {
      case TiebreakerCriteria.points:
        return y.points.compareTo(x.points);
      case TiebreakerCriteria.goalDifference:
        return y.gd.compareTo(x.gd);
      case TiebreakerCriteria.goalsFor:
        return y.gf.compareTo(x.gf);
      case TiebreakerCriteria.goalsAgainst:
        return x.ga.compareTo(y.ga); // fewer goals against = better
      case TiebreakerCriteria.wins:
        return y.won.compareTo(x.won);
      case TiebreakerCriteria.headToHead:
        // Find direct match between x and y
        final h2h = tournament.matches.firstWhere(
          (m) => m.status == 'completed' &&
              ((m.homeTeamId == x.team.id && m.awayTeamId == y.team.id) ||
               (m.homeTeamId == y.team.id && m.awayTeamId == x.team.id)),
          orElse: () => TournamentMatch(id: '', homeTeamId: '', awayTeamId: '', date: DateTime.now(), status: '', venue: ''),
        );
        if (h2h.id.isEmpty) return 0;
        final xWon = (h2h.homeTeamId == x.team.id && h2h.homeScore > h2h.awayScore) ||
                     (h2h.awayTeamId == x.team.id && h2h.awayScore > h2h.homeScore);
        final yWon = (h2h.homeTeamId == y.team.id && h2h.homeScore > h2h.awayScore) ||
                     (h2h.awayTeamId == y.team.id && h2h.awayScore > h2h.homeScore);
        if (xWon) return -1;
        if (yWon) return 1;
        return 0;
      case TiebreakerCriteria.coinFlip:
        return 0; // display as equal; admin resolves manually
    }
  }

  /// Returns standings keyed by groupId for group_knockout format tournaments
  Map<String, List<StandingsRecord>> getGroupStandings(String tournamentId) {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return {};
    final tournament = state.tournaments[tIdx];

    // Collect unique group IDs from matches
    final groupIds = tournament.matches
        .where((m) => m.groupId.isNotEmpty)
        .map((m) => m.groupId)
        .toSet()
        .toList()
      ..sort();

    if (groupIds.isEmpty) return {};

    final Map<String, List<StandingsRecord>> result = {};
    for (final groupId in groupIds) {
      final groupMatches = tournament.matches.where((m) => m.groupId == groupId).toList();
      final groupTeamIds = <String>{};
      for (final m in groupMatches) {
        groupTeamIds.add(m.homeTeamId);
        groupTeamIds.add(m.awayTeamId);
      }
      final groupTeams = tournament.teams.where((t) => groupTeamIds.contains(t.id)).toList();

      final Map<String, _TeamAccumulator> acc = {};
      for (var team in groupTeams) {
        acc[team.id] = _TeamAccumulator(team: team);
      }
      for (var match in groupMatches) {
        if (match.status == 'completed') {
          final home = acc[match.homeTeamId];
          final away = acc[match.awayTeamId];
          if (home != null && away != null) {
            home.played++; away.played++;
            home.gf += match.homeScore; home.ga += match.awayScore;
            away.gf += match.awayScore; away.ga += match.homeScore;
            if (match.homeScore > match.awayScore) {
              home.won++; home.points += tournament.winPts; home.form.add('W');
              away.lost++; away.points += tournament.lossPts; away.form.add('L');
            } else if (match.awayScore > match.homeScore) {
              away.won++; away.points += tournament.winPts; away.form.add('W');
              home.lost++; home.points += tournament.lossPts; home.form.add('L');
            } else {
              home.drawn++; home.points += tournament.drawPts; home.form.add('D');
              away.drawn++; away.points += tournament.drawPts; away.form.add('D');
            }
          }
        }
      }
      final records = acc.values.map((a) {
        final formList = a.form.length > 5 ? a.form.sublist(a.form.length - 5) : a.form;
        return StandingsRecord(
          team: a.team, played: a.played, won: a.won, drawn: a.drawn, lost: a.lost,
          gf: a.gf, ga: a.ga, gd: a.gf - a.ga, points: a.points, form: formList,
        );
      }).toList();
      records.sort((x, y) => _compareByTiebreakers(x, y, tournament));
      result[groupId] = records;
    }
    return result;
  }

  /// Updates sport-specific scoring data without changing match result status
  Future<bool> updateSportData(String tournamentId, String matchId, Map<String, dynamic> sportData) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;
    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id != matchId) return m;
      return m.copyWith(sportData: {...m.sportData, ...sportData});
    }).toList();
    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Sets a match status to 'live' or 'scheduled'
  Future<bool> setMatchLive(String tournamentId, String matchId, {required bool live}) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;

    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id == matchId) return m.copyWith(status: live ? 'live' : 'scheduled');
      return m;
    }).toList();
    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Self-registration: adds a player to a team within a tournament
  Future<bool> addPlayerToTeam(String tournamentId, String teamId, TournamentPlayer player) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;
    final tournament = state.tournaments[tIdx];
    final teamIdx = tournament.teams.indexWhere((t) => t.id == teamId);
    if (teamIdx == -1) return false;

    final team = tournament.teams[teamIdx];
    final updatedTeams = List<TournamentTeam>.from(tournament.teams);
    updatedTeams[teamIdx] = team.copyWith(players: [...team.players, player]);
    final updatedTournament = tournament.copyWith(teams: updatedTeams);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  void addMatchToTournament(String tournamentId, TournamentMatch match) {
    final current = state.tournaments.firstWhere((t) => t.id == tournamentId);
    final updated = current.copyWith(matches: [...current.matches, match]);
    state = state.copyWith(
      tournaments: [for (final t in state.tournaments) if (t.id == tournamentId) updated else t],
    );
  }

  /// Returns knockout matches grouped by phase for bracket display
  Map<String, List<TournamentMatch>> getKnockoutRounds(String tournamentId) {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return {};
    final tournament = state.tournaments[tIdx];

    const phases = ['r16', 'qf', 'sf', 'final'];
    final Map<String, List<TournamentMatch>> result = {};
    for (final phase in phases) {
      final matches = tournament.matches.where((m) => m.phase == phase).toList();
      if (matches.isNotEmpty) result[phase] = matches;
    }
    return result;
  }

  // Recalculates stats like goals, cards, and MOTMs per player based on match results
  List<TournamentTeam> _recalculatePlayerStats(
    List<TournamentTeam> teams,
    List<TournamentMatch> matches, {
    int suspensionThreshold = 3,
  }) {
    final Map<String, int> playerGoals = {};
    final Map<String, int> playerCards = {};
    final Map<String, int> playerYellows = {};
    final Map<String, int> playerReds = {};
    final Map<String, int> playerMotm = {};
    // Track which match number each player received their threshold yellow in
    final Map<String, int> playerSuspendedForMatch = {};

    final completedMatches = matches.where((m) => m.status == 'completed').toList();
    // Process in chronological order so suspension match numbers are accurate
    completedMatches.sort((a, b) => a.date.compareTo(b.date));

    for (int idx = 0; idx < completedMatches.length; idx++) {
      final m = completedMatches[idx];
      for (var scorer in m.scorers) {
        playerGoals[scorer] = (playerGoals[scorer] ?? 0) + 1;
      }
      for (var cardRecord in m.cards) {
        final parts = cardRecord.split(':');
        final pName = parts[0];
        final cardType = parts.length > 1 ? parts[1].toLowerCase() : 'yellow';
        playerCards[pName] = (playerCards[pName] ?? 0) + 1;
        if (cardType == 'red') {
          playerReds[pName] = (playerReds[pName] ?? 0) + 1;
          // Red card = immediate 1-match ban (next match)
          playerSuspendedForMatch[pName] = idx + 1;
        } else {
          final yellows = (playerYellows[pName] ?? 0) + 1;
          playerYellows[pName] = yellows;
          if (suspensionThreshold > 0 && yellows % suspensionThreshold == 0) {
            playerSuspendedForMatch[pName] = idx + 1;
          }
        }
      }
      if (m.motm != null) {
        playerMotm[m.motm!] = (playerMotm[m.motm!] ?? 0) + 1;
      }
    }

    // The next unplayed match index
    final nextMatchIdx = completedMatches.length;

    return teams.map((team) {
      final updatedPlayers = team.players.map((p) {
        final suspendedFor = playerSuspendedForMatch[p.name];
        final isSuspended = suspendedFor != null && suspendedFor == nextMatchIdx;
        return p.copyWith(
          goals: playerGoals[p.name] ?? 0,
          cards: playerCards[p.name] ?? 0,
          yellowCards: playerYellows[p.name] ?? 0,
          redCards: playerReds[p.name] ?? 0,
          motm: playerMotm[p.name] ?? 0,
          isSuspended: isSuspended,
          suspendedForMatchNumber: suspendedFor ?? 0,
        );
      }).toList();
      return team.copyWith(players: updatedPlayers);
    }).toList();
  }

  void playerHighlighter(Map<String, int> map, String name) {
    map[name] = (map[name] ?? 0) + 1;
  }

  Future<bool> assignReferee(String tournamentId, String matchId, {required String refereeId, required String refereeName}) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;

    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id == matchId) return m.copyWith(refereeId: refereeId, refereeName: refereeName);
      return m;
    }).toList();
    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Returns true if the given userId is creator or co-admin of the tournament
  bool isAdmin(String tournamentId, String userId) {
    final t = state.tournaments.firstWhere((t) => t.id == tournamentId,
        orElse: () => Tournament(id: '', name: '', sport: '', format: '', description: '', location: '',
            bannerUrl: '', winPts: 3, drawPts: 1, lossPts: 0, teams: [], matches: [], prizes: '', creatorId: ''));
    return t.creatorId == userId || t.coAdminIds.contains(userId);
  }

  /// Adds a co-admin by userId, logging the action
  Future<bool> addCoAdmin(String tournamentId, String userId, String displayName) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;
    final tournament = state.tournaments[tIdx];
    if (tournament.coAdminIds.contains(userId)) return true;

    final logEntry = '$userId:co_admin_added:${DateTime.now().toIso8601String()}:$displayName';
    final updated = tournament.copyWith(
      coAdminIds: [...tournament.coAdminIds, userId],
      adminLog: [...tournament.adminLog, logEntry],
    );
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updated;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updated);
    return true;
  }

  /// Removes a co-admin, logging the action
  Future<bool> removeCoAdmin(String tournamentId, String userId) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;
    final tournament = state.tournaments[tIdx];

    final logEntry = '$userId:co_admin_removed:${DateTime.now().toIso8601String()}';
    final updated = tournament.copyWith(
      coAdminIds: tournament.coAdminIds.where((id) => id != userId).toList(),
      adminLog: [...tournament.adminLog, logEntry],
    );
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updated;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updated);
    return true;
  }

  /// Submits or updates a team's lineup for a match (replaces existing lineup for that team)
  Future<bool> submitLineup(String tournamentId, String matchId, MatchLineup lineup) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;
    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id != matchId) return m;
      final existing = m.lineups.where((l) => l.teamId != lineup.teamId).toList();
      return m.copyWith(lineups: [...existing, lineup]);
    }).toList();
    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Reschedules a match, logging the original date and reason
  Future<bool> postponeMatch(
    String tournamentId,
    String matchId, {
    required DateTime newDate,
    required String reason,
  }) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;

    final tournament = state.tournaments[tIdx];
    final updatedMatches = tournament.matches.map((m) {
      if (m.id == matchId) {
        final entry = PostponementEntry(
          originalDate: m.date,
          newDate: newDate,
          reason: reason,
          loggedAt: DateTime.now(),
        );
        return m.copyWith(
          date: newDate,
          status: 'postponed',
          postponements: [...m.postponements, entry],
        );
      }
      return m;
    }).toList();

    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Splits teams into groups of 4 (or as evenly as possible) and generates round-robin fixtures per group.
  /// Placeholder knockout slots (TBD vs TBD) are also created for r16/qf/sf/final as appropriate.
  List<TournamentMatch> _generateGroupStageFixtures(List<TournamentTeam> teams) {
    final List<TournamentMatch> matches = [];
    int matchCounter = 1;

    // Determine number of groups: aim for groups of 4
    final groupCount = (teams.length / 4).ceil().clamp(2, 8);
    final List<List<TournamentTeam>> groups = List.generate(groupCount, (_) => []);

    // Distribute teams into groups in round-robin fashion
    for (int i = 0; i < teams.length; i++) {
      groups[i % groupCount].add(teams[i]);
    }

    // Group labels
    const labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    // Generate round-robin fixtures for each group
    for (int g = 0; g < groups.length; g++) {
      final groupTeams = groups[g];
      final groupId = labels[g];
      for (int i = 0; i < groupTeams.length; i++) {
        for (int j = i + 1; j < groupTeams.length; j++) {
          matches.add(TournamentMatch(
            id: 'grp_${groupId}_${matchCounter++}',
            homeTeamId: groupTeams[i].id,
            awayTeamId: groupTeams[j].id,
            date: DateTime.now().add(Duration(days: matchCounter)),
            status: 'scheduled',
            venue: 'Pitch $groupId',
            phase: 'group',
            groupId: groupId,
          ));
        }
      }
    }

    // Add placeholder knockout slots based on team count
    final advancingTeams = groupCount * 2; // top 2 per group advance
    final knockoutPhases = _knockoutPhasesFor(advancingTeams);
    int knockoutCounter = 1;
    for (final phase in knockoutPhases.take(1)) {
      // Only first round slots; rest get created when bracket is advanced
      final slots = advancingTeams ~/ 2;
      for (int i = 0; i < slots; i++) {
        matches.add(TournamentMatch(
          id: 'ko_${phase}_${knockoutCounter++}',
          homeTeamId: 'tbd',
          awayTeamId: 'tbd',
          date: DateTime.now().add(Duration(days: matchCounter + 7 + i)),
          status: 'scheduled',
          venue: 'Main Stadium',
          phase: phase,
          groupId: '',
        ));
      }
    }

    return matches;
  }

  List<String> _knockoutPhasesFor(int teamCount) {
    if (teamCount >= 16) return ['r16', 'qf', 'sf', 'final'];
    if (teamCount >= 8)  return ['qf', 'sf', 'final'];
    if (teamCount >= 4)  return ['sf', 'final'];
    return ['final'];
  }

  /// Advances group stage winners into knockout slots.
  /// Call this after all group matches are complete.
  Future<bool> generateKnockoutBracket(String tournamentId) async {
    final tIdx = state.tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return false;

    final tournament = state.tournaments[tIdx];
    final groupStandings = getGroupStandings(tournamentId);
    if (groupStandings.isEmpty) return false;

    // Collect top 2 from each group
    final qualifiers = <TournamentTeam>[];
    for (final entry in groupStandings.entries) {
      final top = entry.value.take(2).map((r) => r.team).toList();
      qualifiers.addAll(top);
    }

    // Find existing TBD knockout slots and fill them in order
    int qualIdx = 0;
    final updatedMatches = tournament.matches.map((m) {
      if (m.phase != 'group' && m.homeTeamId == 'tbd' && qualIdx + 1 < qualifiers.length) {
        final home = qualifiers[qualIdx++];
        final away = qualifiers[qualIdx++];
        return m.copyWith(homeTeamId: home.id, awayTeamId: away.id);
      }
      return m;
    }).toList();

    final updatedTournament = tournament.copyWith(matches: updatedMatches);
    final newList = List<Tournament>.from(state.tournaments);
    newList[tIdx] = updatedTournament;
    state = state.copyWith(tournaments: newList);
    await _syncTournamentUpdate(updatedTournament);
    return true;
  }

  /// Routes a tournament update through offline queue if no connectivity
  Future<void> _syncTournamentUpdate(Tournament tournament) async {
    final syncState = ref.read(offlineSyncProvider);
    if (!syncState.isOnline) {
      await ref.read(offlineSyncProvider.notifier).queueTournamentUpdate(tournament.toJson());
      return;
    }
    try {
      final client = sb.Supabase.instance.client;
      await client.from('tournaments').update(tournament.toJson()).eq('id', tournament.id);
    } catch (e) {
      debugPrint('DB write failed, queuing for later sync: $e');
      await ref.read(offlineSyncProvider.notifier).queueTournamentUpdate(tournament.toJson());
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // Round-Robin fixtures generator
  List<TournamentMatch> _generateRoundRobinFixtures(List<TournamentTeam> teams) {
    final List<TournamentMatch> matches = [];
    final int teamCount = teams.length;
    int matchCounter = 1;

    // Standard round robin pairing algorithm (Berger tables)
    for (int i = 0; i < teamCount; i++) {
      for (int j = i + 1; j < teamCount; j++) {
        matches.add(
          TournamentMatch(
            id: 'match_auto_${matchCounter++}',
            homeTeamId: teams[i].id,
            awayTeamId: teams[j].id,
            date: DateTime.now().add(Duration(days: matchCounter)),
            status: 'scheduled',
            venue: 'Main Stadium Pitch ${matchCounter % 2 == 0 ? "A" : "B"}',
          ),
        );
      }
    }
    return matches;
  }

  // ─── Mock Data ─────────────────────────────────────────────────────────────

  List<Tournament> _getMockTournaments() {
    // Mock Teams
    final t1Players = const [
      TournamentPlayer(id: 'p1_1', name: 'Alex Thorne', jerseyNumber: 10, position: 'FWD'),
      TournamentPlayer(id: 'p1_2', name: 'Liam Vance', jerseyNumber: 8, position: 'MID'),
      TournamentPlayer(id: 'p1_3', name: 'Marcus Fox', jerseyNumber: 4, position: 'DEF'),
      TournamentPlayer(id: 'p1_4', name: 'Sam Taylor', jerseyNumber: 1, position: 'GK'),
    ];
    final t2Players = const [
      TournamentPlayer(id: 'p2_1', name: 'David Miller', jerseyNumber: 9, position: 'FWD'),
      TournamentPlayer(id: 'p2_2', name: 'Chris Evans', jerseyNumber: 7, position: 'MID'),
      TournamentPlayer(id: 'p2_3', name: 'Tom Hardy', jerseyNumber: 5, position: 'DEF'),
      TournamentPlayer(id: 'p2_4', name: 'John Doe', jerseyNumber: 12, position: 'GK'),
    ];
    final t3Players = const [
      TournamentPlayer(id: 'p3_1', name: 'Kylian C', jerseyNumber: 10, position: 'FWD'),
      TournamentPlayer(id: 'p3_2', name: 'Paul P', jerseyNumber: 6, position: 'MID'),
      TournamentPlayer(id: 'p3_3', name: 'Raphael V', jerseyNumber: 4, position: 'DEF'),
      TournamentPlayer(id: 'p3_4', name: 'Hugo L', jerseyNumber: 1, position: 'GK'),
    ];
    final t4Players = const [
      TournamentPlayer(id: 'p4_1', name: 'Harry K', jerseyNumber: 9, position: 'FWD'),
      TournamentPlayer(id: 'p4_2', name: 'Jude B', jerseyNumber: 10, position: 'MID'),
      TournamentPlayer(id: 'p4_3', name: 'John S', jerseyNumber: 5, position: 'DEF'),
      TournamentPlayer(id: 'p4_4', name: 'Jordan P', jerseyNumber: 1, position: 'GK'),
    ];

    final team1 = TournamentTeam(id: 'team_red', name: 'Red Panthers', logoUrl: '🐆', primaryColor: '0xFFEF4444', secondaryColor: '0xFF131318', players: t1Players);
    final team2 = TournamentTeam(id: 'team_blue', name: 'Blue Falcons', logoUrl: '🦅', primaryColor: '0xFF3B82F6', secondaryColor: '0xFF131318', players: t2Players);
    final team3 = TournamentTeam(id: 'team_green', name: 'Green Vipers', logoUrl: '🐍', primaryColor: '0xFF10B981', secondaryColor: '0xFF131318', players: t3Players);
    final team4 = TournamentTeam(id: 'team_gold', name: 'Golden Eagles', logoUrl: '🦅', primaryColor: '0xFFFFD700', secondaryColor: '0xFF131318', players: t4Players);

    final mockMatches = [
      TournamentMatch(
        id: 'm_1',
        homeTeamId: 'team_red',
        awayTeamId: 'team_blue',
        homeScore: 2,
        awayScore: 1,
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'completed',
        venue: 'Stadium Pitch A',
        scorers: ['Alex Thorne', 'Liam Vance', 'David Miller'],
        cards: ['Marcus Fox:Yellow'],
        motm: 'Alex Thorne',
      ),
      TournamentMatch(
        id: 'm_2',
        homeTeamId: 'team_green',
        awayTeamId: 'team_gold',
        homeScore: 0,
        awayScore: 0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'completed',
        venue: 'Stadium Pitch B',
        scorers: [],
        cards: [],
        motm: 'Hugo L',
      ),
      TournamentMatch(
        id: 'm_3',
        homeTeamId: 'team_red',
        awayTeamId: 'team_green',
        date: DateTime.now().add(const Duration(hours: 3)),
        status: 'scheduled',
        venue: 'Stadium Pitch A',
      ),
      TournamentMatch(
        id: 'm_4',
        homeTeamId: 'team_blue',
        awayTeamId: 'team_gold',
        date: DateTime.now().add(const Duration(days: 2)),
        status: 'scheduled',
        venue: 'Stadium Pitch B',
      ),
    ];

    // Build complete redone teams with calculated stats
    final initTeams = [team1, team2, team3, team4];
    final processedTeams = _recalculatePlayerStats(initTeams, mockMatches, suspensionThreshold: 3);

    return [
      Tournament(
        id: 'tour_1',
        name: 'PES Super League 2026',
        sport: 'football',
        format: 'league',
        description: 'Elite local PES mobile league with top local squad players competing for the annual shield.',
        location: 'Kochi Arena (Offline)',
        bannerUrl: 'assets/images/tournament-banner-1.png',
        winPts: 3,
        drawPts: 1,
        lossPts: 0,
        teams: processedTeams,
        matches: mockMatches,
        prizes: '🏆 Trophy + ₹5000 Shop Voucher',
        creatorId: 'mock-user-id',
      ),
      Tournament(
        id: 'tour_2',
        name: 'Mumbai Cup 2026',
        sport: 'football',
        format: 'knockout',
        description: 'Knockout cup championship for college teams in Mumbai district.',
        location: 'Cooperage Ground',
        bannerUrl: 'assets/images/tournament-banner-2.png',
        winPts: 3,
        drawPts: 0,
        lossPts: 0,
        teams: processedTeams.sublist(0, 2),
        matches: [
          TournamentMatch(
            id: 'm_cup_1',
            homeTeamId: 'team_red',
            awayTeamId: 'team_blue',
            date: DateTime.now().add(const Duration(days: 4)),
            status: 'scheduled',
            venue: 'Cooperage Ground',
          )
        ],
        prizes: '🎖️ Winner Gold Medals + Kit sponsor',
        creatorId: 'another-creator',
      ),
    ];
  }
}

class _TeamAccumulator {
  final TournamentTeam team;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int gf = 0;
  int ga = 0;
  int points = 0;
  List<String> form = [];

  _TeamAccumulator({required this.team});
}

final tournamentsProvider = NotifierProvider<TournamentsNotifier, TournamentsState>(() {
  return TournamentsNotifier();
});
